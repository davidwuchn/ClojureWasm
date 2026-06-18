// SPDX-License-Identifier: EPL-2.0
//! `java.time.Month` enum VALUE (D-462) — the month-of-year.
//!
//! Mirrors the DayOfWeek model (`day_of_week_value.zig`): a no-slot cljw-native
//! `.typed_instance` (F-004 layout UNCHANGED, no NaN-box tag) carrying ONE
//! integer field — `value` (1=JANUARY .. 12=DECEMBER) — plus a per-Runtime
//! `.native` descriptor whose `temporal_print = .month` makes the printer emit
//! the bare enum NAME (NO `#tag`, no quotes — clj's `(str m)` form, e.g.
//! "MARCH"). Minted by LocalDate/LocalDateTime's `getMonth` getter.
//!
//! Distinct from the other temporal types by the per-Runtime descriptor
//! pointer (so `=` / print / `(class …)` discriminate). The lone instance
//! method is `getValue` (the 1..12 ordinal). Static-field access
//! (`Month/JANUARY`) is not yet provided — these are minted on demand.

const std = @import("std");
const value = @import("../value/value.zig");
const Value = value.Value;
const Runtime = @import("../runtime.zig").Runtime;
const Env = @import("../env.zig").Env;
const td_mod = @import("../type_descriptor.zig");
const TypeDescriptor = td_mod.TypeDescriptor;
const TypedInstance = td_mod.TypedInstance;
const error_catalog = @import("../error/catalog.zig");
const SourceLocation = @import("../error/info.zig").SourceLocation;

/// Month names, indexed by `value - 1` (1=JANUARY .. 12=DECEMBER). Public so the
/// printer's `.month` arm (`print.zig`) reads the bare NAME.
pub const NAMES = [_][]const u8{
    "JANUARY", "FEBRUARY", "MARCH",     "APRIL",   "MAY",      "JUNE",
    "JULY",    "AUGUST",   "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER",
};

/// The bare enum name for a month value 1..12 (`(str m)` form). Caller passes a
/// validated value; out-of-range asserts (a getter always supplies 1..12).
pub fn nameOf(v: i64) []const u8 {
    return NAMES[@intCast(v - 1)];
}

/// `(.getValue m)` — the month ordinal 1..12 (JVM `Month.getValue`).
fn getValueFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getValue", args, 1, loc);
    return Value.initInteger(valueOf(args[0]));
}

/// The per-Runtime canonical Month descriptor (lazily allocated on `gc.infra`;
/// freed in `Runtime.deinit`). `fqcn = "Month"` so `(class …)` prints the simple
/// name (AD-003 / no-JVM); `temporal_print = .month` drives the bare enum-NAME
/// print form.
pub fn descriptorOf(rt: *Runtime) !*const TypeDescriptor {
    if (rt.month_descriptor) |d| return d;
    const td = try rt.gc.infra.create(TypeDescriptor);
    td.* = .{
        .fqcn = "Month",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
        .temporal_print = .month,
    };
    const specs = .{
        .{ "getValue", &getValueFn },
    };
    const entries = try rt.gc.infra.alloc(TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try rt.gc.infra.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
    rt.month_descriptor = td;
    return td;
}

/// Build a Month from its ordinal `value` (1=JANUARY .. 12=DECEMBER). One
/// typed_instance field.
pub fn make(rt: *Runtime, value_in: i64) !Value {
    const td = try descriptorOf(rt);
    return td_mod.allocInstance(rt, td, &.{Value.initInteger(value_in)});
}

/// True when `v` is a Month (carries the per-Runtime descriptor).
pub fn isMonth(rt: *Runtime, v: Value) bool {
    if (v.tag() != .typed_instance) return false;
    const d = rt.month_descriptor orelse return false;
    return v.decodePtr(*const TypedInstance).descriptor == d;
}

/// The ordinal `value` field. Caller must have checked `isMonth`.
pub fn valueOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[0].asInteger();
}

/// Free the per-Runtime descriptor (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitDescriptor(rt: *Runtime) void {
    if (rt.month_descriptor) |td| {
        for (td.method_table) |e| rt.gc.infra.free(e.method_name);
        if (td.method_table.len > 0) rt.gc.infra.free(td.method_table);
        rt.gc.infra.destroy(td);
        rt.month_descriptor = null;
    }
}

// --- tests ---

const testing = std.testing;

test "Month value: make / isMonth / valueOf + temporal_print set + nameOf" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const m = try make(&rt, 3); // MARCH
    try testing.expect(m.tag() == .typed_instance);
    try testing.expect(isMonth(&rt, m));
    try testing.expectEqual(@as(i64, 3), valueOf(m));
    try testing.expect(m.decodePtr(*const TypedInstance).descriptor.temporal_print == .month);
    try testing.expect(!isMonth(&rt, Value.initInteger(5)));
    try testing.expectEqualStrings("JANUARY", nameOf(1));
    try testing.expectEqualStrings("MARCH", nameOf(3));
    try testing.expectEqualStrings("DECEMBER", nameOf(12));
}
