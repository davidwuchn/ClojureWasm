// SPDX-License-Identifier: EPL-2.0
//! STM TVal — history-ring node (ADR-0010 amendment 4).
//!
//! A `Ref` carries an MVCC history ring of past committed values.
//! Each node — a TVal — holds:
//!
//!   - `val`    the committed Value
//!   - `point`  monotonic transaction id (assigned at commit time)
//!   - `msecs`  wall-clock millis at commit (matches JVM `Ref.TVal.msecs`)
//!   - `prior`  pointer to the previous TVal in the ring
//!   - `next`   pointer to the next TVal in the ring
//!
//! The ring is **doubly-linked with self-loop termination** per JVM
//! `Ref.java`. A single-node ring satisfies `prior == self ==
//! next`; subsequent commits splice a new TVal between `head` and
//! `head.next` exactly per the `clojure.lang.Ref.TVal` ctor in
//! Clojure's `Ref.java`.
//!
//! D-102 landed the data structure + GC integration; transaction
//! control flow (`doSet` / `doCommute` / `doEnsure` / commit /
//! retry / `histCount` / `trimHistory`) lands at Phase B (D-114) on
//! the unchanged shape.
//!
//! Tag: `HeapTag.tval` = Group D slot 63 (D15 — the last anonymous
//! reserve, named here per D-043 "name the reserve or shrink".)
//! TVal is GC-allocated via `rt.gc.alloc(TVal)` and traced through
//! `tag_ops.registerTrace(.tval, &traceGc)`. **TVal is not
//! NaN-boxed as a Value**: callers reach it only via `*TVal`
//! pointers held by `Ref.tvals`. No `Value.Tag.tval` exists.

const std = @import("std");
const value = @import("../value/value.zig");
const Value = value.Value;
const HeapHeader = value.HeapHeader;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");
const mark_sweep = @import("../gc/mark_sweep.zig");

/// One node in the Ref history ring. Doubly-linked with self-loop
/// termination — see module docstring.
pub const TVal = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    val: Value,
    point: i64 = 0,
    msecs: i64 = 0,
    prior: *TVal,
    next: *TVal,

    comptime {
        std.debug.assert(@alignOf(TVal) >= 8);
        std.debug.assert(@offsetOf(TVal, "header") == 0);
    }
};

/// Allocate a self-loop seed TVal. Used by `Ref.alloc` to materialise
/// the initial 1-node ring (`prior == next == self`).
pub fn allocSelfLoop(rt: *Runtime, init_val: Value, point: i64, msecs: i64) !*TVal {
    const node = try rt.gc.alloc(TVal);
    node.* = .{
        .header = HeapHeader.init(.tval),
        .val = init_val,
        .point = point,
        .msecs = msecs,
        .prior = node,
        .next = node,
    };
    return node;
}

/// Per-tag trace fn. The doubly-linked ring is traced via the
/// existing mark-bitmap cycle detection in `mark_sweep.mark` (the
/// `gc_mark & 1 == 1` short-circuit at the top of `mark` breaks the
/// `prior` / `next` cycle in one pass). We mark `val` (the user
/// payload) and recurse through `prior` + `next` so every reachable
/// TVal in the ring is visited even when the ring head is not the
/// caller's entry point.
pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const t: *TVal = @ptrCast(@alignCast(header));
    if (t.val.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    mark_sweep.mark(gc, &t.prior.header);
    mark_sweep.mark(gc, &t.next.header);
}

/// Register TVal's trace fn at `.tval`. Idempotent.
pub fn registerGcHooks() void {
    tag_ops.registerTrace(.tval, &traceGc);
}

// --- tests ---

const testing = std.testing;

test "allocSelfLoop produces a 1-node ring (prior == next == self)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const t = try allocSelfLoop(&rt, Value.initInteger(7), 0, 0);
    try testing.expect(t.prior == t);
    try testing.expect(t.next == t);
    try testing.expectEqual(@as(i64, 7), t.val.asInteger());
    try testing.expectEqual(@as(i64, 0), t.point);
}

test "self-loop ring mark-trace terminates (cycle detection works)" {
    // Manually thread a 3-node ring: a → b → c → a (and back via prior).
    // Mark via `traceGc` and assert all three are marked exactly once,
    // proving the mark-bitmap break in mark_sweep.mark handles the
    // doubly-linked self-loop without infinite recursion.
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const a = try allocSelfLoop(&rt, Value.initInteger(1), 0, 0);
    const b = try allocSelfLoop(&rt, Value.initInteger(2), 1, 0);
    const c = try allocSelfLoop(&rt, Value.initInteger(3), 2, 0);
    // Re-thread: a → b → c → a forward; c → b → a → c reverse.
    a.next = b;
    b.prior = a;
    b.next = c;
    c.prior = b;
    c.next = a;
    a.prior = c;
    // Clear marks defensively.
    mark_sweep.clearMarks(&rt.gc);
    // Start mark from `a`. The trace must walk to b and c without
    // re-entering a infinitely.
    mark_sweep.mark(&rt.gc, &a.header);
    try testing.expect((a.header.gc_and_lock.gc_mark & 1) == 1);
    try testing.expect((b.header.gc_and_lock.gc_mark & 1) == 1);
    try testing.expect((c.header.gc_and_lock.gc_mark & 1) == 1);
    // Clean up: the GC owns the nodes; deinit handles them via the
    // GcHeap allocations list.
}
