// SPDX-License-Identifier: EPL-2.0
//! Arbitrary-precision BigDecimal per F-005 + ADR-0027 §2 Group D
//! slot 2.
//!
//! ## 5.9.c shape
//!
//! BigDecimal = (unscaled: *BigInt, scale: i32). Numeric value is
//! `unscaled * 10^(-scale)`. Mirrors JVM `java.math.BigDecimal`:
//!
//!   - `unscaled` is the integer significand, stored as a GC-managed
//!     BigInt (so the trace fn marks it; the BigInt carries its own
//!     finaliser).
//!   - `scale` is the decimal point's offset from the right of the
//!     unscaled integer. Positive scale = fractional value
//!     (`scale=2, unscaled=150` → 1.50). Negative scale = trailing
//!     zeros (`scale=-2, unscaled=15` → 1500).
//!
//! Phase 5.9.c lands the data shape + constructors + accessors only.
//! Arithmetic with rounding modes (add / sub / mul / div with
//! MathContext) lands at 5.9.d / 5.10. Reader-literal entry
//! (`1.5M` → BigDecimal) lands at 5.10.
//!
//! HeapTag slot 50 (Group D position 2, `big_decimal`) per F-004 +
//! ADR-0027.

const std = @import("std");
const value_mod = @import("../value/value.zig");
const HeapHeader = value_mod.HeapHeader;
const Value = value_mod.Value;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");
const mark_sweep = @import("../gc/mark_sweep.zig");
const big_int_mod = @import("big_int.zig");
const BigInt = big_int_mod.BigInt;

/// GC-managed BigDecimal. Wraps a `*BigInt` significand and an i32
/// decimal-point offset. `unscaled` itself is GC-managed; this
/// struct's trace fn keeps it alive.
pub const BigDecimal = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    unscaled: *BigInt,
    scale: i32,
    _pad2: [4]u8 = .{ 0, 0, 0, 0 },

    comptime {
        std.debug.assert(@alignOf(BigDecimal) >= 8);
        std.debug.assert(@offsetOf(BigDecimal, "header") == 0);
        // unscaled lands at the same offset as BigInt.m / Ratio.numer
        // so all three numeric heap structs share the trailing-pad
        // pattern.
        std.debug.assert(@offsetOf(BigDecimal, "unscaled") == @offsetOf(BigInt, "m"));
    }
};

/// Allocate a BigDecimal from an i64 unscaled value + i32 scale.
pub fn allocFromI64Scale(rt: *Runtime, unscaled_i64: i64, scale: i32) !Value {
    var u_m = try std.math.big.int.Managed.init(rt.gc.infra);
    defer u_m.deinit();
    try u_m.set(unscaled_i64);
    return allocFromManagedScale(rt, &u_m, scale);
}

/// Allocate a BigDecimal from a caller-built Managed unscaled
/// value + i32 scale. The caller retains ownership of the input
/// (this routine clones onto `rt.gc.infra` via `allocFromManaged`).
pub fn allocFromManagedScale(
    rt: *Runtime,
    unscaled: *const std.math.big.int.Managed,
    scale: i32,
) !Value {
    const unscaled_val = try big_int_mod.allocFromManaged(rt, unscaled);

    const bd = try rt.gc.alloc(BigDecimal);
    bd.* = .{
        .header = HeapHeader.init(.big_decimal),
        .unscaled = unscaled_val.decodePtr(*BigInt),
        .scale = scale,
    };
    return Value.encodeHeapPtr(.big_decimal, bd);
}

/// Decode a BigDecimal Value into its unscaled significand.
pub fn asUnscaled(v: Value) *const BigInt {
    std.debug.assert(v.tag() == .big_decimal);
    return v.decodePtr(*const BigDecimal).unscaled;
}

/// Decode a BigDecimal Value into its decimal-point scale offset.
pub fn asScale(v: Value) i32 {
    std.debug.assert(v.tag() == .big_decimal);
    return v.decodePtr(*const BigDecimal).scale;
}

/// Trace fn called by the mark phase. Walks `unscaled` so the
/// underlying BigInt + its *Managed limbs stay alive across GC
/// cycles. BigDecimal itself has no non-GC owned resources.
pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const bd: *BigDecimal = @ptrCast(@alignCast(header));
    mark_sweep.mark(gc, &bd.unscaled.header);
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.big_decimal, &traceGc);
}

// --- same-type arithmetic (5.9.d) ---
//
// BigDecimal add/sub/compare align both operands to the larger
// scale by multiplying the smaller-scale unscaled value by
// 10^(scale_diff). `mul` multiplies unscaled values and sums
// scales (JVM convention; no precision loss). `div` requires a
// MathContext (rounding mode + precision) and lands at 5.10.

/// Three-way compare two BigDecimal Values. Aligns scales then
/// compares unscaled values. Both inputs MUST have
/// `tag() == .big_decimal`.
pub fn compareValue(rt: *Runtime, a: Value, b: Value) !std.math.Order {
    std.debug.assert(a.tag() == .big_decimal and b.tag() == .big_decimal);
    var aligned_a: std.math.big.int.Managed = undefined;
    var aligned_b: std.math.big.int.Managed = undefined;
    try alignScales(rt, a, b, &aligned_a, &aligned_b);
    defer aligned_a.deinit();
    defer aligned_b.deinit();
    return aligned_a.order(aligned_b);
}

/// `a + b` returning a fresh BigDecimal with `scale = max(a.scale, b.scale)`.
pub fn allocAdd(rt: *Runtime, a: Value, b: Value) !Value {
    return try alignedCombine(rt, a, b, .add);
}

/// `a - b`.
pub fn allocSub(rt: *Runtime, a: Value, b: Value) !Value {
    return try alignedCombine(rt, a, b, .sub);
}

/// `a * b` — unscaled values multiply, scales add.
pub fn allocMul(rt: *Runtime, a: Value, b: Value) !Value {
    std.debug.assert(a.tag() == .big_decimal and b.tag() == .big_decimal);
    const ad = a.decodePtr(*const BigDecimal);
    const bd = b.decodePtr(*const BigDecimal);

    var u = try std.math.big.int.Managed.init(rt.gc.infra);
    defer u.deinit();
    try u.mul(ad.unscaled.m, bd.unscaled.m);

    return try allocFromManagedScale(rt, &u, ad.scale + bd.scale);
}

const AddOrSub = enum { add, sub };

fn alignedCombine(rt: *Runtime, a: Value, b: Value, op: AddOrSub) !Value {
    std.debug.assert(a.tag() == .big_decimal and b.tag() == .big_decimal);
    const ad = a.decodePtr(*const BigDecimal);
    const bd = b.decodePtr(*const BigDecimal);

    var aligned_a: std.math.big.int.Managed = undefined;
    var aligned_b: std.math.big.int.Managed = undefined;
    try alignScales(rt, a, b, &aligned_a, &aligned_b);
    defer aligned_a.deinit();
    defer aligned_b.deinit();

    var r = try std.math.big.int.Managed.init(rt.gc.infra);
    defer r.deinit();
    switch (op) {
        .add => try r.add(&aligned_a, &aligned_b),
        .sub => try r.sub(&aligned_a, &aligned_b),
    }

    const result_scale = @max(ad.scale, bd.scale);
    return try allocFromManagedScale(rt, &r, result_scale);
}

/// Initialise `aligned_a` / `aligned_b` such that both represent
/// the same numeric values with the common scale `max(a.scale, b.scale)`.
/// Caller MUST `deinit` both outputs.
fn alignScales(
    rt: *Runtime,
    a: Value,
    b: Value,
    aligned_a: *std.math.big.int.Managed,
    aligned_b: *std.math.big.int.Managed,
) !void {
    const ad = a.decodePtr(*const BigDecimal);
    const bd = b.decodePtr(*const BigDecimal);
    const target_scale = @max(ad.scale, bd.scale);

    aligned_a.* = try cloneAndScale(rt, ad.unscaled.m, target_scale - ad.scale);
    errdefer aligned_a.deinit();
    aligned_b.* = try cloneAndScale(rt, bd.unscaled.m, target_scale - bd.scale);
}

/// Clone `src` and multiply by 10^extra_scale (extra_scale >= 0).
fn cloneAndScale(rt: *Runtime, src: *const std.math.big.int.Managed, extra_scale: i32) !std.math.big.int.Managed {
    var out = try src.cloneWithDifferentAllocator(rt.gc.infra);
    errdefer out.deinit();
    if (extra_scale > 0) {
        var ten = try std.math.big.int.Managed.init(rt.gc.infra);
        defer ten.deinit();
        try ten.set(10);
        var multiplier = try std.math.big.int.Managed.init(rt.gc.infra);
        defer multiplier.deinit();
        try multiplier.set(1);
        var i: i32 = 0;
        while (i < extra_scale) : (i += 1) {
            var tmp = try std.math.big.int.Managed.init(rt.gc.infra);
            defer tmp.deinit();
            try tmp.mul(&multiplier, &ten);
            multiplier.swap(&tmp);
        }
        var product = try std.math.big.int.Managed.init(rt.gc.infra);
        defer product.deinit();
        try product.mul(&out, &multiplier);
        out.swap(&product);
    }
    return out;
}

// --- tests ---

const testing = std.testing;

const BdFixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,

    fn init() BdFixture {
        var fix: BdFixture = .{
            .threaded = std.Io.Threaded.init(testing.allocator, .{}),
            .rt = undefined,
        };
        fix.rt = Runtime.init(fix.threaded.io(), testing.allocator);
        return fix;
    }
    fn deinit(self: *BdFixture) void {
        self.rt.deinit();
        self.threaded.deinit();
    }
};

test "BigDecimal extern struct layout matches the numeric trailing-pad pattern" {
    try testing.expectEqual(@as(usize, 0), @offsetOf(BigDecimal, "header"));
    try testing.expectEqual(@offsetOf(BigInt, "m"), @offsetOf(BigDecimal, "unscaled"));
    try testing.expect(@alignOf(BigDecimal) >= 8);
}

test "allocFromI64Scale (150, 2) represents 1.50 — accessors round-trip" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const v = try allocFromI64Scale(&fix.rt, 150, 2);
    try testing.expect(v.tag() == .big_decimal);
    try testing.expectEqual(@as(i64, 150), try big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(v))).toInt(i64));
    try testing.expectEqual(@as(i32, 2), asScale(v));
}

test "allocFromI64Scale (15, -2) represents 1500 — negative scale supported" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const v = try allocFromI64Scale(&fix.rt, 15, -2);
    try testing.expectEqual(@as(i64, 15), try big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(v))).toInt(i64));
    try testing.expectEqual(@as(i32, -2), asScale(v));
}

test "allocFromManagedScale supports unscaled > i64 (2^70 with scale=5)" {
    var fix = BdFixture.init();
    defer fix.deinit();

    var big = try std.math.big.int.Managed.init(testing.allocator);
    defer big.deinit();
    try big.set(1);
    try big.shiftLeft(&big, 70);

    const v = try allocFromManagedScale(&fix.rt, &big, 5);
    try testing.expect(big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(v))).bitCountAbs() > 64);
    try testing.expectEqual(@as(i32, 5), asScale(v));
}

test "compareValue (1.50 vs 1.5): equal numerically despite different scale" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const a = try allocFromI64Scale(&fix.rt, 150, 2); // 1.50
    const b = try allocFromI64Scale(&fix.rt, 15, 1);  // 1.5
    try testing.expectEqual(std.math.Order.eq, try compareValue(&fix.rt, a, b));
}

test "compareValue (1.5 vs 2.0): lt" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const a = try allocFromI64Scale(&fix.rt, 15, 1);
    const b = try allocFromI64Scale(&fix.rt, 20, 1);
    try testing.expectEqual(std.math.Order.lt, try compareValue(&fix.rt, a, b));
}

test "allocAdd (1.50 + 0.5) = 2.00 (scale 2)" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const a = try allocFromI64Scale(&fix.rt, 150, 2);
    const b = try allocFromI64Scale(&fix.rt, 5, 1);
    const sum = try allocAdd(&fix.rt, a, b);
    // 1.50 + 0.5 = 1.50 + 0.50 = 2.00 -> unscaled=200, scale=2
    try testing.expectEqual(@as(i64, 200), try big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(sum))).toInt(i64));
    try testing.expectEqual(@as(i32, 2), asScale(sum));
}

test "allocSub (3.00 - 1.5) = 1.50" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const a = try allocFromI64Scale(&fix.rt, 300, 2);
    const b = try allocFromI64Scale(&fix.rt, 15, 1);
    const diff = try allocSub(&fix.rt, a, b);
    try testing.expectEqual(@as(i64, 150), try big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(diff))).toInt(i64));
    try testing.expectEqual(@as(i32, 2), asScale(diff));
}

test "allocMul (1.5 * 2.0): unscaled=300, scale=2 (= 3.00)" {
    var fix = BdFixture.init();
    defer fix.deinit();

    const a = try allocFromI64Scale(&fix.rt, 15, 1);
    const b = try allocFromI64Scale(&fix.rt, 20, 1);
    const prod = try allocMul(&fix.rt, a, b);
    try testing.expectEqual(@as(i64, 300), try big_int_mod.asManaged(Value.encodeHeapPtr(.big_int, asUnscaled(prod))).toInt(i64));
    try testing.expectEqual(@as(i32, 2), asScale(prod));
}

test "Runtime.deinit releases BigDecimal + unscaled BigInt (no leak)" {
    var fix = BdFixture.init();
    _ = try allocFromI64Scale(&fix.rt, 150, 2);
    _ = try allocFromI64Scale(&fix.rt, 1234567, 6);
    fix.deinit();
}
