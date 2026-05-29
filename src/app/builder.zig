// SPDX-License-Identifier: EPL-2.0
//! `cljw build` — compile a Clojure source to a serialized bytecode
//! payload envelope (D-100(b), ADR-0034 amendment 1 Alt B). Each
//! top-level form compiles to one `BytecodeChunk`; the chunks are framed
//! by `serialize.serializeEnvelope`. This module is the **compile core**:
//! it turns already-bootstrapped runtime state + source text into the
//! payload bytes. The Deno-style binary trailer (runtime + payload +
//! `"CLJC"` footer) and the `cljw build app.clj -o app` CLI dispatch
//! layer above this in later steps.
//!
//! Backend: surface-only (Layer 3 → eval/runtime impl). Impl deps:
//! serialize, vm/compiler, analyzer. Clojure peer: none.
//!
//! F-009 note: `runner.runSource` already owns the bootstrap chain
//! (Runtime / Env / macro_table / loadCore) and is documented as the
//! shared entry for "the build-runner"; this core takes that state as
//! parameters rather than re-deriving it, so the eventual CLI path wires
//! the same setup once and feeds both run and build.

const std = @import("std");
const Runtime = @import("../runtime/runtime.zig").Runtime;
const Env = @import("../runtime/env.zig").Env;
const Reader = @import("../eval/reader.zig").Reader;
const analyzeForm = @import("../eval/analyzer/analyzer.zig").analyze;
const macro_dispatch = @import("../eval/macro_dispatch.zig");
const vm_compiler = @import("../eval/backend/vm/compiler.zig");
const serialize = @import("../eval/bytecode/serialize.zig");
const BytecodeChunk = @import("../eval/backend/vm/opcode.zig").BytecodeChunk;
const driver = @import("../eval/driver.zig");
const Value = @import("../runtime/value/value.zig").Value;

/// Compile every top-level form in `source_text` to a `BytecodeChunk`
/// and return the serialized payload envelope (caller frees the bytes
/// via `allocator.free`). The runtime / env / macro_table must already
/// be bootstrapped (`loadCore` done) by the caller.
///
/// The compiled chunks' slices are allocated from `arena`
/// (`vm_compiler.compile` uses it), so `serializeEnvelope` copies their
/// bytes and the chunks need no per-chunk free — the caller's arena owns
/// them.
pub fn buildEnvelope(
    allocator: std.mem.Allocator,
    rt: *Runtime,
    env: *Env,
    macro_table: *macro_dispatch.Table,
    arena: std.mem.Allocator,
    source_text: []const u8,
) ![]u8 {
    var chunks: std.ArrayList(BytecodeChunk) = .empty;
    defer chunks.deinit(allocator);

    // A1-D2 (ADR-0034 am1, Alt B): compile-THEN-eval each top-level form.
    // The eval step evolves `env` (macros / requires / defs register) so
    // form N+1 analyses against the same state Clojure AOT would see; a
    // top-level side effect (e.g. `(println …)`) runs at build time, as
    // documented in `cljw build` help. Compile produces the payload chunk;
    // eval (tree_walk via the installed vtable) only mutates env.
    var locals: [driver.MAX_LOCALS]Value = [_]Value{.nil_val} ** driver.MAX_LOCALS;
    var reader = Reader.init(arena, source_text);
    while (true) {
        const form = (try reader.read()) orelse break;
        const node = try analyzeForm(arena, rt, env, null, form, macro_table);
        const chunk = try vm_compiler.compile(rt, arena, node);
        try chunks.append(allocator, chunk);
        _ = try driver.evalForm(rt, env, &locals, arena, node);
    }
    return serialize.serializeEnvelope(allocator, chunks.items);
}

// --- tests ---

const testing = std.testing;
const primitive = @import("../lang/primitive.zig");
const macro_transforms = @import("../lang/macro_transforms.zig");
const bootstrap = @import("../lang/bootstrap.zig");

test "buildEnvelope compiles two forms into a two-chunk envelope" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    var env = try Env.init(&rt);
    defer env.deinit();

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    driver.installVTable(&rt);
    bootstrap.installEmbeddedResolver(&rt);
    try primitive.registerAll(&env);
    var macro_table = macro_dispatch.Table.init(testing.allocator);
    defer macro_table.deinit();
    try macro_transforms.registerInto(&env, &macro_table);
    try bootstrap.loadCore(arena, &rt, &env, &macro_table);

    const bytes = try buildEnvelope(testing.allocator, &rt, &env, &macro_table, arena, "(+ 1 2) (* 3 4)");
    defer testing.allocator.free(bytes);

    const chunks = try serialize.deserializeEnvelope(testing.allocator, &rt, &env, bytes);
    defer serialize.freeEnvelope(testing.allocator, chunks);

    // Two top-level forms → two chunks, in source order, each with a
    // non-empty instruction stream (the compiler emits at least op_ret).
    try testing.expectEqual(@as(usize, 2), chunks.len);
    try testing.expect(chunks[0].instructions.len > 0);
    try testing.expect(chunks[1].instructions.len > 0);
}

test "buildEnvelope evaluates each form so later forms see earlier env (ADR-0034 A1-D2)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    var env = try Env.init(&rt);
    defer env.deinit();

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    driver.installVTable(&rt);
    bootstrap.installEmbeddedResolver(&rt);
    try primitive.registerAll(&env);
    var macro_table = macro_dispatch.Table.init(testing.allocator);
    defer macro_table.deinit();
    try macro_transforms.registerInto(&env, &macro_table);
    try bootstrap.loadCore(arena, &rt, &env, &macro_table);

    // Form 2 `(s/union …)` only ANALYSES once form 1's `(require …:as s)`
    // has been EVALUATED — the alias `s` is registered when the
    // `op_require_with_libspec` op RUNS (vm.zig), not at compile time. A
    // compile-only loop leaves `s` unbound and form 2 raises name_error.
    // This proves the A1-D2 eval step while keeping both chunks
    // serializable (libspec table + var_ref + array-set constants; no
    // fn_val). Clojure AOT shape.
    const bytes = try buildEnvelope(testing.allocator, &rt, &env, &macro_table, arena, "(require '[clojure.set :as s]) (s/union #{1} #{2})");
    defer testing.allocator.free(bytes);

    const chunks = try serialize.deserializeEnvelope(testing.allocator, &rt, &env, bytes);
    defer serialize.freeEnvelope(testing.allocator, chunks);

    try testing.expectEqual(@as(usize, 2), chunks.len);
    try testing.expect(chunks[1].instructions.len > 0);
}
