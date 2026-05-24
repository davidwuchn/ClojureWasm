// SPDX-License-Identifier: EPL-2.0
//! Arbitrary-precision integer heap struct per F-005 + ADR-0012
//! amendment 1 + ADR-0027 §2 Group D slot 0.
//!
//! ## 5.9.a migration (resolves 5.3.d.9 deferral)
//!
//! BigInt is now an `extern struct` with HeapHeader at offset 0 +
//! a `*Managed` wrapper field. `std.math.big.int.Managed` cannot be
//! embedded directly in an extern struct (its `limbs: []Limb` slice
//! and `allocator: std.mem.Allocator` fields are not C-ABI-extern),
//! so we hold a pointer to a `Managed` allocated separately on the
//! infra_alloc (per F-006 §2 layer 1 — limbs live on GPA, not on
//! the GC heap, per the Block B reconciliation in ADR-0028 §2).
//!
//! The per-tag finaliser (`finaliseGc`, registered into
//! `tag_ops.tag_finaliser_table[.big_int]` at `registerGcHooks`)
//! deinitialises the Managed (releases limbs back to infra_alloc)
//! and destroys the Managed allocation before sweep rawFrees the
//! BigInt wrapper.
//!
//! HeapTag slot 48 (Group D position 0, `big_int`) per F-004 +
//! ADR-0027 §2. Phase 5 row 5.2.b rotated the slot from the g1
//! placement at 29 (released `wasm_module` slot per ADR-0006 a1 +
//! ADR-0012 a1) to the canonical Group D numeric block.

const std = @import("std");
const value_mod = @import("../value/value.zig");
const HeapHeader = value_mod.HeapHeader;
const Value = value_mod.Value;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");

/// Heap-allocated arbitrary-precision integer. The wrapper is GC-
/// managed; the `*Managed` it points at lives on `gc.infra` (process-
/// lifetime GPA per F-006). The finaliser releases both.
pub const BigInt = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    /// Pointer to a `Managed` allocated on `gc.infra`. The Managed
    /// owns its limb slice via its embedded allocator (also gc.infra).
    /// `finaliseGc` chains `m.deinit()` + `infra.destroy(m)`.
    m: *std.math.big.int.Managed,

    comptime {
        std.debug.assert(@alignOf(BigInt) >= 8);
        std.debug.assert(@offsetOf(BigInt, "header") == 0);
    }
};

/// Allocate a BigInt holding the i64 `v`. The Managed is constructed
/// on `rt.gc.infra` (GPA) per F-006 §2; the BigInt wrapper lives on
/// `rt.gc.alloc` (GC heap). Finaliser releases both at sweep time.
pub fn allocFromI64(rt: *Runtime, v: i64) !Value {
    const m_ptr = try rt.gc.infra.create(std.math.big.int.Managed);
    errdefer rt.gc.infra.destroy(m_ptr);
    m_ptr.* = try std.math.big.int.Managed.init(rt.gc.infra);
    errdefer m_ptr.deinit();
    try m_ptr.set(v);

    const bi = try rt.gc.alloc(BigInt);
    bi.* = .{ .header = HeapHeader.init(.big_int), .m = m_ptr };
    return Value.encodeHeapPtr(.big_int, bi);
}

/// Allocate a BigInt as a copy of an existing Managed. The source's
/// limbs are deep-copied through `Managed.clone` so the caller's
/// Managed can be deinit'd independently. Useful when arithmetic
/// produces a Managed result that needs to land on the GC heap.
///
/// **Note**: `Managed.setString` from `std.math.big.int` has a
/// known Linux glibc-x86 platform divergence in Zig 0.16 (off-by-
/// one result for values past i64). Until upstream lands a fix
/// (tracked in D-047), construct large BigInts via `set` + bit-shift
/// or via repeated arithmetic instead of base-10 string parsing.
pub fn allocFromManaged(rt: *Runtime, src: *const std.math.big.int.Managed) !Value {
    const m_ptr = try rt.gc.infra.create(std.math.big.int.Managed);
    errdefer rt.gc.infra.destroy(m_ptr);
    m_ptr.* = try src.cloneWithDifferentAllocator(rt.gc.infra);

    const bi = try rt.gc.alloc(BigInt);
    bi.* = .{ .header = HeapHeader.init(.big_int), .m = m_ptr };
    return Value.encodeHeapPtr(.big_int, bi);
}

/// Per-tag finaliser called by sweep before unlink + rawFree (or by
/// GcHeap.deinit on shutdown). Releases the Managed's limb storage
/// + destroys the Managed allocation itself.
pub fn finaliseGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const bi: *BigInt = @ptrCast(@alignCast(header));
    bi.m.deinit();
    gc.infra.destroy(bi.m);
}

/// BigInt has no Value fields → no trace fn needed (the GC walks
/// the live list, sees BigInt's tag, and skips the per-tag trace
/// table lookup when no entry is registered).
pub fn registerGcHooks() void {
    tag_ops.registerFinaliser(.big_int, &finaliseGc);
}

/// Decode a BigInt Value into its *Managed for read-only access.
pub fn asManaged(v: Value) *const std.math.big.int.Managed {
    std.debug.assert(v.tag() == .big_int);
    return v.decodePtr(*const BigInt).m;
}

// --- same-type arithmetic (5.9.d) ---
//
// Cross-type dispatch (Long ↔ BigInt ↔ Ratio ↔ BigDecimal) lands at
// 5.10 in `runtime/numeric/promote.zig`. The functions below are the
// per-type building blocks the dispatcher composes.

/// Three-way compare two BigInt Values (a vs b). Both Values MUST
/// have `tag() == .big_int`.
pub fn compareManaged(a: *const std.math.big.int.Managed, b: *const std.math.big.int.Managed) std.math.Order {
    return a.order(b.*);
}

/// Allocate `a + b` as a fresh BigInt on the GC heap. Limbs of the
/// result live on `rt.gc.infra`; the wrapper lives on `rt.gc.alloc`.
pub fn allocAddManaged(
    rt: *Runtime,
    a: *const std.math.big.int.Managed,
    b: *const std.math.big.int.Managed,
) !Value {
    var r = try std.math.big.int.Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.add(a, b);
    return allocFromManaged(rt, &r);
}

/// Allocate `a - b`.
pub fn allocSubManaged(
    rt: *Runtime,
    a: *const std.math.big.int.Managed,
    b: *const std.math.big.int.Managed,
) !Value {
    var r = try std.math.big.int.Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.sub(a, b);
    return allocFromManaged(rt, &r);
}

/// Allocate `a * b`.
pub fn allocMulManaged(
    rt: *Runtime,
    a: *const std.math.big.int.Managed,
    b: *const std.math.big.int.Managed,
) !Value {
    var r = try std.math.big.int.Managed.init(rt.gc.infra);
    defer r.deinit();
    try r.mul(a, b);
    return allocFromManaged(rt, &r);
}

/// Floor-divide `a / b` (integer quotient toward -∞). Raises
/// `error.DivideByZero` on `b == 0`. Cross-type promotion of
/// non-exact integer division to Ratio is the 5.10 dispatcher's
/// responsibility; this entry returns the floor quotient and
/// discards the remainder.
pub fn allocDivFloorManaged(
    rt: *Runtime,
    a: *const std.math.big.int.Managed,
    b: *const std.math.big.int.Managed,
) !Value {
    if (b.eqlZero()) return error.DivideByZero;
    var q = try std.math.big.int.Managed.init(rt.gc.infra);
    defer q.deinit();
    var r = try std.math.big.int.Managed.init(rt.gc.infra);
    defer r.deinit();
    try q.divFloor(&r, a, b);
    return allocFromManaged(rt, &q);
}

// --- tests ---

const testing = std.testing;

const RuntimeFixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,

    fn init() RuntimeFixture {
        var fix: RuntimeFixture = .{
            .threaded = std.Io.Threaded.init(testing.allocator, .{}),
            .rt = undefined,
        };
        fix.rt = Runtime.init(fix.threaded.io(), testing.allocator);
        return fix;
    }
    fn deinit(self: *RuntimeFixture) void {
        self.rt.deinit();
        self.threaded.deinit();
    }
};

test "BigInt extern struct layout: HeapHeader at offset 0, align ≥ 8" {
    try testing.expectEqual(@as(usize, 0), @offsetOf(BigInt, "header"));
    try testing.expect(@alignOf(BigInt) >= 8);
}

test "allocFromI64 + asManaged round-trip on small value" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    const v = try allocFromI64(&fix.rt, 12345);
    try testing.expect(v.tag() == .big_int);
    const m = asManaged(v);
    try testing.expectEqual(@as(i64, 12345), try m.toInt(i64));
}

test "allocFromI64 + asManaged round-trip on negative value" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    const v = try allocFromI64(&fix.rt, -987654321);
    const m = asManaged(v);
    try testing.expectEqual(@as(i64, -987654321), try m.toInt(i64));
}

test "allocFromManaged holds values beyond i64 range (2^65 via shiftLeft)" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    // 2^65 — beyond i64. Construct via `set(1)` + `shiftLeft(65)`
    // (avoids the Zig-0.16 Managed.setString Linux glibc-x86
    // off-by-one; see D-047 + allocFromManaged docstring).
    var src = try std.math.big.int.Managed.init(testing.allocator);
    defer src.deinit();
    try src.set(1);
    try src.shiftLeft(&src, 65);

    const v = try allocFromManaged(&fix.rt, &src);
    const m = asManaged(v);
    try testing.expect(m.bitCountAbs() > 64);
    try testing.expect(m.eql(src));
}

test "compareManaged orders (3 < 5 == 5)" {
    var a = try std.math.big.int.Managed.init(testing.allocator);
    defer a.deinit();
    try a.set(3);
    var b = try std.math.big.int.Managed.init(testing.allocator);
    defer b.deinit();
    try b.set(5);

    try testing.expectEqual(std.math.Order.lt, compareManaged(&a, &b));
    try testing.expectEqual(std.math.Order.gt, compareManaged(&b, &a));
    try testing.expectEqual(std.math.Order.eq, compareManaged(&a, &a));
}

test "allocAddManaged / SubManaged / MulManaged round-trip" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    var a = try std.math.big.int.Managed.init(testing.allocator);
    defer a.deinit();
    try a.set(7);
    var b = try std.math.big.int.Managed.init(testing.allocator);
    defer b.deinit();
    try b.set(5);

    const sum_v = try allocAddManaged(&fix.rt, &a, &b);
    try testing.expectEqual(@as(i64, 12), try asManaged(sum_v).toInt(i64));

    const diff_v = try allocSubManaged(&fix.rt, &a, &b);
    try testing.expectEqual(@as(i64, 2), try asManaged(diff_v).toInt(i64));

    const prod_v = try allocMulManaged(&fix.rt, &a, &b);
    try testing.expectEqual(@as(i64, 35), try asManaged(prod_v).toInt(i64));
}

test "allocDivFloorManaged raises DivideByZero on b=0" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    var a = try std.math.big.int.Managed.init(testing.allocator);
    defer a.deinit();
    try a.set(7);
    var z = try std.math.big.int.Managed.init(testing.allocator);
    defer z.deinit();
    try z.set(0);

    try testing.expectError(error.DivideByZero, allocDivFloorManaged(&fix.rt, &a, &z));
}

test "allocDivFloorManaged returns floor quotient (7 / 2 = 3)" {
    var fix = RuntimeFixture.init();
    defer fix.deinit();

    var a = try std.math.big.int.Managed.init(testing.allocator);
    defer a.deinit();
    try a.set(7);
    var b = try std.math.big.int.Managed.init(testing.allocator);
    defer b.deinit();
    try b.set(2);

    const q = try allocDivFloorManaged(&fix.rt, &a, &b);
    try testing.expectEqual(@as(i64, 3), try asManaged(q).toInt(i64));
}

test "Runtime.deinit releases BigInt + Managed limbs (no leak)" {
    var fix = RuntimeFixture.init();
    _ = try allocFromI64(&fix.rt, 42);
    _ = try allocFromI64(&fix.rt, std.math.maxInt(i64));
    // Don't `defer fix.deinit()` — call manually so the testing
    // allocator's leak detector verifies the finaliser ran.
    fix.deinit();
}
