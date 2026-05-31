// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.Double` static methods.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: clojure.core/parse-double
//!
//! Thin wrapper over the shared `runtime/numeric/parse.zig` leaf
//! (`parseFloat`, shared with `clojure.core/parse-double`, F-011 DRY) +
//! `std.math` predicates. `parseDouble` trims whitespace and rejects
//! `_` to match Java; an `Infinity` / `-Infinity` / `NaN` string parses
//! to the corresponding f64. Malformed input raises a `number_error`-Kind
//! Code → NumberFormatException (ADR-0060). isNaN / isInfinite widen an
//! integer arg to f64 (Java's `double` parameter).

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const parse = @import("../../numeric/parse.zig");
const string_mod = @import("../../collection/string.zig");

/// Implements `(Double/parseDouble s)`. Spec: parse an f64; malformed ⇒
/// NumberFormatException. Surrounding whitespace is trimmed (Java).
/// JVM reference: java.lang.Double#parseDouble.
/// cw v1 tier: A (§A26 clj differential sweep).
fn parseDouble(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Double/parseDouble", args, 1, loc);
    if (args[0].tag() != .string)
        return error_catalog.raise(.type_arg_not_string, loc, .{ .fn_name = "Double/parseDouble", .actual = @tagName(args[0].tag()) });
    const s = string_mod.asString(args[0]);
    const f = parse.parseFloat(s) catch
        return error_catalog.raise(.number_format_invalid, loc, .{ .fn_name = "Double/parseDouble", .text = s });
    return Value.initFloat(f);
}

/// `Double/isNaN` and `isInfinite` share one shape: widen the number arg
/// to f64 (Java's `double` parameter) and apply the std.math predicate.
fn Predicate(comptime name: []const u8, comptime f: fn (f64) bool) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = rt;
            _ = env;
            try error_catalog.checkArity("Double/" ++ name, args, 1, loc);
            const x = try error_catalog.expectNumber(args[0], "Double/" ++ name, loc);
            return if (f(x)) .true_val else .false_val;
        }
    };
}

fn isNanF(x: f64) bool {
    return std.math.isNan(x);
}
fn isInfF(x: f64) bool {
    return std.math.isInf(x);
}

fn initDouble(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const specs = .{
        .{ "parseDouble", &parseDouble },
        .{ "isNaN", &Predicate("isNaN", isNanF).call },
        .{ "isInfinite", &Predicate("isInfinite", isInfF).call },
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
    .cljw_ns = "cljw.java.lang.Double",
    .descriptor = &descriptor,
    .init = &initDouble,
};

// Static fields (ADR-0061) — comptime-const. Java Double.MAX_VALUE /
// MIN_VALUE = the largest finite double / smallest positive denormal.
// Values are exact; their scientific-notation print form is D-166.
const double_static_fields = [_]type_descriptor.TypeDescriptor.StaticField{
    .{ .name = "MAX_VALUE", .value = .{ .float = std.math.floatMax(f64) } },
    .{ .name = "MIN_VALUE", .value = .{ .float = std.math.floatTrueMin(f64) } },
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.Double",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .static_fields = &double_static_fields,
    .parent = null,
    .meta = .nil_val,
};
