// SPDX-License-Identifier: EPL-2.0
//! `java.time.LocalDateTime` VALUE (D-462) — a timezone-agnostic date+time.
//!
//! Mirrors the Instant/Duration model (`instant_value.zig` /
//! `duration_value.zig`): a no-slot cljw-native `.typed_instance` (F-004
//! layout UNCHANGED, no NaN-box tag) carrying TWO integer fields —
//! `epoch_day` (signed days since 1970-01-01, via the Hinnant civil algorithm
//! in `instant.zig`) + `nano_of_day` (in [0, 86_400_000_000_000)) — plus a
//! per-Runtime `.native` descriptor whose `temporal_print = .iso_local_date_time`
//! makes the printer emit the bare ISO local date-time string (NO `#tag`, no
//! quotes — clj's `(str ldt)` form). The civil↔epoch-day conversions are
//! reused from `instant.zig` (F-009 neutral home); the Java
//! `java.time.LocalDateTime` static surface (`runtime/java/time/LocalDateTime.zig`)
//! mints these from above.
//!
//! Distinct from Instant/Duration/Date/Timestamp by the per-Runtime descriptor
//! pointer (so `=` / print / `(class …)` discriminate) and by carrying the
//! instance methods getYear / getMonthValue / getDayOfMonth / getHour /
//! getMinute / getSecond / getNano.

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
const instant = @import("instant.zig");
const local_date_value = @import("local_date_value.zig");
const local_time_value = @import("local_time_value.zig");

/// `(.getYear d)` — the proleptic year (JVM `LocalDateTime.getYear`).
fn getYearFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getYear", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).y);
}

/// `(.getMonthValue d)` — the month 1..12 (JVM `LocalDateTime.getMonthValue`).
fn getMonthValueFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getMonthValue", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).m);
}

/// `(.getDayOfMonth d)` — the day-of-month 1..31 (JVM `LocalDateTime.getDayOfMonth`).
fn getDayOfMonthFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getDayOfMonth", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).d);
}

/// `(.getHour d)` — the hour-of-day 0..23 (JVM `LocalDateTime.getHour`).
fn getHourFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getHour", args, 1, loc);
    return Value.initInteger(@divTrunc(nanoOfDayOf(args[0]), 3_600_000_000_000));
}

/// `(.getMinute d)` — the minute-of-hour 0..59 (JVM `LocalDateTime.getMinute`).
fn getMinuteFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getMinute", args, 1, loc);
    return Value.initInteger(@rem(@divTrunc(nanoOfDayOf(args[0]), 60_000_000_000), 60));
}

/// `(.getSecond d)` — the second-of-minute 0..59 (JVM `LocalDateTime.getSecond`).
fn getSecondFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getSecond", args, 1, loc);
    return Value.initInteger(@rem(@divTrunc(nanoOfDayOf(args[0]), 1_000_000_000), 60));
}

/// `(.getNano d)` — the nanosecond-of-second 0..999_999_999 (JVM
/// `LocalDateTime.getNano`).
fn getNanoFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getNano", args, 1, loc);
    return Value.initInteger(@rem(nanoOfDayOf(args[0]), 1_000_000_000));
}

/// `(.toLocalDate d)` — the date half as a LocalDate (JVM
/// `LocalDateTime.toLocalDate`).
fn toLocalDateFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("toLocalDate", args, 1, loc);
    return local_date_value.make(rt, epochDayOf(args[0]));
}

/// `(.toLocalTime d)` — the time half as a LocalTime (JVM
/// `LocalDateTime.toLocalTime`).
fn toLocalTimeFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("toLocalTime", args, 1, loc);
    return local_time_value.make(rt, nanoOfDayOf(args[0]));
}

/// The per-Runtime canonical LocalDateTime descriptor (lazily allocated on
/// `gc.infra`; freed in `Runtime.deinit`). `fqcn = "LocalDateTime"` so
/// `(class …)` prints the simple name (AD-003 / no-JVM);
/// `temporal_print = .iso_local_date_time` drives the bare ISO-local print form.
/// Carries the instance methods.
pub fn descriptorOf(rt: *Runtime) !*const TypeDescriptor {
    if (rt.local_date_time_descriptor) |d| return d;
    const td = try rt.gc.infra.create(TypeDescriptor);
    td.* = .{
        .fqcn = "LocalDateTime",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
        .temporal_print = .iso_local_date_time,
    };
    const specs = .{
        .{ "getYear", &getYearFn },
        .{ "getMonthValue", &getMonthValueFn },
        .{ "getDayOfMonth", &getDayOfMonthFn },
        .{ "getHour", &getHourFn },
        .{ "getMinute", &getMinuteFn },
        .{ "getSecond", &getSecondFn },
        .{ "getNano", &getNanoFn },
        .{ "toLocalDate", &toLocalDateFn },
        .{ "toLocalTime", &toLocalTimeFn },
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
    rt.local_date_time_descriptor = td;
    return td;
}

/// Build a LocalDateTime from `epoch_day` (signed) + `nano_of_day`
/// (in [0, 86_400_000_000_000)). Two typed_instance fields.
pub fn make(rt: *Runtime, epoch_day: i64, nano_of_day: i64) !Value {
    const td = try descriptorOf(rt);
    return td_mod.allocInstance(rt, td, &.{ Value.initInteger(epoch_day), Value.initInteger(nano_of_day) });
}

/// True when `v` is a LocalDateTime (carries the per-Runtime descriptor).
pub fn isLocalDateTime(rt: *Runtime, v: Value) bool {
    if (v.tag() != .typed_instance) return false;
    const d = rt.local_date_time_descriptor orelse return false;
    return v.decodePtr(*const TypedInstance).descriptor == d;
}

/// The `epoch_day` field. Caller must have checked `isLocalDateTime`.
pub fn epochDayOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[0].asInteger();
}

/// The `nano_of_day` field. Caller must have checked `isLocalDateTime`.
pub fn nanoOfDayOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[1].asInteger();
}

/// Free the per-Runtime descriptor (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitDescriptor(rt: *Runtime) void {
    if (rt.local_date_time_descriptor) |td| {
        for (td.method_table) |e| rt.gc.infra.free(e.method_name);
        if (td.method_table.len > 0) rt.gc.infra.free(td.method_table);
        rt.gc.infra.destroy(td);
        rt.local_date_time_descriptor = null;
    }
}

/// Format a LocalDateTime (`epoch_day` signed + `nano_of_day` in
/// [0, 86_400_000_000_000)) as the bare ISO local date-time string clj's
/// `(str ldt)` emits — `formatLocalDate ++ "T" ++ formatLocalTime` (the two
/// halves it shares with LocalDate / LocalTime, both in `instant.zig` the
/// F-009 neutral home). `buf` must be ≥ 35 bytes; returns the written slice.
/// Year is assumed [0, 9999] (4-digit pad).
pub fn formatLocalDateTime(buf: []u8, epoch_day: i64, nano_of_day: i64) []const u8 {
    const date = instant.formatLocalDate(buf, epoch_day);
    var len = date.len;
    buf[len] = 'T';
    len += 1;
    const time = instant.formatLocalTime(buf[len..], nano_of_day);
    return buf[0 .. len + time.len];
}

// --- tests ---

const testing = std.testing;

test "LocalDateTime value: make / isLocalDateTime / accessors + temporal_print set" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const epoch_day = instant.daysFromCivil(2024, 3, 9);
    const nod: i64 = ((14 * 60 + 5) * 60 + 45) * 1_000_000_000 + 123_456_789;
    const d = try make(&rt, epoch_day, nod);
    try testing.expect(d.tag() == .typed_instance);
    try testing.expect(isLocalDateTime(&rt, d));
    try testing.expectEqual(epoch_day, epochDayOf(d));
    try testing.expectEqual(nod, nanoOfDayOf(d));
    try testing.expect(d.decodePtr(*const TypedInstance).descriptor.temporal_print == .iso_local_date_time);
    try testing.expect(!isLocalDateTime(&rt, Value.initInteger(5)));
}

test "formatLocalDateTime: conditional seconds + variable fraction" {
    var buf: [40]u8 = undefined;
    const d0 = instant.daysFromCivil(2024, 1, 1);
    // h:mm only — sec == 0 && nano == 0
    try testing.expectEqualStrings("2024-01-01T12:30", formatLocalDateTime(&buf, d0, (12 * 60 + 30) * 60_000_000_000));
    // :ss appended — sec != 0
    try testing.expectEqualStrings("2024-01-01T12:30:45", formatLocalDateTime(&buf, d0, ((12 * 60 + 30) * 60 + 45) * 1_000_000_000));
    // :ss + 3-digit fraction — whole millisecond nano
    try testing.expectEqualStrings("2024-01-01T12:30:45.500", formatLocalDateTime(&buf, d0, ((12 * 60 + 30) * 60 + 45) * 1_000_000_000 + 500_000_000));
    // 9-digit fraction — sub-microsecond nano (sec != 0 so :ss present)
    try testing.expectEqualStrings("2024-03-09T14:05:45.123456789", formatLocalDateTime(&buf, instant.daysFromCivil(2024, 3, 9), ((14 * 60 + 5) * 60 + 45) * 1_000_000_000 + 123_456_789));
    // midnight — both zero, no :ss
    try testing.expectEqualStrings("2024-06-15T00:00", formatLocalDateTime(&buf, instant.daysFromCivil(2024, 6, 15), 0));
    // nano != 0 but sec == 0 — :00 still appended (sec-or-nano gate), then fraction
    try testing.expectEqualStrings("2024-01-01T12:30:00.250", formatLocalDateTime(&buf, d0, (12 * 60 + 30) * 60_000_000_000 + 250_000_000));
}
