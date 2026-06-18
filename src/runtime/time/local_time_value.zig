// SPDX-License-Identifier: EPL-2.0
//! `java.time.LocalTime` VALUE (D-462) — a timezone-agnostic time-of-day.
//!
//! Mirrors the LocalDate model (`local_date_value.zig`): a no-slot cljw-native
//! `.typed_instance` (F-004 layout UNCHANGED, no NaN-box tag) carrying ONE
//! integer field — `nano_of_day` (in [0, 86_400_000_000_000)) — plus a
//! per-Runtime `.native` descriptor whose `temporal_print = .iso_local_time`
//! makes the printer emit the bare ISO local time string (NO `#tag`, no quotes
//! — clj's `(str lt)` form). The time format/parse halves are reused from
//! `instant.zig` (F-009 neutral home); the Java `java.time.LocalTime` static
//! surface (`runtime/java/time/LocalTime.zig`) mints these from above.
//!
//! Distinct from the other temporal types by the per-Runtime descriptor
//! pointer (so `=` / print / `(class …)` discriminate) and by carrying the
//! instance methods getHour / getMinute / getSecond / getNano.

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

/// `(.getHour t)` — the hour-of-day 0..23 (JVM `LocalTime.getHour`).
fn getHourFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getHour", args, 1, loc);
    return Value.initInteger(@divTrunc(nanoOfDayOf(args[0]), 3_600_000_000_000));
}

/// `(.getMinute t)` — the minute-of-hour 0..59 (JVM `LocalTime.getMinute`).
fn getMinuteFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getMinute", args, 1, loc);
    return Value.initInteger(@rem(@divTrunc(nanoOfDayOf(args[0]), 60_000_000_000), 60));
}

/// `(.getSecond t)` — the second-of-minute 0..59 (JVM `LocalTime.getSecond`).
fn getSecondFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getSecond", args, 1, loc);
    return Value.initInteger(@rem(@divTrunc(nanoOfDayOf(args[0]), 1_000_000_000), 60));
}

/// `(.getNano t)` — the nanosecond-of-second 0..999_999_999 (JVM
/// `LocalTime.getNano`).
fn getNanoFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getNano", args, 1, loc);
    return Value.initInteger(@rem(nanoOfDayOf(args[0]), 1_000_000_000));
}

/// `(.isBefore a b)` — true when `a` is before `b` (JVM `LocalTime.isBefore`).
fn isBeforeFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("isBefore", args, 2, loc);
    if (!isLocalTime(rt, args[1]))
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = ".isBefore", .expected = "LocalTime", .actual = @tagName(args[1].tag()) });
    return Value.initBoolean(nanoOfDayOf(args[0]) < nanoOfDayOf(args[1]));
}

/// `(.isAfter a b)` — true when `a` is after `b` (JVM `LocalTime.isAfter`).
fn isAfterFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("isAfter", args, 2, loc);
    if (!isLocalTime(rt, args[1]))
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = ".isAfter", .expected = "LocalTime", .actual = @tagName(args[1].tag()) });
    return Value.initBoolean(nanoOfDayOf(args[0]) > nanoOfDayOf(args[1]));
}

/// The per-Runtime canonical LocalTime descriptor (lazily allocated on
/// `gc.infra`; freed in `Runtime.deinit`). `fqcn = "LocalTime"` so
/// `(class …)` prints the simple name (AD-003 / no-JVM);
/// `temporal_print = .iso_local_time` drives the bare ISO local-time print form.
/// Carries the instance methods.
pub fn descriptorOf(rt: *Runtime) !*const TypeDescriptor {
    if (rt.local_time_descriptor) |d| return d;
    const td = try rt.gc.infra.create(TypeDescriptor);
    td.* = .{
        .fqcn = "LocalTime",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
        .temporal_print = .iso_local_time,
    };
    const specs = .{
        .{ "getHour", &getHourFn },
        .{ "getMinute", &getMinuteFn },
        .{ "getSecond", &getSecondFn },
        .{ "getNano", &getNanoFn },
        .{ "isBefore", &isBeforeFn },
        .{ "isAfter", &isAfterFn },
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
    rt.local_time_descriptor = td;
    return td;
}

/// Build a LocalTime from `nano_of_day` (in [0, 86_400_000_000_000)). One
/// typed_instance field.
pub fn make(rt: *Runtime, nano_of_day: i64) !Value {
    const td = try descriptorOf(rt);
    return td_mod.allocInstance(rt, td, &.{Value.initInteger(nano_of_day)});
}

/// True when `v` is a LocalTime (carries the per-Runtime descriptor).
pub fn isLocalTime(rt: *Runtime, v: Value) bool {
    if (v.tag() != .typed_instance) return false;
    const d = rt.local_time_descriptor orelse return false;
    return v.decodePtr(*const TypedInstance).descriptor == d;
}

/// The `nano_of_day` field. Caller must have checked `isLocalTime`.
pub fn nanoOfDayOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[0].asInteger();
}

/// Free the per-Runtime descriptor (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitDescriptor(rt: *Runtime) void {
    if (rt.local_time_descriptor) |td| {
        for (td.method_table) |e| rt.gc.infra.free(e.method_name);
        if (td.method_table.len > 0) rt.gc.infra.free(td.method_table);
        rt.gc.infra.destroy(td);
        rt.local_time_descriptor = null;
    }
}

// --- tests ---

const testing = std.testing;

test "LocalTime value: make / isLocalTime / accessors + temporal_print set" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const nod: i64 = ((14 * 60 + 5) * 60 + 45) * 1_000_000_000 + 123_456_789;
    const t = try make(&rt, nod);
    try testing.expect(t.tag() == .typed_instance);
    try testing.expect(isLocalTime(&rt, t));
    try testing.expectEqual(nod, nanoOfDayOf(t));
    try testing.expect(t.decodePtr(*const TypedInstance).descriptor.temporal_print == .iso_local_time);
    try testing.expect(!isLocalTime(&rt, Value.initInteger(5)));
}
