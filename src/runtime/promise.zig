// SPDX-License-Identifier: EPL-2.0
//! Promise — Tier A single-shot write-once cell (Phase B #4b).
//!
//! `(promise)` constructs an unfulfilled Promise. `(deliver p v)` sets the
//! value once (idempotent: re-delivery returns `nil`, matching JVM
//! `Promise.deliver` after a failed CAS) and wakes every blocked deref'er.
//! `(deref p)` BLOCKS on an `Io.Mutex`+`Io.Condition` cell until the value is
//! delivered (possibly from another thread), then returns it — the standard
//! `(let [p (promise)] (future (deliver p v)) (deref p))` cross-thread pattern.
//! Deref of a never-delivered promise blocks forever, exactly as JVM Clojure
//! does (D-113 discharged: the prior single-thread `promise_undelivered_error`
//! raise is retired now that real threading can block).
//!
//! The result cell (`Io.Condition` has automatic layout, so it cannot live in
//! the `extern` Promise) is infra-allocated and freed by the Promise's
//! finaliser — the same shape as `future.zig`'s `FutureCell`.
//!
//! Per F-009 the implementation is namespace-neutral; surface `promise` /
//! `deliver` primitives live in `lang/primitive/stm.zig`.

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const io_default = @import("concurrency/io_default.zig");
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");
const mark_sweep = @import("gc/mark_sweep.zig");

pub const PromiseState = enum(u8) {
    pending = 0,
    delivered = 1,
};

/// Blocking cell, held off the GC heap (see the module doc); infra-allocated at
/// construction, freed by the Promise's finaliser. `deref` waits on `cond`;
/// `deliver` broadcasts it. Stable address — a parked deref'er's wait target is
/// valid for the cell's lifetime (the Promise stays rooted while held).
const PromiseCell = struct {
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,
};

pub const Promise = extern struct {
    header: HeapHeader,
    /// Read/written ONLY under `cell.mutex`.
    state: PromiseState = .pending,
    _pad: [7]u8 = @splat(0),
    /// Delivered value; `.nil_val` while pending.
    value: Value = .nil_val,
    cell: *PromiseCell,

    comptime {
        std.debug.assert(@alignOf(Promise) >= 8);
        std.debug.assert(@offsetOf(Promise, "header") == 0);
    }
};

pub fn alloc(rt: *Runtime) !Value {
    const cell = try rt.gpa.create(PromiseCell);
    cell.* = .{};
    const p = rt.gc.alloc(Promise) catch |e| {
        rt.gpa.destroy(cell);
        return e;
    };
    p.* = .{ .header = HeapHeader.init(.promise), .cell = cell };
    return Value.encodeHeapPtr(.promise, p);
}

pub fn isPromise(v: Value) bool {
    return v.tag() == .promise;
}

/// `(deliver p v)` — set the value on first call (and wake blocked deref'ers),
/// no-op + return nil on subsequent calls. Returns the promise on success, nil
/// on a failed-CAS retry (the surface tests check against this).
pub fn deliver(v: Value, val: Value) Value {
    std.debug.assert(v.tag() == .promise);
    const p = v.decodePtr(*Promise);
    io_default.lockMutex(&p.cell.mutex);
    defer io_default.unlockMutex(&p.cell.mutex);
    if (p.state == .delivered) return .nil_val;
    p.value = val;
    p.state = .delivered;
    io_default.condBroadcast(&p.cell.cond);
    return v;
}

/// `(deref p)` — BLOCK until the value is delivered (matching JVM Clojure),
/// then return it. A never-delivered promise blocks forever (a user deadlock,
/// as in clj).
pub fn deref(v: Value) Value {
    std.debug.assert(v.tag() == .promise);
    const p = v.decodePtr(*Promise);
    io_default.lockMutex(&p.cell.mutex);
    defer io_default.unlockMutex(&p.cell.mutex);
    while (p.state == .pending) {
        io_default.condWait(&p.cell.cond, &p.cell.mutex);
    }
    return p.value;
}

pub fn isRealised(v: Value) bool {
    if (v.tag() != .promise) return false;
    const p = v.decodePtr(*Promise);
    io_default.lockMutex(&p.cell.mutex);
    defer io_default.unlockMutex(&p.cell.mutex);
    return p.state == .delivered;
}

/// Wait up to `timeout_ms` for a delivery (the 3-arity `deref` support).
/// Polls in 1ms sleeps — Zig 0.16's `std.Io.Condition` has no timed wait
/// (the future.zig waitRealised twin). False on timeout.
pub fn waitDelivered(io: std.Io, v: Value, timeout_ms: i64) bool {
    const clock = @import("clock.zig");
    const deadline = clock.currentMillis(io) + @max(timeout_ms, 0);
    while (!isRealised(v)) {
        if (clock.currentMillis(io) >= deadline) return false;
        io_default.sleep(1_000_000); // 1ms
    }
    return true;
}

pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const p: *Promise = @ptrCast(@alignCast(header));
    if (p.state == .delivered) {
        if (p.value.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    }
}

/// Free the off-heap cell on sweep (no-alloc invariant: a `destroy`). Reachable
/// only when the Promise is unreachable — no deref'er is blocked on it then.
pub fn finaliseGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const p: *Promise = @ptrCast(@alignCast(header));
    gc.infra.destroy(p.cell);
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.promise, &traceGc);
    tag_ops.registerFinaliser(.promise, &finaliseGc);
}

const testing = std.testing;

test "Promise alloc + deliver + deref (already-delivered, no block)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const p = try alloc(&rt);
    try testing.expect(isPromise(p));
    try testing.expect(!isRealised(p));
    _ = deliver(p, Value.initInteger(42));
    try testing.expect(isRealised(p));
    // Already delivered → deref returns immediately (no block).
    try testing.expectEqual(@as(i64, 42), deref(p).asInteger());
    // Retry-deliver returns nil and does NOT overwrite.
    const second = deliver(p, Value.initInteger(99));
    try testing.expect(second.isNil());
    try testing.expectEqual(@as(i64, 42), deref(p).asInteger());
}
