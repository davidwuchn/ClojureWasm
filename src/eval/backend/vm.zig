// SPDX-License-Identifier: EPL-2.0
//! Bytecode VM dispatch loop — the second backend (ROADMAP §9.6 / 4.6,
//! ADR-0005). `eval` consumes a `BytecodeChunk` produced by
//! `vm/compiler.zig` and executes its instructions against a per-frame
//! operand stack of `OPERAND_STACK_MAX` Values, mirroring TreeWalk's
//! `MAX_LOCALS` discipline so the recursion bound matches across
//! backends.
//!
//! Per ADR-0022 the VM must produce bit-for-bit identical Values to
//! TreeWalk for the same source. Errors raised here therefore reuse
//! TreeWalk's `error_catalog` Codes; control-flow signals
//! (`error.RecurSignaled`, `error.ThrownValue`) use the same Zig errors
//! so a shared try/loop driver works across backends at task 4.7.
//!
//! Dispatch shape is a single `switch (Opcode)` per ROADMAP §9.6.
//! Computed-goto is deferred; only the hot `op_const` / `op_ret` arms
//! carry `@branchHint(.likely)`.

const std = @import("std");
const node_mod = @import("../node.zig");
const opcode_mod = @import("vm/opcode.zig");
const value_mod = @import("../../runtime/value.zig");
const env_mod = @import("../../runtime/env.zig");
const runtime_mod = @import("../../runtime/runtime.zig");
const string_mod = @import("../../runtime/collection/string.zig");
const dispatch = @import("../../runtime/dispatch.zig");
const error_mod = @import("../../runtime/error.zig");
const error_catalog = @import("../../runtime/error_catalog.zig");
const tree_walk = @import("tree_walk.zig");

const Opcode = opcode_mod.Opcode;
const Instruction = opcode_mod.Instruction;
const BytecodeChunk = opcode_mod.BytecodeChunk;
const Value = value_mod.Value;
const Env = env_mod.Env;
const Var = env_mod.Var;
const Runtime = runtime_mod.Runtime;
const SourceLocation = error_mod.SourceLocation;
const Function = tree_walk.Function;

/// Per-frame operand stack ceiling. Matches `tree_walk.MAX_LOCALS` so
/// the VM's per-call working set equals TreeWalk's. The analyser does
/// not yet compute max stack depth (Phase 4 entry); the runtime check
/// raises `internal_error` if a malformed chunk overflows.
pub const OPERAND_STACK_MAX: u16 = 256;

/// Evaluate a compiled chunk. `locals` is the caller-owned slot array
/// (typically a fixed 256-entry stack array, matching `tree_walk.eval`).
/// Returns the value produced by `op_ret`.
pub fn eval(
    rt: *Runtime,
    env: *Env,
    locals: []Value,
    chunk: *const BytecodeChunk,
) anyerror!Value {
    var stack: [OPERAND_STACK_MAX]Value = undefined;
    var sp: u16 = 0;
    var ip: usize = 0;

    while (true) {
        if (ip >= chunk.instructions.len)
            return raiseInternal("vm: ip past end of chunk");
        const instr = chunk.instructions[ip];
        ip += 1;

        switch (instr.opcode) {
            .op_const => {
                @branchHint(.likely);
                if (instr.operand >= chunk.constants.len)
                    return raiseInternal("vm: op_const constant index out of range");
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = chunk.constants[instr.operand];
                sp += 1;
            },
            .op_load_local => {
                if (instr.operand >= locals.len)
                    return error_mod.setErrorFmt(.eval, .index_error, .{}, "Local slot {d} out of range (max {d})", .{ instr.operand, locals.len });
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = locals[instr.operand];
                sp += 1;
            },
            .op_store_local => {
                if (instr.operand >= locals.len)
                    return error_mod.setErrorFmt(.eval, .index_error, .{}, "let* slot {d} out of range (max {d})", .{ instr.operand, locals.len });
                if (sp == 0) return raiseInternal("vm: op_store_local on empty stack");
                sp -= 1;
                locals[instr.operand] = stack[sp];
            },
            .op_def => {
                if (sp == 0) return raiseInternal("vm: op_def on empty stack");
                sp -= 1;
                const value = stack[sp];
                const name_idx = instr.operand & opcode_mod.DEF_NAME_IDX_MASK;
                if (name_idx >= chunk.constants.len)
                    return raiseInternal("vm: op_def name index out of range");
                const name_val = chunk.constants[name_idx];
                if (!name_val.isString())
                    return raiseInternal("vm: op_def constant is not a String");
                const ns = env.current_ns orelse
                    return error_mod.setErrorFmt(.eval, .internal_error, .{}, "def: no current namespace", .{});
                const var_ptr = try env.intern(ns, string_mod.asString(name_val), value);
                var_ptr.flags.dynamic = (instr.operand & opcode_mod.DEF_FLAG_DYNAMIC) != 0;
                var_ptr.flags.macro_ = (instr.operand & opcode_mod.DEF_FLAG_MACRO) != 0;
                var_ptr.flags.private = (instr.operand & opcode_mod.DEF_FLAG_PRIVATE) != 0;
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = Value.encodeHeapPtr(.var_ref, var_ptr);
                sp += 1;
            },
            .op_get_var => {
                if (instr.operand >= chunk.constants.len)
                    return raiseInternal("vm: op_get_var constant index out of range");
                const var_value = chunk.constants[instr.operand];
                const var_ptr = var_value.decodePtr(*Var);
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = var_ptr.deref();
                sp += 1;
            },
            .op_jump => {
                const offset: i16 = @bitCast(instr.operand);
                ip = applyJump(ip, offset) orelse
                    return raiseInternal("vm: op_jump target out of range");
            },
            .op_jump_if_false => {
                if (sp == 0) return raiseInternal("vm: op_jump_if_false on empty stack");
                sp -= 1;
                if (!stack[sp].isTruthy()) {
                    const offset: i16 = @bitCast(instr.operand);
                    ip = applyJump(ip, offset) orelse
                        return raiseInternal("vm: op_jump_if_false target out of range");
                }
            },
            .op_call => {
                const arg_count: usize = instr.operand;
                if (sp < arg_count + 1)
                    return raiseInternal("vm: op_call underflow");
                sp -= @intCast(arg_count + 1);
                const callee = stack[sp];
                const args = stack[sp + 1 .. sp + 1 + arg_count];
                const vt = rt.vtable orelse
                    return error_mod.setErrorFmt(.eval, .internal_error, .{}, "Runtime vtable not installed; cannot dispatch call", .{});
                const result = try vt.callFn(rt, env, callee, args, .{});
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = result;
                sp += 1;
            },
            .op_ret => {
                @branchHint(.likely);
                if (sp == 0) return raiseInternal("vm: op_ret on empty stack");
                sp -= 1;
                return stack[sp];
            },
            .op_pop => {
                if (sp == 0) return raiseInternal("vm: op_pop on empty stack");
                sp -= 1;
            },
            .op_dup => {
                if (sp == 0) return raiseInternal("vm: op_dup on empty stack");
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = stack[sp - 1];
                sp += 1;
            },
            .op_throw => {
                if (sp == 0) return raiseInternal("vm: op_throw on empty stack");
                sp -= 1;
                dispatch.last_thrown_exception = stack[sp];
                return error.ThrownValue;
            },
            .op_make_fn => {
                // The compiler pre-allocates closure-less Functions at
                // compile time and stashes the resulting `.fn_val`
                // Value in the constant pool (compiler.zig::compileFn).
                // Closure capture (`slot_base > 0`) is task 4.7 and
                // already errors at compile time, so the dispatcher
                // only handles the closure-less case: push the
                // pre-built Function.
                if (instr.operand >= chunk.constants.len)
                    return raiseInternal("vm: op_make_fn constant index out of range");
                if (sp >= OPERAND_STACK_MAX)
                    return raiseInternal("vm: operand stack overflow");
                stack[sp] = chunk.constants[instr.operand];
                sp += 1;
            },
            .op_recur => {
                // The compiler does not yet emit `op_recur` (loop*/recur
                // compile lands at task 4.7, which also adds the
                // matching loop driver that drains the recur scratch).
                // Per `no_op_stub_forbidden.md`, surface the absence
                // explicitly rather than half-wire the unwind.
                return error_catalog.raise(.unsupported_feature, .{}, .{ .name = "recur" });
            },
            .op_invoke_builtin => {
                // Reserved for analyzer-resolved direct builtin calls;
                // the compiler does not emit this at 4.6 (every call
                // routes through `op_call` + vtable). Per
                // `no_op_stub_forbidden.md`, raise rather than fall
                // through silently.
                return error_catalog.raise(.unsupported_feature, .{}, .{ .name = "op_invoke_builtin" });
            },
        }
    }
}

fn raiseInternal(comptime detail: []const u8) anyerror {
    return error_catalog.raise(.internal_error, .{}, .{ .detail = detail });
}

fn applyJump(ip: usize, offset: i16) ?usize {
    if (offset >= 0) {
        return ip + @as(usize, @intCast(offset));
    }
    const back = @as(usize, @intCast(-@as(i32, offset)));
    if (back > ip) return null;
    return ip - back;
}

// --- tests ---

const testing = std.testing;

const Fixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,
    env: Env,

    fn init(alloc: std.mem.Allocator) !Fixture {
        var f: Fixture = undefined;
        f.threaded = std.Io.Threaded.init(alloc, .{});
        f.rt = Runtime.init(f.threaded.io(), alloc);
        f.env = try Env.init(&f.rt);
        tree_walk.installVTable(&f.rt);
        return f;
    }

    fn deinit(self: *Fixture) void {
        self.env.deinit();
        self.rt.deinit();
        self.threaded.deinit();
    }

    fn run(self: *Fixture, chunk: *const BytecodeChunk) anyerror!Value {
        var locals: [256]Value = [_]Value{.nil_val} ** 256;
        return eval(&self.rt, &self.env, &locals, chunk);
    }
};

test "op_const then op_ret returns the constant" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{Value.true_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_pop discards the top of the operand stack" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_pop },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ Value.true_val, Value.false_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_dup duplicates the top of the operand stack" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_dup },
        .{ .opcode = .op_pop },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{Value.true_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_store_local then op_load_local round-trips a slot" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_store_local, .operand = 7 },
        .{ .opcode = .op_load_local, .operand = 7 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{Value.true_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_load_local out of range raises index_error" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_load_local, .operand = 1000 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectError(error.IndexError, f.run(&chunk));
}

test "op_jump unconditionally skips forward" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    // op_jump +1 ; op_const false (skipped) ; op_const true ; op_ret
    const instrs = [_]Instruction{
        .{ .opcode = .op_jump, .operand = @as(u16, @bitCast(@as(i16, 1))) },
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ Value.true_val, Value.false_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_jump_if_false takes the jump when popped value is false" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    // op_const false ; op_jump_if_false +1 ; op_const true (skipped) ; op_const false ; op_ret
    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_jump_if_false, .operand = @as(u16, @bitCast(@as(i16, 1))) },
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ Value.true_val, Value.false_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.false_val, try f.run(&chunk));
}

test "op_jump_if_false falls through when popped value is truthy" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    // (if true true false): push true cond ; jump_if_false +2 (no jump) ;
    // push true ; ret ; push false ; ret
    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_jump_if_false, .operand = @as(u16, @bitCast(@as(i16, 2))) },
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_ret },
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ Value.true_val, Value.false_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_def interns the name into env.current_ns and pushes the Var" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const name_val = try string_mod.alloc(&f.rt, "answer");
    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_def, .operand = 0 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ name_val, Value.true_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    const result = try f.run(&chunk);
    try testing.expectEqual(value_mod.Value.Tag.var_ref, result.tag());
    const var_ptr = result.decodePtr(*Var);
    try testing.expectEqualStrings("answer", var_ptr.name);
    try testing.expectEqual(Value.true_val, var_ptr.deref());
    try testing.expect(!var_ptr.flags.dynamic);
}

test "op_def stamps dynamic / macro / private flags from the operand" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const name_val = try string_mod.alloc(&f.rt, "foo");
    const packed_operand: u16 = 0 | opcode_mod.DEF_FLAG_DYNAMIC | opcode_mod.DEF_FLAG_PRIVATE;
    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_def, .operand = packed_operand },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ name_val, Value.nil_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    const result = try f.run(&chunk);
    const var_ptr = result.decodePtr(*Var);
    try testing.expect(var_ptr.flags.dynamic);
    try testing.expect(!var_ptr.flags.macro_);
    try testing.expect(var_ptr.flags.private);
}

test "op_get_var dereferences a Var pointer from the constant pool" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const ns = f.env.current_ns.?;
    const var_ptr = try f.env.intern(ns, "x", Value.true_val);
    const var_value = Value.encodeHeapPtr(.var_ref, var_ptr);

    const instrs = [_]Instruction{
        .{ .opcode = .op_get_var, .operand = 0 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{var_value};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_call routes through rt.vtable.callFn" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const ns = f.env.current_ns.?;
    const builtin_val = Value.initBuiltinFn(@as(dispatch.BuiltinFn, &testReturnFirstArg));
    _ = try f.env.intern(ns, "first-arg", builtin_val);

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_const, .operand = 1 },
        .{ .opcode = .op_const, .operand = 2 },
        .{ .opcode = .op_call, .operand = 2 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{ builtin_val, Value.true_val, Value.false_val };
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(Value.true_val, try f.run(&chunk));
}

test "op_make_fn pushes the pre-allocated Function from the constants pool" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const body: node_mod.Node = .{ .constant = .{ .value = Value.true_val } };
    const fn_node = node_mod.FnNode{
        .arity = 0,
        .has_rest = false,
        .params = &.{},
        .body = &body,
        .slot_base = 0,
    };
    const fn_val = try tree_walk.allocFunction(&f.rt, fn_node, &.{});

    const instrs = [_]Instruction{
        .{ .opcode = .op_make_fn, .operand = 0 },
        .{ .opcode = .op_ret },
    };
    const constants = [_]Value{fn_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectEqual(fn_val, try f.run(&chunk));
}

test "op_throw sets dispatch.last_thrown_exception and returns ThrownValue" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    dispatch.last_thrown_exception = null;

    const instrs = [_]Instruction{
        .{ .opcode = .op_const, .operand = 0 },
        .{ .opcode = .op_throw },
    };
    const constants = [_]Value{Value.true_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectError(error.ThrownValue, f.run(&chunk));
    try testing.expectEqual(Value.true_val, dispatch.last_thrown_exception.?);
    dispatch.last_thrown_exception = null;
}

test "op_invoke_builtin raises unsupported_feature (4.6 placeholder)" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();

    const instrs = [_]Instruction{
        .{ .opcode = .op_invoke_builtin, .operand = 0 },
    };
    const constants = [_]Value{Value.nil_val};
    const chunk: BytecodeChunk = .{ .instructions = &instrs, .constants = &constants };

    try testing.expectError(error.NotImplemented, f.run(&chunk));
}

fn testReturnFirstArg(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    _ = loc;
    if (args.len == 0) return Value.nil_val;
    return args[0];
}
