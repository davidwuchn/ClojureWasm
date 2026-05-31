// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.Long` static methods.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: clojure.core/parse-long
//!
//! Thin wrapper over the shared `runtime/numeric/parse.zig` leaf (same
//! acceptance as `Integer/parseInt` / `clojure.core/parse-long`, F-011
//! DRY) at i64 width + Zig `std.fmt` radix formatting. parseLong wraps
//! through `promote.wrapManaged`, matching parse-long: a value beyond
//! the i48 NaN-box payload stays exact as a BigInt rather than a lossy
//! Float. That makes `(Long/parseLong "999999999999999")` print
//! `…N` (BigInt) where JVM keeps a primitive Long — a recorded
//! representation divergence (D-165, F-004 NaN-box i48 boundary); the
//! value is exact. Parse failure raises a `number_error`-Kind Code →
//! NumberFormatException (ADR-0060).

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const parse = @import("../../numeric/parse.zig");
const promote = @import("../../numeric/promote.zig");
const string_mod = @import("../../collection/string.zig");

/// Parse `s` as an i64 in `radix`, wrapping through `promote.wrapManaged`
/// (collapses to a Long in i48 range, BigInt beyond — D-165). On failure
/// raise NumberFormatException. Shared by `parseLong` and `valueOf`.
fn parseI64(rt: *Runtime, s: []const u8, radix: u8, fn_name: []const u8, loc: SourceLocation) anyerror!Value {
    const v = parse.parseSigned(i64, s, radix) catch
        return error_catalog.raise(.number_format_invalid, loc, .{ .fn_name = fn_name, .text = s });
    var m = try std.math.big.int.Managed.initSet(rt.gc.infra, v);
    defer m.deinit();
    return promote.wrapManaged(rt, &m);
}

/// Implements `(Long/parseLong s)` and `(Long/parseLong s radix)`.
/// Spec: parse a 64-bit long; malformed ⇒ NumberFormatException. Radix
/// defaults to 10, must be in 2..36.
/// JVM reference: java.lang.Long#parseLong.
/// cw v1 tier: A (§A26 clj differential sweep).
fn parseLong(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    if (args.len < 1 or args.len > 2)
        return error_catalog.raise(.arity_out_of_range, loc, .{ .fn_name = "Long/parseLong", .got = args.len, .min = 1, .max = 2 });
    if (args[0].tag() != .string)
        return error_catalog.raise(.type_arg_not_string, loc, .{ .fn_name = "Long/parseLong", .actual = @tagName(args[0].tag()) });
    const s = string_mod.asString(args[0]);
    var radix: u8 = 10;
    if (args.len == 2) {
        const r = try error_catalog.expectInteger(args[1], "Long/parseLong", loc);
        if (r < 2 or r > 36)
            return error_catalog.raise(.number_format_invalid, loc, .{ .fn_name = "Long/parseLong", .text = s });
        radix = @intCast(r);
    }
    return parseI64(rt, s, radix, "Long/parseLong", loc);
}

/// Implements `(Long/valueOf x)`. Spec: a String parses (like parseLong
/// base-10); a number is returned as-is.
/// JVM reference: java.lang.Long#valueOf.
/// cw v1 tier: A (§A26 clj differential sweep).
fn valueOf(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("Long/valueOf", args, 1, loc);
    return switch (args[0].tag()) {
        .string => parseI64(rt, string_mod.asString(args[0]), 10, "Long/valueOf", loc),
        .integer => args[0],
        else => error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "Long/valueOf", .actual = @tagName(args[0].tag()) }),
    };
}

/// `Long/toBinaryString` / `toHexString` / `toOctalString`: view the
/// value's full 64 bits as two's-complement u64 (Java long width) and
/// format in the radix with no leading zeros. Mirrors Integer.zig's
/// factory at 64-bit width (the only difference; per ADR-0029 R4 the two
/// surfaces cannot share a factory across the java/ tree, and the body
/// is a thin `std.fmt` call with no Java-specific normalisation to hoist).
fn RadixString(comptime verb: []const u8, comptime name: []const u8) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = env;
            try error_catalog.checkArity("Long/" ++ name, args, 1, loc);
            const n = try error_catalog.expectInteger(args[0], "Long/" ++ name, loc);
            const wide: i64 = n; // expectInteger yields i48; sign-extend to i64
            const u: u64 = @bitCast(wide);
            // u64 needs ≤ 64 binary digits — the 70-byte buffer can't overflow.
            var buf: [70]u8 = undefined;
            const out = std.fmt.bufPrint(&buf, "{" ++ verb ++ "}", .{u}) catch unreachable;
            return string_mod.alloc(rt, out);
        }
    };
}

fn initLong(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const specs = .{
        .{ "parseLong", &parseLong },
        .{ "valueOf", &valueOf },
        .{ "toBinaryString", &RadixString("b", "toBinaryString").call },
        .{ "toHexString", &RadixString("x", "toHexString").call },
        .{ "toOctalString", &RadixString("o", "toOctalString").call },
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

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.lang.Long",
    .descriptor = &descriptor,
    .init = &initLong,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.Long",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
