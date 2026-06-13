// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.math.BigDecimal`.
//!
//! Backend: impl-only
//! Impl deps: big_decimal
//! Clojure peer: clojure.core/bigdec, clojure.core/+, clojure.core/-,
//!   clojure.core/*, clojure.core// (numeric tower auto-promotion)
//!
//! Thin wrapper over `runtime/numeric/big_decimal.zig` per F-009 — the impl
//! carries the `(unscaled BigInt, i32 scale)` representation declared by F-005.
//! Two surfaces: the static `cljw.java.math.BigDecimal` descriptor (rt.types
//! auto-import) carries the `ROUND_*` rounding-mode constants; the per-Runtime
//! native `.big_decimal` descriptor carries instance methods reached as
//! `(.setScale bd n mode)` — installed by `installNativeMethods` at runtime
//! init (D-097, the math.numeric-tower floor/ceil path D-420). Arithmetic
//! auto-promotion landed earlier via D-014a.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const Value = @import("../../value/value.zig").Value;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const big_decimal = @import("../../numeric/big_decimal.zig");

/// `(.setScale bd newScale roundingMode)` — JVM `BigDecimal.setScale(int, int)`.
/// `newScale` is the desired scale; `roundingMode` is a `ROUND_*` int constant.
fn setScale(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("setScale", args, 3, loc);
    if (args[0].tag() != .big_decimal)
        return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "setScale", .actual = @tagName(args[0].tag()) });
    if (!args[1].isInt() or !args[2].isInt())
        return error_catalog.raise(.type_arg_not_number, loc, .{ .fn_name = "setScale", .actual = "non-integer scale/mode" });
    return big_decimal.setScale(rt, args[0], @intCast(args[1].asInteger()), args[2].asInteger()) catch |e| switch (e) {
        error.RoundingNecessary => error_catalog.raise(.rounding_necessary, loc, .{}),
        error.InvalidRoundingMode => error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "setScale", .expected = "a ROUND_* mode (0-7)", .actual = "an unknown rounding mode" }),
        else => e,
    };
}

/// Populate the per-Runtime native `.big_decimal` descriptor's `method_table`
/// (D-097). Driven from `lang/primitive.zig` at runtime init (Layer 2 — Layer 0
/// `runtime/` may not import this surface). Idempotent: a non-empty table
/// short-circuits. Allocations land on `rt.gc.infra` (freed by the
/// native-descriptor pass in `Runtime.deinit`).
pub fn installNativeMethods(rt: *Runtime) !void {
    const td = try rt.nativeDescriptor(.big_decimal);
    if (td.method_table.len != 0) return; // idempotent re-run
    const gpa = rt.gc.infra;
    const specs = .{
        .{ "setScale", &setScale },
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
    .cljw_ns = "cljw.java.math.BigDecimal",
    .descriptor = &descriptor,
};

/// The deprecated-but-still-public `BigDecimal.ROUND_*` int constants
/// (java.math.BigDecimal). Real Clojure libs (clojure.math.numeric-tower's
/// floor/ceil) read them for `(.setScale n 0 BigDecimal/ROUND_FLOOR)`.
const big_decimal_static_fields = [_]type_descriptor.TypeDescriptor.StaticField{
    .{ .name = "ROUND_UP", .value = .{ .int = 0 } },
    .{ .name = "ROUND_DOWN", .value = .{ .int = 1 } },
    .{ .name = "ROUND_CEILING", .value = .{ .int = 2 } },
    .{ .name = "ROUND_FLOOR", .value = .{ .int = 3 } },
    .{ .name = "ROUND_HALF_UP", .value = .{ .int = 4 } },
    .{ .name = "ROUND_HALF_DOWN", .value = .{ .int = 5 } },
    .{ .name = "ROUND_HALF_EVEN", .value = .{ .int = 6 } },
    .{ .name = "ROUND_UNNECESSARY", .value = .{ .int = 7 } },
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.math.BigDecimal",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
    .static_fields = &big_decimal_static_fields,
};
