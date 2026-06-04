// SPDX-License-Identifier: EPL-2.0
//! Heap-value monitor for `(locking obj ...)` — a spinlock on the header's
//! `lock_state` bits (ADR-0009) plus a `threadlocal` held-set for reentrancy.
//! This is NOT a JVM object monitor (see `no_jvm_specific_assumption`): cljw
//! locks the heap value's own header word, and only heap objects (those with a
//! `HeapHeader`) are lockable — an immutable immediate has no identity to lock.
//!
//! Guarantees: mutual exclusion across OS threads, reentrancy (the same thread
//! re-acquires without deadlock), and GC-safety — the acquire spin polls the
//! `safepoint` so a stop-the-world collect can still drain (the #1 hazard: a
//! non-polling spinner never parks and hangs `stopWorld` forever).
//!
//! A contended waiter SPINS rather than parks. The blocking-monitor inflation
//! (`lock_state` 1→2 + an off-heap condition cell, the clj finished form) is
//! tracked as D-245 (ADR-0092 Option C). The pieces here — the gc_mark-
//! preserving header CAS, the safepoint-poll discipline, and the reentrancy
//! held-set — are Option C's uncontended fast path verbatim and carry forward
//! unchanged.

const std = @import("std");
const HeapHeader = @import("../value/heap_header.zig").HeapHeader;
const safepoint = @import("safepoint.zig");

/// Max reentrant-lock depth tracked per thread. Real reentrancy is 1–2 deep; a
/// nest beyond this is a runaway and errors out rather than corrupting state.
pub const HELD_CAP = 32;

const Held = struct { obj: ?*HeapHeader = null, count: u32 = 0 };

/// Per-thread reentrancy bookkeeping: which objects THIS thread holds + how
/// deep. NOT a GC root source — the locked object is already a root via the
/// `EvalFrame` operand-stack/locals walk (ADR-0091) for the body's duration;
/// the held-set only counts re-entries so a release at depth>1 does not unlock.
threadlocal var held: [HELD_CAP]Held = [_]Held{.{}} ** HELD_CAP;

fn findHeld(hdr: *HeapHeader) ?*Held {
    for (&held) |*h| {
        if (h.obj == hdr) return h;
    }
    return null;
}

/// Acquire `hdr`'s monitor for the current thread. Reentrant: a re-acquire of an
/// already-held object just bumps its depth. Otherwise spins on the header
/// `lock_state` CAS, polling the safepoint each turn so a concurrent collect can
/// proceed, until the bit is won.
pub fn enter(hdr: *HeapHeader) error{HeldOverflow}!void {
    if (findHeld(hdr)) |h| {
        h.count += 1;
        return;
    }
    const word: *u32 = @ptrCast(&hdr.gc_and_lock);
    while (true) {
        // GC-safety: a non-allocating spin MUST yield to a pending stop-the-world
        // collect, or `stopWorld` waits for a park that never comes (deadlock vs
        // the GC, strictly worse than the contention spin itself).
        if (safepoint.gc_requested.load(.acquire)) safepoint.park();
        const cur = @atomicLoad(u32, word, .monotonic);
        if (cur & 0b11 == 0) {
            // CAS the WHOLE u32 to preserve gc_mark (the other 30 bits).
            const desired = (cur & ~@as(u32, 0b11)) | 1;
            if (@cmpxchgWeak(u32, word, cur, desired, .acquire, .monotonic) == null) break;
        }
        std.atomic.spinLoopHint();
    }
    for (&held) |*h| {
        if (h.obj == null) {
            h.* = .{ .obj = hdr, .count = 1 };
            return;
        }
    }
    // No free slot: undo the lock we just took, then signal overflow.
    releaseBit(word);
    return error.HeldOverflow;
}

/// Release one level of `hdr`'s monitor. At depth>1 just decrements; at the
/// outermost level clears the header `lock_state` bit + frees the held slot. A
/// release with no matching acquire is a no-op (defensive).
pub fn exit(hdr: *HeapHeader) void {
    const h = findHeld(hdr) orelse return;
    h.count -= 1;
    if (h.count > 0) return;
    h.obj = null;
    releaseBit(@ptrCast(&hdr.gc_and_lock));
}

/// CAS `lock_state` back to 0, preserving gc_mark.
fn releaseBit(word: *u32) void {
    while (true) {
        const cur = @atomicLoad(u32, word, .monotonic);
        const desired = cur & ~@as(u32, 0b11);
        if (@cmpxchgWeak(u32, word, cur, desired, .release, .monotonic) == null) break;
    }
}

// --- tests ---

const testing = std.testing;

test "enter/exit toggles the header lock bit" {
    var hdr = HeapHeader.init(.vector);
    try testing.expectEqual(@as(u2, 0), hdr.gc_and_lock.lock_state);
    try enter(&hdr);
    try testing.expectEqual(@as(u2, 1), hdr.gc_and_lock.lock_state);
    exit(&hdr);
    try testing.expectEqual(@as(u2, 0), hdr.gc_and_lock.lock_state);
}

test "enter is reentrant on one thread (bit stays set until outer exit)" {
    var hdr = HeapHeader.init(.vector);
    try enter(&hdr);
    try enter(&hdr); // reentrant — no deadlock, no second CAS
    try testing.expectEqual(@as(u2, 1), hdr.gc_and_lock.lock_state);
    exit(&hdr); // inner
    try testing.expectEqual(@as(u2, 1), hdr.gc_and_lock.lock_state);
    exit(&hdr); // outer — now released
    try testing.expectEqual(@as(u2, 0), hdr.gc_and_lock.lock_state);
}

test "the lock CAS preserves gc_mark" {
    var hdr = HeapHeader.init(.vector);
    hdr.gc_and_lock.gc_mark = 12345;
    try enter(&hdr);
    try testing.expectEqual(@as(u30, 12345), hdr.gc_and_lock.gc_mark);
    try testing.expectEqual(@as(u2, 1), hdr.gc_and_lock.lock_state);
    exit(&hdr);
    try testing.expectEqual(@as(u30, 12345), hdr.gc_and_lock.gc_mark);
}
