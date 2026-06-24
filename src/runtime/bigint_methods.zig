// SPDX-License-Identifier: EPL-2.0
//! Host-interop instance methods on the `.big_int` value (java.math.BigInteger).
//! Real number-theory / crypto Clojure reaches these via the dot form:
//! `(.gcd a b)` / `(.modPow …)` / `(.pow n e)` / `(.sqrt n)`. Installs on the
//! per-Runtime `.big_int` native descriptor — the same `receiverDescriptor` →
//! `method_table` path String / Keyword / BigDecimal / Ratio interop uses.
//! Mirrors `ratio_methods.zig` (native-tag instance methods, no static surface).
//!
//! Backend: impl-only
//! Impl deps: none (std.math.big.int)
//! Clojure peer: none (clojure.core arithmetic auto-promotes; these are the
//! Java BigInteger method surface, distinct from the core fns).
//!
//! Every result stays a BigInteger (`.bigint`), matching JVM (a BigInteger method
//! never collapses to a Long) — so `allocFromManaged(.bigint)`, NOT the
//! Long-collapsing `promote.wrapManaged`. `(str …)` is identical either way.
//! `modPow` / `isProbablePrime` / `bitLength` are D-514.

const std = @import("std");
const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const Env = @import("env.zig").Env;
const SourceLocation = @import("error/info.zig").SourceLocation;
const error_catalog = @import("error/catalog.zig");
const type_descriptor = @import("type_descriptor.zig");
const big_int = @import("numeric/big_int.zig");
const Managed = std.math.big.int.Managed;

fn requireBigInt(v: Value, name: []const u8, loc: SourceLocation) !void {
    if (v.tag() != .big_int)
        return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = name, .actual = @tagName(v.tag()) });
}

/// `(.abs n)` — absolute value (JVM `BigInteger.abs`).
fn absFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("abs", args, 1, loc);
    var m = try big_int.asManaged(args[0]).clone();
    defer m.deinit();
    m.abs();
    return big_int.allocFromManaged(rt, &m, .bigint);
}

/// `(.negate n)` — arithmetic negation (JVM `BigInteger.negate`).
fn negateFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("negate", args, 1, loc);
    var m = try big_int.asManaged(args[0]).clone();
    defer m.deinit();
    m.negate();
    return big_int.allocFromManaged(rt, &m, .bigint);
}

/// `(.signum n)` — -1 / 0 / 1 (JVM `BigInteger.signum`).
fn signumFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = rt;
    try error_catalog.checkArity("signum", args, 1, loc);
    return Value.initInteger(switch (big_int.asManaged(args[0]).toConst().orderAgainstScalar(0)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    });
}

/// `(.gcd a b)` — greatest common divisor, non-negative (JVM `BigInteger.gcd`).
fn gcdFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("gcd", args, 2, loc);
    try requireBigInt(args[1], "gcd", loc);
    var r = try Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.gcd(big_int.asManaged(args[0]), big_int.asManaged(args[1]));
    return big_int.allocFromManaged(rt, &r, .bigint);
}

/// `(.pow n e)` — `n^e`, e ≥ 0 (JVM `BigInteger.pow(int)`).
fn powFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("pow", args, 2, loc);
    if (!args[1].isInt())
        return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "pow", .actual = "non-integer exponent" });
    const e = args[1].asInteger();
    if (e < 0)
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "pow", .expected = "a non-negative exponent", .actual = "a negative exponent" });
    var r = try Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.pow(big_int.asManaged(args[0]), @intCast(e));
    return big_int.allocFromManaged(rt, &r, .bigint);
}

/// `(.mod n m)` — floor-mod, result in [0, m) for m > 0 (JVM `BigInteger.mod`).
fn modFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("mod", args, 2, loc);
    try requireBigInt(args[1], "mod", loc);
    if (big_int.asManaged(args[1]).toConst().orderAgainstScalar(0) != .gt)
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "mod", .expected = "a positive modulus", .actual = "a non-positive modulus" });
    var q = try Managed.init(rt.gc.infra);
    defer q.deinit();
    var r = try Managed.init(rt.gc.infra);
    defer r.deinit();
    try q.divFloor(&r, big_int.asManaged(args[0]), big_int.asManaged(args[1])); // r sign = divisor sign (≥0)
    return big_int.allocFromManaged(rt, &r, .bigint);
}

/// `(.sqrt n)` — floor integer square root, n ≥ 0 (JVM `BigInteger.sqrt`).
fn sqrtFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("sqrt", args, 1, loc);
    if (big_int.asManaged(args[0]).toConst().orderAgainstScalar(0) == .lt)
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "sqrt", .expected = "a non-negative value", .actual = "a negative value" });
    var r = try Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.sqrt(big_int.asManaged(args[0]));
    return big_int.allocFromManaged(rt, &r, .bigint);
}

/// Populate the per-Runtime `.big_int` native descriptor's method table.
/// Idempotent. Called at runtime init alongside the other native installers.
pub fn installNativeMethods(rt: *Runtime) !void {
    const td = try rt.nativeDescriptor(.big_int);
    if (td.method_table.len != 0) return; // idempotent re-run
    const gpa = rt.gc.infra;
    const specs = .{
        .{ "abs", &absFn },
        .{ "negate", &negateFn },
        .{ "signum", &signumFn },
        .{ "gcd", &gcdFn },
        .{ "pow", &powFn },
        .{ "mod", &modFn },
        .{ "sqrt", &sqrtFn },
    };
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
}
