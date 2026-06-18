// SPDX-License-Identifier: EPL-2.0
//! `java.time.DayOfWeek` enum VALUE (D-462) — the ISO day-of-week.
//!
//! Mirrors the LocalDate/LocalTime model (`local_date_value.zig`): a no-slot
//! cljw-native `.typed_instance` (F-004 layout UNCHANGED, no NaN-box tag)
//! carrying ONE integer field — `value` (1=MONDAY .. 7=SUNDAY, ISO) — plus a
//! per-Runtime `.native` descriptor whose `temporal_print = .day_of_week`
//! makes the printer emit the bare enum NAME (NO `#tag`, no quotes — clj's
//! `(str dow)` form, e.g. "SATURDAY"). Minted by LocalDate/LocalDateTime's
//! `getDayOfWeek` getter.
//!
//! Distinct from the other temporal types by the per-Runtime descriptor
//! pointer (so `=` / print / `(class …)` discriminate). The lone instance
//! method is `getValue` (the 1..7 ISO ordinal). Static-field access
//! (`DayOfWeek/MONDAY`) is not yet provided — these are minted on demand.

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

/// ISO day-of-week names, indexed by `value - 1` (1=MONDAY .. 7=SUNDAY). Public
/// so the printer's `.day_of_week` arm (`print.zig`) reads the bare NAME.
pub const NAMES = [_][]const u8{ "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY" };

/// The bare enum name for an ISO value 1..7 (`(str dow)` form). Caller passes a
/// validated value; out-of-range asserts (a getter always supplies 1..7).
pub fn nameOf(v: i64) []const u8 {
    return NAMES[@intCast(v - 1)];
}

/// `(.getValue dow)` — the ISO ordinal 1..7 (JVM `DayOfWeek.getValue`).
fn getValueFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getValue", args, 1, loc);
    return Value.initInteger(valueOf(args[0]));
}

/// The per-Runtime canonical DayOfWeek descriptor (lazily allocated on
/// `gc.infra`; freed in `Runtime.deinit`). `fqcn = "DayOfWeek"` so
/// `(class …)` prints the simple name (AD-003 / no-JVM);
/// `temporal_print = .day_of_week` drives the bare enum-NAME print form.
pub fn descriptorOf(rt: *Runtime) !*const TypeDescriptor {
    if (rt.day_of_week_descriptor) |d| return d;
    const td = try rt.gc.infra.create(TypeDescriptor);
    td.* = .{
        .fqcn = "DayOfWeek",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
        .temporal_print = .day_of_week,
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
    rt.day_of_week_descriptor = td;
    return td;
}

/// Build a DayOfWeek from its ISO ordinal `value` (1=MONDAY .. 7=SUNDAY). One
/// typed_instance field.
pub fn make(rt: *Runtime, value_in: i64) !Value {
    const td = try descriptorOf(rt);
    return td_mod.allocInstance(rt, td, &.{Value.initInteger(value_in)});
}

/// True when `v` is a DayOfWeek (carries the per-Runtime descriptor).
pub fn isDayOfWeek(rt: *Runtime, v: Value) bool {
    if (v.tag() != .typed_instance) return false;
    const d = rt.day_of_week_descriptor orelse return false;
    return v.decodePtr(*const TypedInstance).descriptor == d;
}

/// The ISO ordinal `value` field. Caller must have checked `isDayOfWeek`.
pub fn valueOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[0].asInteger();
}

/// Free the per-Runtime descriptor (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitDescriptor(rt: *Runtime) void {
    if (rt.day_of_week_descriptor) |td| {
        for (td.method_table) |e| rt.gc.infra.free(e.method_name);
        if (td.method_table.len > 0) rt.gc.infra.free(td.method_table);
        rt.gc.infra.destroy(td);
        rt.day_of_week_descriptor = null;
    }
}

// --- tests ---

const testing = std.testing;

test "DayOfWeek value: make / isDayOfWeek / valueOf + temporal_print set + nameOf" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const dow = try make(&rt, 6); // SATURDAY
    try testing.expect(dow.tag() == .typed_instance);
    try testing.expect(isDayOfWeek(&rt, dow));
    try testing.expectEqual(@as(i64, 6), valueOf(dow));
    try testing.expect(dow.decodePtr(*const TypedInstance).descriptor.temporal_print == .day_of_week);
    try testing.expect(!isDayOfWeek(&rt, Value.initInteger(5)));
    try testing.expectEqualStrings("MONDAY", nameOf(1));
    try testing.expectEqualStrings("SATURDAY", nameOf(6));
    try testing.expectEqualStrings("SUNDAY", nameOf(7));
}
