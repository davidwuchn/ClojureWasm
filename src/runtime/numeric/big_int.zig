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
const value_mod = @import("../value/value.zig");
const HeapHeader = value_mod.HeapHeader;

/// Heap-allocated arbitrary-precision integer. Wraps
/// `std.math.big.int.Managed` so the cw runtime borrows the stdlib's
/// limb arithmetic without re-implementing it. The wrapping struct
/// carries the cw heap header so the future GC can walk it like any
/// other heap object.
///
/// HeapTag slot 29 (`big_int`) is the released `wasm_module` slot
/// per ADR-0006 amendment 1 + ADR-0012 amendment 1 — the day-1
/// reservation principle (ADR-0004) places it at its final NaN-box
/// position from skeleton time.
pub const BigInt = struct {
    header: HeapHeader,
    /// Owned by `m.allocator`; lifetime tied to the cw heap. Phase 5
    /// `freeBigInt` calls `m.deinit()`.
    m: std.math.big.int.Managed,

    pub fn init(managed: std.math.big.int.Managed) BigInt {
        return .{
            .header = HeapHeader.init(.big_int),
            .m = managed,
        };
    }
};

// --- tests ---

const testing = std.testing;

test "BigInt struct layout: HeapHeader + Managed at HeapTag.big_int slot" {
    var m = try std.math.big.int.Managed.init(testing.allocator);
    try m.set(123);

    var bi: BigInt = .init(m);
    defer bi.m.deinit();
    try testing.expectEqual(@as(u8, @intFromEnum(value_mod.HeapTag.big_int)), bi.header.tag);
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
