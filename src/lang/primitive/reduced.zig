// SPDX-License-Identifier: EPL-2.0
//! reduced / reduced? / unreduced / ensure-reduced — the early-termination
//! sentinel surface (transducer foundation). The `Reduced` heap value +
//! `reduce`/`transduce` honoring it live in runtime/collection/reduced.zig;
//! `reduce` already unwraps a returned Reduced (higher_order.zig). `deref`
//! on a Reduced unwraps it (stm.zig `.reduced` arm).

const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const error_mod = @import("../../runtime/error/info.zig");
const error_catalog = @import("../../runtime/error/catalog.zig");
const SourceLocation = error_mod.SourceLocation;
const dispatch = @import("../../runtime/dispatch.zig");
const reduced = @import("../../runtime/collection/reduced.zig");

/// `(reduced x)` — wrap x so a reducing fn can signal early termination.
pub fn reducedFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("reduced", args, 1, loc);
    return reduced.alloc(rt, args[0]);
}

/// `(reduced? x)` — true iff x is a Reduced sentinel.
pub fn reducedQFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("reduced?", args, 1, loc);
    return if (reduced.isReduced(args[0])) Value.true_val else Value.false_val;
}

/// `(unreduced x)` — the inner value if x is Reduced, else x.
pub fn unreducedFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("unreduced", args, 1, loc);
    return if (reduced.isReduced(args[0])) reduced.unreduce(args[0]) else args[0];
}

/// `(ensure-reduced x)` — x if already Reduced, else `(reduced x)`.
pub fn ensureReducedFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("ensure-reduced", args, 1, loc);
    return if (reduced.isReduced(args[0])) args[0] else reduced.alloc(rt, args[0]);
}

// --- registration ---

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const ENTRIES = [_]Entry{
    .{ .name = "reduced", .f = &reducedFn },
    .{ .name = "reduced?", .f = &reducedQFn },
    .{ .name = "unreduced", .f = &unreducedFn },
    .{ .name = "ensure-reduced", .f = &ensureReducedFn },
};

pub fn register(env: *Env, rt_ns: *env_mod.Namespace) !void {
    for (ENTRIES) |it| {
        _ = try env.intern(rt_ns, it.name, Value.initBuiltinFn(it.f), null);
    }
}
