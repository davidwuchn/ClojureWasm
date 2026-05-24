// SPDX-License-Identifier: EPL-2.0
//! PersistentVector — Clojure-shape HAMT (shift=5 = 32-way) + 32-element
//! tail array per ROADMAP §9.7 row 5.4.
//!
//! Structure (matches clojure JVM `clojure.lang.PersistentVector`,
//! re-typed in Zig 0.16 `extern struct` shape for the 5.3 GC
//! integration — header at offset 0, slots inlined as fixed-size
//! arrays, all allocations through `rt.gc.alloc`):
//!
//!   ```
//!   Vector { count, shift, root: ?*HamtNode, tail: ?*TailNode, meta }
//!     ├── root → HamtNode { slots: [32]Value }
//!     │            ├── slots[i] → HamtNode (interior at shift > 5)
//!     │            └── slots[i] → leaf HamtNode (shift == 5, slot = Value)
//!     └── tail → TailNode { len, slots: [32]Value }
//!   ```
//!
//! The first `tailoff() = (count - 1) & ~31` Values live in `root` —
//! 32 leaves per interior level, `shift` levels deep. The remaining
//! `count - tailoff()` Values live in `tail` (≤ 32). `nth(v, i)`:
//! if `i >= tailoff()` → `tail.slots[i - tailoff()]`; else walk
//! `root` via `(i >>> level) & 0x1F` at each level until shift==5,
//! then `leaf.slots[i & 0x1F]`.
//!
//! 5.4.a (this file's first landing): struct shapes + EMPTY singleton
//! + nth + count read-side ops. 5.4.b lands conj + pop (pushTail /
//! popTail patterns); 5.4.c lands assoc; 5.4.d lands subvec.
//!
//! Per-tag trace fns + Runtime.init registration are deferred to
//! 5.4.b alongside the first allocation site — at 5.4.a EMPTY is a
//! comptime const singleton (no GC trace needed because it never
//! lives on the GC heap).

const std = @import("std");
const value_mod = @import("../value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const HeapTag = value_mod.HeapTag;

/// Number of branch bits per HAMT level (Clojure JVM = 5; matches
/// the cache-line-friendly 32-way branching factor).
pub const SHIFT_BITS: u5 = 5;
/// Branch factor per level (2^SHIFT_BITS = 32).
pub const BRANCH_FACTOR: u8 = 1 << SHIFT_BITS;
/// Index mask for one level (`& MASK` picks the low SHIFT_BITS).
pub const MASK: u32 = BRANCH_FACTOR - 1;

/// Top-level PersistentVector. extern struct so declaration order is
/// preserved + HeapHeader lands at offset 0 (required by
/// `gc.alloc(T)` per the comptime check).
pub const Vector = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    /// O(1) element count. Capped at `std.math.maxInt(u32)`.
    count: u32 = 0,
    /// Trie depth in branch bits — `shift = SHIFT_BITS * (depth - 1)`
    /// where depth is the number of node levels in `root`. shift = 0
    /// means root is a leaf HamtNode (or null for empty).
    shift: u32 = 0,
    /// Root of the HAMT trie (null for vectors with ≤ 32 elements
    /// where everything lives in `tail`).
    root: ?*HamtNode = null,
    /// Tail array — the last ≤ 32 elements live here for O(1) conj
    /// per the canonical clojure JVM pattern.
    tail: ?*TailNode = null,
    /// Optional metadata map (Clojure `with-meta` / `meta`).
    meta: Value = Value.nil_val,

    comptime {
        std.debug.assert(@alignOf(Vector) >= 8);
        std.debug.assert(@offsetOf(Vector, "header") == 0);
    }
};

/// HAMT interior / leaf node — 32 Value slots inlined. At leaf level
/// (shift == 0 in the parent Vector's terms) the slots are Clojure
/// element Values; at interior levels they are `Value`-encoded
/// `*HamtNode` pointers (via `encodeHeapPtr(.hamt_node, child)`).
///
/// Why `slots` is 32 Values and not 32 raw pointers: the GC trace
/// fn walks per-slot via `Value.heapHeader()` which uniformly
/// handles both element Values and HamtNode-pointer Values. The
/// extra encoding cost is zero (Values are u64 already).
pub const HamtNode = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    slots: [BRANCH_FACTOR]Value = @splat(Value.nil_val),

    comptime {
        std.debug.assert(@alignOf(HamtNode) >= 8);
        std.debug.assert(@offsetOf(HamtNode, "header") == 0);
    }
};

/// 32-element tail array. `len` tracks the populated prefix (1..32);
/// `slots[0..len]` are the live Values. When `len` reaches 32 the
/// tail promotes to a leaf HamtNode under `root` (5.4.b conj).
pub const TailNode = extern struct {
    header: HeapHeader,
    _pad: [2]u8 = .{ 0, 0 },
    len: u32 = 0,
    slots: [BRANCH_FACTOR]Value = @splat(Value.nil_val),

    comptime {
        std.debug.assert(@alignOf(TailNode) >= 8);
        std.debug.assert(@offsetOf(TailNode, "header") == 0);
    }
};

/// Empty PersistentVector singleton — comptime const, lives forever
/// in the binary's read-only segment. The Value form `EMPTY_VALUE`
/// encodes a pointer at the singleton; the GC never sweeps it
/// because `nil` heap-pointers / immediate-band pointers are filtered
/// out by `Value.heapHeader()` before the live-list walk would see
/// them.
pub var EMPTY: Vector align(8) = .{
    .header = HeapHeader.init(.vector),
    .count = 0,
    .shift = 0,
    .root = null,
    .tail = null,
    .meta = Value.nil_val,
};

/// Pointer to the EMPTY singleton, wrapped as a heap-tagged Value.
/// Use this as the starting point for `conj`-built vectors (5.4.b).
pub fn empty() Value {
    return Value.encodeHeapPtr(.vector, &EMPTY);
}

/// O(1) element count. Per Clojure semantics, `(count nil) = 0`.
pub fn count(v: Value) u32 {
    return switch (v.tag()) {
        .vector => v.decodePtr(*const Vector).count,
        .nil => 0,
        else => 0,
    };
}

/// `tailoff = first index that lives in tail (= 0 when tail-only)`.
/// Per clojure JVM `PersistentVector.tailoff()`.
inline fn tailoff(c: u32) u32 {
    if (c < BRANCH_FACTOR) return 0;
    return ((c - 1) >> SHIFT_BITS) << SHIFT_BITS;
}

/// O(log32 n) random access. Returns `nil` for out-of-bounds (matches
/// Clojure `(nth v i nil)` — the 2-arg `(nth v i)` throws but the
/// 3-arg variant returns the not-found sentinel; our Day-1 surface
/// goes through the analyzer which decides which variant to call).
pub fn nth(v: Value, i: u32) Value {
    if (v.tag() != .vector) return Value.nil_val;
    const vec = v.decodePtr(*const Vector);
    if (i >= vec.count) return Value.nil_val;

    if (i >= tailoff(vec.count)) {
        // In-tail path: trivial index into the 32-slot tail.
        const t = vec.tail orelse return Value.nil_val;
        return t.slots[i - tailoff(vec.count)];
    }

    // In-root path: walk down the HAMT via `(i >>> level) & MASK` at
    // each level. shift = SHIFT_BITS * (depth - 1); we descend until
    // shift reaches 0.
    var node: *const HamtNode = vec.root orelse return Value.nil_val;
    var level: u32 = vec.shift;
    while (level > 0) : (level -= SHIFT_BITS) {
        const idx = (i >> @as(u5, @intCast(level))) & MASK;
        const child_val = node.slots[idx];
        node = child_val.decodePtr(*const HamtNode);
    }
    return node.slots[i & MASK];
}

// --- tests ---

const testing = std.testing;

test "EMPTY singleton: count = 0, nth out-of-bounds = nil" {
    const v = empty();
    try testing.expect(v.tag() == .vector);
    try testing.expectEqual(@as(u32, 0), count(v));
    try testing.expect(nth(v, 0).isNil());
    try testing.expect(nth(v, 100).isNil());
}

test "count on nil = 0; count on non-vector = 0" {
    try testing.expectEqual(@as(u32, 0), count(Value.nil_val));
    try testing.expectEqual(@as(u32, 0), count(Value.initInteger(42)));
    try testing.expectEqual(@as(u32, 0), count(Value.initFloat(3.14)));
}

test "tailoff edge cases" {
    try testing.expectEqual(@as(u32, 0), tailoff(0));
    try testing.expectEqual(@as(u32, 0), tailoff(1));
    try testing.expectEqual(@as(u32, 0), tailoff(31));
    try testing.expectEqual(@as(u32, 0), tailoff(32)); // first 32 fit in tail
    try testing.expectEqual(@as(u32, 32), tailoff(33));
    try testing.expectEqual(@as(u32, 32), tailoff(63));
    try testing.expectEqual(@as(u32, 32), tailoff(64));
    try testing.expectEqual(@as(u32, 64), tailoff(65));
}

test "Vector struct layout: HeapHeader at offset 0, 8-byte aligned" {
    try testing.expectEqual(@as(usize, 0), @offsetOf(Vector, "header"));
    try testing.expect(@alignOf(Vector) >= 8);
}

test "HamtNode struct layout: header at 0, 32 slots inlined" {
    try testing.expectEqual(@as(usize, 0), @offsetOf(HamtNode, "header"));
    const default_node: HamtNode = .{ .header = HeapHeader.init(.hamt_node) };
    try testing.expectEqual(@as(usize, BRANCH_FACTOR), default_node.slots.len);
    try testing.expect(@alignOf(HamtNode) >= 8);
}

test "TailNode struct layout: header at 0, 32 slots + len" {
    try testing.expectEqual(@as(usize, 0), @offsetOf(TailNode, "header"));
    const default_tail: TailNode = .{ .header = HeapHeader.init(.tail_node) };
    try testing.expectEqual(@as(usize, BRANCH_FACTOR), default_tail.slots.len);
    try testing.expect(@alignOf(TailNode) >= 8);
}

test "nth in-tail path: handcrafted vector of 3 elements" {
    var tail = TailNode{
        .header = HeapHeader.init(.tail_node),
        .len = 3,
        .slots = blk: {
            var s: [BRANCH_FACTOR]Value = @splat(Value.nil_val);
            s[0] = Value.initInteger(10);
            s[1] = Value.initInteger(20);
            s[2] = Value.initInteger(30);
            break :blk s;
        },
    };
    var vec = Vector{
        .header = HeapHeader.init(.vector),
        .count = 3,
        .shift = 0,
        .root = null,
        .tail = &tail,
    };
    const v = Value.encodeHeapPtr(.vector, &vec);

    try testing.expectEqual(@as(u32, 3), count(v));
    try testing.expectEqual(@as(i48, 10), nth(v, 0).asInteger());
    try testing.expectEqual(@as(i48, 20), nth(v, 1).asInteger());
    try testing.expectEqual(@as(i48, 30), nth(v, 2).asInteger());
    try testing.expect(nth(v, 3).isNil()); // out-of-bounds
}

test "nth in-root path: handcrafted shift=5 vector with 33 elements" {
    // 33 elements: first 32 in root (leaf node 0), 33rd in tail.
    var leaf0 = HamtNode{
        .header = HeapHeader.init(.hamt_node),
        .slots = blk: {
            var s: [BRANCH_FACTOR]Value = @splat(Value.nil_val);
            for (0..BRANCH_FACTOR) |idx| s[idx] = Value.initInteger(@intCast(idx + 100));
            break :blk s;
        },
    };
    var tail = TailNode{
        .header = HeapHeader.init(.tail_node),
        .len = 1,
        .slots = blk: {
            var s: [BRANCH_FACTOR]Value = @splat(Value.nil_val);
            s[0] = Value.initInteger(132); // index 32 = first tail elem
            break :blk s;
        },
    };
    var vec = Vector{
        .header = HeapHeader.init(.vector),
        .count = 33,
        .shift = 0, // root IS the leaf (1 level)
        .root = &leaf0,
        .tail = &tail,
    };
    const v = Value.encodeHeapPtr(.vector, &vec);

    try testing.expectEqual(@as(u32, 33), count(v));
    try testing.expectEqual(@as(i48, 100), nth(v, 0).asInteger());
    try testing.expectEqual(@as(i48, 131), nth(v, 31).asInteger());
    try testing.expectEqual(@as(i48, 132), nth(v, 32).asInteger());
    try testing.expect(nth(v, 33).isNil());
}
