// SPDX-License-Identifier: EPL-2.0
//! Promise — Tier A single-shot future-write-once cell.
//!
//! `(promise)` constructs an unfulfilled Promise. `(deliver p v)`
//! sets the value (idempotent: re-delivery returns `nil` per JVM
//! `Promise.deliver` after CAS failure). `(deref p)` returns the
//! delivered value when `state == .delivered`.
//!
//! **PROVISIONAL** semantic on single-thread: `(deref p)` when
//! `state == .pending` would block forever in a multi-threaded JVM
//! Clojure. cw v1 Phase 14 single-thread runtime cannot block on
//! itself — it would deadlock by definition. The Phase-14 landing
//! raises `promise_undelivered_error` instead; the contention path
//! lands at Phase 15.1 alongside `std.Io.Mutex` (D-113).
//!
//! Per F-009 the implementation is namespace-neutral; surface
//! `promise` / `deliver` primitives live in `lang/primitive/deref.zig`.

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");
const mark_sweep = @import("gc/mark_sweep.zig");

pub const PromiseState = enum(u8) {
    pending = 0,
    delivered = 1,
};

pub const Promise = extern struct {
    header: HeapHeader,
    state: PromiseState = .pending,
    _pad: [5]u8 = .{ 0, 0, 0, 0, 0 },
    /// Delivered value. Undefined while `state == .pending`.
    value: Value = .nil_val,

    comptime {
        std.debug.assert(@alignOf(Promise) >= 8);
        std.debug.assert(@offsetOf(Promise, "header") == 0);
    }
};

pub fn alloc(rt: *Runtime) !Value {
    const p = try rt.gc.alloc(Promise);
    p.* = .{ .header = HeapHeader.init(.promise) };
    return Value.encodeHeapPtr(.promise, p);
}

pub fn isPromise(v: Value) bool {
    return v.tag() == .promise;
}

/// `(deliver p v)` — set the value on first call, no-op + return
/// nil on subsequent calls. JVM Clojure's `deliver` returns the
/// promise on success, nil on failed-CAS retry; cw v1 returns nil
/// on retry-deliver to match the surface tests check against.
pub fn deliver(v: Value, val: Value) Value {
    std.debug.assert(v.tag() == .promise);
    const p_const = v.decodePtr(*const Promise);
    if (p_const.state == .delivered) return .nil_val;
    const p: *Promise = @constCast(p_const);
    p.value = val;
    p.state = .delivered;
    return v;
}

/// `(deref p)` dispatch: return delivered value, or raise the
/// undelivered-promise signal so the caller (deref primitive) can
/// surface it through `error_catalog`.
pub fn deref(v: Value) ?Value {
    std.debug.assert(v.tag() == .promise);
    const p = v.decodePtr(*const Promise);
    if (p.state == .delivered) return p.value;
    return null;
}

pub fn isRealised(v: Value) bool {
    if (v.tag() != .promise) return false;
    return v.decodePtr(*const Promise).state == .delivered;
}

pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const p: *Promise = @ptrCast(@alignCast(header));
    if (p.state == .delivered) {
        if (p.value.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    }
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.promise, &traceGc);
}

const testing = std.testing;

test "Promise alloc + deliver + deref" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const p = try alloc(&rt);
    try testing.expect(isPromise(p));
    try testing.expect(!isRealised(p));
    try testing.expect(deref(p) == null);
    _ = deliver(p, Value.initInteger(42));
    try testing.expect(isRealised(p));
    try testing.expectEqual(@as(i64, 42), deref(p).?.asInteger());
    // Retry-deliver returns nil and does NOT overwrite.
    const second = deliver(p, Value.initInteger(99));
    try testing.expect(second.isNil());
    try testing.expectEqual(@as(i64, 42), deref(p).?.asInteger());
}
