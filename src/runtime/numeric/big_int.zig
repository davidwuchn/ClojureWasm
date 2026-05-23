// SPDX-License-Identifier: EPL-2.0
//! Arbitrary-precision integer heap struct (ROADMAP §9.6 / 4.23,
//! ADR-0012).
//!
//! Phase 4 entry lands the struct shape only. Arithmetic promotion
//! (`Long` → `BigInt` on overflow), the `+` / `-` / `*` / `/`
//! dispatch, and equality comparisons all land at Phase 5 alongside
//! the mark-sweep GC and the rewritten numeric primitives.
//!
//! The `Value.Tag.big_int` slot is already reserved at Day 1 per
//! ADR-0004 + ADR-0012; this file provides the heap struct the slot
//! points at.

const std = @import("std");
const value_mod = @import("../value.zig");
const HeapHeader = value_mod.HeapHeader;

/// Heap-allocated arbitrary-precision integer. Wraps
/// `std.math.big.int.Managed` so the cw runtime borrows the stdlib's
/// limb arithmetic without re-implementing it. The wrapping struct
/// carries the cw heap header so the future GC can walk it like any
/// other heap object.
///
/// Phase 4 entry lands the struct shape only. The matching
/// `HeapTag.big_int` enum slot is **not yet assigned** because the
/// current NaN-box layout (`NB_HEAP_GROUP_SIZE = 8`, 4 groups → 32
/// slots, all used) needs an amendment to grow. The header's `tag`
/// stays at a placeholder until Phase 5 lands the layout extension
/// and the matching `encodeHeapPtr` group expansion.
pub const BigInt = struct {
    header: HeapHeader,
    /// Owned by `m.allocator`; lifetime tied to the cw heap. Phase 5
    /// `freeBigInt` calls `m.deinit()`.
    m: std.math.big.int.Managed,

    /// Phase-4 placeholder tag value (0xFF — outside the assigned
    /// HeapTag range). Phase 5 swaps to `HeapTag.big_int` once the
    /// NaN-box layout amendment lands.
    pub const PHASE4_PLACEHOLDER_TAG: u8 = 0xFF;

    pub fn init(managed: std.math.big.int.Managed) BigInt {
        return .{
            .header = .{ .tag = PHASE4_PLACEHOLDER_TAG, .flags = .{} },
            .m = managed,
        };
    }
};

// --- tests ---

const testing = std.testing;

test "BigInt struct layout: HeapHeader + Managed" {
    var m = try std.math.big.int.Managed.init(testing.allocator);
    try m.set(123);

    var bi: BigInt = .init(m);
    defer bi.m.deinit();
    try testing.expectEqual(BigInt.PHASE4_PLACEHOLDER_TAG, bi.header.tag);
}

test "BigInt holds values beyond i64 range" {
    var m = try std.math.big.int.Managed.init(testing.allocator);
    // 2^65 — beyond i64. The wrapping struct stores the big_int
    // verbatim; arithmetic + printing wire in Phase 5.
    try m.setString(10, "36893488147419103232");
    var bi: BigInt = .init(m);
    defer bi.m.deinit();

    try testing.expect(bi.m.bitCountAbs() > 64);
}
