// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.Random` — a stateful native instance (ADR-0106 /
//! D-289). A seeded `(java.util.Random. n)` reproduces the JVM 48-bit-LCG
//! sequence (F-011), so clojure.data.generators / test.check are deterministic.
//!
//! Backend: impl-only
//! Impl deps: random
//! Clojure peer: none. clojure.core/rand & rand-int are primitives in
//! lang/primitive/math.zig over runtime/random.zig's DefaultPrng (no parity
//! need) — they do NOT route through this Java-LCG surface.
//!
//! The instance is a `.host_instance` (ADR-0106 general container) carrying this
//! surface descriptor + state[0]=LCG seed (state[1..]=gaussian cache, D-289b).
//! `<init>` + the instance methods are registered on the descriptor in
//! `initRandom`; dispatch reads the descriptor off the instance.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const random = @import("../../random.zig");
const host_instance = @import("../../host_instance.zig");
const big_int = @import("../../numeric/big_int.zig");

/// The live rt.types descriptor (set in `initRandom`), embedded into every
/// HostInstance so the `<init>` path and instance-method dispatch share it.
var rnd_descriptor: ?*const type_descriptor.TypeDescriptor = null;

fn seedPtr(recv: Value) *u64 {
    return &@constCast(host_instance.asHostInstance(recv)).state[0];
}

/// `(java.util.Random.)` / `(java.util.Random. seed)`. 0-arg seeds from entropy
/// (non-reproducible, like clj); 1-arg scrambles the seed (Java-LCG parity).
fn initRandomInstance(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    const seed: u64 = if (args.len == 0)
        random.javaScramble(@bitCast(random.entropyU64(rt.io)))
    else if (args.len == 1) blk: {
        if (args[0].tag() != .integer)
            return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "java.util.Random.", .actual = @tagName(args[0].tag()) });
        break :blk random.javaScramble(args[0].asInteger());
    } else return error_catalog.raise(.arity_not_expected, loc, .{ .got = args.len, .fn_name = "java.util.Random.", .expected = 1 });
    const td = rnd_descriptor orelse return error.NoVTable;
    return host_instance.alloc(rt, td, .{ seed, 0, 0, 0 });
}

/// `(.nextInt r)` → next i32; `(.nextInt r bound)` → [0,bound) (bound > 0).
fn nextInt(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    if (args.len == 1) return Value.initInteger(random.javaNextInt(seedPtr(args[0])));
    if (args.len == 2) {
        if (args[1].tag() != .integer)
            return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "nextInt", .actual = @tagName(args[1].tag()) });
        const bound = args[1].asInteger();
        if (bound <= 0)
            return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "nextInt", .expected = "a positive bound", .actual = "non-positive" });
        return Value.initInteger(random.javaNextIntBound(seedPtr(args[0]), @intCast(bound)));
    }
    return error_catalog.raise(.arity_not_expected, loc, .{ .got = args.len, .fn_name = "nextInt", .expected = 1 });
}

fn nextLong(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("nextLong", args, 1, loc);
    // F-005: a full 64-bit long exceeds the i48 immediate range → box as a
    // .long-origin BigInt (NOT initInteger, which floats past i48).
    return big_int.allocFromI64(rt, random.javaNextLong(seedPtr(args[0])), .long);
}

fn nextDouble(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("nextDouble", args, 1, loc);
    return Value.initFloat(random.javaNextDouble(seedPtr(args[0])));
}

fn nextFloat(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("nextFloat", args, 1, loc);
    return Value.initFloat(random.javaNextFloat(seedPtr(args[0])));
}

fn nextBoolean(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("nextBoolean", args, 1, loc);
    return Value.initBoolean(random.javaNextBoolean(seedPtr(args[0])));
}

/// `(.setSeed r n)` — re-scramble the seed + reset gaussian cache. Returns nil
/// (Java setSeed is void).
fn setSeed(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("setSeed", args, 2, loc);
    if (args[1].tag() != .integer)
        return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "setSeed", .actual = @tagName(args[1].tag()) });
    host_instance.setState(args[0], 0, random.javaScramble(args[1].asInteger()));
    host_instance.setState(args[0], 2, 0); // clear have-gaussian
    return Value.nil_val;
}

const MethodSpec = struct { name: []const u8, f: *const fn (*Runtime, *Env, []const Value, SourceLocation) anyerror!Value };

const METHODS = [_]MethodSpec{
    .{ .name = "<init>", .f = &initRandomInstance },
    .{ .name = "nextInt", .f = &nextInt },
    .{ .name = "nextLong", .f = &nextLong },
    .{ .name = "nextDouble", .f = &nextDouble },
    .{ .name = "nextFloat", .f = &nextFloat },
    .{ .name = "nextBoolean", .f = &nextBoolean },
    .{ .name = "setSeed", .f = &setSeed },
};

fn initRandom(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent
    rnd_descriptor = td;
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, METHODS.len);
    for (METHODS, 0..) |m, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, m.name),
            .method_val = Value.initBuiltinFn(m.f),
        };
    }
    td.method_table = entries;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.Random",
    .descriptor = &descriptor,
    .init = &initRandom,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "java.util.Random",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
