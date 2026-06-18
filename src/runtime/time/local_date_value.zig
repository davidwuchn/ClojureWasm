// SPDX-License-Identifier: EPL-2.0
//! `java.time.LocalDate` VALUE (D-462) — a timezone-agnostic calendar date.
//!
//! Mirrors the LocalDateTime model (`local_date_time_value.zig`): a no-slot
//! cljw-native `.typed_instance` (F-004 layout UNCHANGED, no NaN-box tag)
//! carrying ONE integer field — `epoch_day` (signed days since 1970-01-01,
//! via the Hinnant civil algorithm in `instant.zig`) — plus a per-Runtime
//! `.native` descriptor whose `temporal_print = .iso_local_date` makes the
//! printer emit the bare ISO local date string (NO `#tag`, no quotes — clj's
//! `(str ld)` form). The civil↔epoch-day conversions + the date format/parse
//! halves are reused from `instant.zig` (F-009 neutral home); the Java
//! `java.time.LocalDate` static surface (`runtime/java/time/LocalDate.zig`)
//! mints these from above.
//!
//! Distinct from the other temporal types by the per-Runtime descriptor
//! pointer (so `=` / print / `(class …)` discriminate) and by carrying the
//! instance methods getYear / getMonthValue / getDayOfMonth / plusDays.

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

/// `(.getYear d)` — the proleptic year (JVM `LocalDate.getYear`).
fn getYearFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getYear", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).y);
}

/// `(.getMonthValue d)` — the month 1..12 (JVM `LocalDate.getMonthValue`).
fn getMonthValueFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getMonthValue", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).m);
}

/// `(.getDayOfMonth d)` — the day-of-month 1..31 (JVM `LocalDate.getDayOfMonth`).
fn getDayOfMonthFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("getDayOfMonth", args, 1, loc);
    return Value.initInteger(instant.civilFromDays(epochDayOf(args[0])).d);
}

/// `(.plusDays d n)` — the date `n` days later (JVM `LocalDate.plusDays`).
/// Mints a fresh LocalDate.
fn plusDaysFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("plusDays", args, 2, loc);
    if (args[1].tag() != .integer)
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "plusDays", .expected = "integer", .actual = @tagName(args[1].tag()) });
    return make(rt, epochDayOf(args[0]) + args[1].asInteger());
}

/// `(.isBefore a b)` — true when `a` is before `b` (JVM `LocalDate.isBefore`).
fn isBeforeFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("isBefore", args, 2, loc);
    if (!isLocalDate(rt, args[1]))
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = ".isBefore", .expected = "LocalDate", .actual = @tagName(args[1].tag()) });
    return Value.initBoolean(epochDayOf(args[0]) < epochDayOf(args[1]));
}

/// `(.isAfter a b)` — true when `a` is after `b` (JVM `LocalDate.isAfter`).
fn isAfterFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("isAfter", args, 2, loc);
    if (!isLocalDate(rt, args[1]))
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = ".isAfter", .expected = "LocalDate", .actual = @tagName(args[1].tag()) });
    return Value.initBoolean(epochDayOf(args[0]) > epochDayOf(args[1]));
}

/// `(.isEqual a b)` — true when `a` equals `b` (JVM `LocalDate.isEqual`).
fn isEqualFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("isEqual", args, 2, loc);
    if (!isLocalDate(rt, args[1]))
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = ".isEqual", .expected = "LocalDate", .actual = @tagName(args[1].tag()) });
    return Value.initBoolean(epochDayOf(args[0]) == epochDayOf(args[1]));
}

/// The per-Runtime canonical LocalDate descriptor (lazily allocated on
/// `gc.infra`; freed in `Runtime.deinit`). `fqcn = "LocalDate"` so
/// `(class …)` prints the simple name (AD-003 / no-JVM);
/// `temporal_print = .iso_local_date` drives the bare ISO local-date print form.
/// Carries the instance methods.
pub fn descriptorOf(rt: *Runtime) !*const TypeDescriptor {
    if (rt.local_date_descriptor) |d| return d;
    const td = try rt.gc.infra.create(TypeDescriptor);
    td.* = .{
        .fqcn = "LocalDate",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
        .temporal_print = .iso_local_date,
    };
    const specs = .{
        .{ "getYear", &getYearFn },
        .{ "getMonthValue", &getMonthValueFn },
        .{ "getDayOfMonth", &getDayOfMonthFn },
        .{ "plusDays", &plusDaysFn },
        .{ "isBefore", &isBeforeFn },
        .{ "isAfter", &isAfterFn },
        .{ "isEqual", &isEqualFn },
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
    rt.local_date_descriptor = td;
    return td;
}

/// Build a LocalDate from `epoch_day` (signed days since 1970-01-01). One
/// typed_instance field.
pub fn make(rt: *Runtime, epoch_day: i64) !Value {
    const td = try descriptorOf(rt);
    return td_mod.allocInstance(rt, td, &.{Value.initInteger(epoch_day)});
}

/// True when `v` is a LocalDate (carries the per-Runtime descriptor).
pub fn isLocalDate(rt: *Runtime, v: Value) bool {
    if (v.tag() != .typed_instance) return false;
    const d = rt.local_date_descriptor orelse return false;
    return v.decodePtr(*const TypedInstance).descriptor == d;
}

/// The `epoch_day` field. Caller must have checked `isLocalDate`.
pub fn epochDayOf(v: Value) i64 {
    return v.decodePtr(*const TypedInstance).fields()[0].asInteger();
}

/// Free the per-Runtime descriptor (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitDescriptor(rt: *Runtime) void {
    if (rt.local_date_descriptor) |td| {
        for (td.method_table) |e| rt.gc.infra.free(e.method_name);
        if (td.method_table.len > 0) rt.gc.infra.free(td.method_table);
        rt.gc.infra.destroy(td);
        rt.local_date_descriptor = null;
    }
}

// --- tests ---

const testing = std.testing;

test "LocalDate value: make / isLocalDate / accessors + temporal_print set" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const epoch_day = instant.daysFromCivil(2024, 3, 9);
    const d = try make(&rt, epoch_day);
    try testing.expect(d.tag() == .typed_instance);
    try testing.expect(isLocalDate(&rt, d));
    try testing.expectEqual(epoch_day, epochDayOf(d));
    try testing.expect(d.decodePtr(*const TypedInstance).descriptor.temporal_print == .iso_local_date);
    try testing.expect(!isLocalDate(&rt, Value.initInteger(5)));
}
