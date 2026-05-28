// SPDX-License-Identifier: EPL-2.0
//! Delay — Tier A lazy single-shot memoised computation.
//!
//! `(delay expr)` constructs a Delay carrying a thunk (= zero-arity
//! fn closing over `expr`'s environment). `(deref d)` evaluates the
//! thunk on first call and caches the result; subsequent derefs
//! return the cached Value without re-running the thunk. JVM
//! `clojure.lang.Delay` is the model (single-shot lock-on-realise +
//! cached value / cached exception). cw v1 row 14.8 implements the
//! single-thread single-shot variant per F-NNN — no Mutex needed at
//! Phase 14; the contention path lands at Phase 15.1 alongside `std.
//! Io.Mutex` / `std.atomic.Mutex` (NOT the Zig-0.16-removed
//! `std.Thread.Mutex`).
//!
//! Per F-009: implementation here is namespace-neutral. The Clojure-
//! ns surface `(delay ...)` macro lives in `lang/macro_transforms`,
//! expanding to `(__delay-create (fn [] expr))`. The neutral primitive
//! `__delay-create` is registered alongside `deref` extensions in
//! `lang/primitive/deref.zig` (Phase 14 split from stm.zig).

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");
const mark_sweep = @import("gc/mark_sweep.zig");

/// Delay state machine — single-thread single-shot.
///
/// - `pending`: thunk hasn't run yet; `cached` is undefined.
/// - `realised`: thunk ran successfully; `cached` holds the value.
///
/// JVM's Delay also tracks `exception` for re-raise on subsequent
/// derefs. cw v1 single-thread defers exception caching to Phase
/// 15.1 alongside the lock activation; today a thunk error bubbles
/// uncaught at first deref and the Delay's state stays `.pending`
/// (a retry of `deref` re-runs the thunk).
pub const DelayState = enum(u8) {
    pending = 0,
    realised = 1,
};

pub const Delay = extern struct {
    header: HeapHeader,
    state: DelayState = .pending,
    _pad: [5]u8 = .{ 0, 0, 0, 0, 0 },
    /// Zero-arity thunk wrapping the delayed expression. Held until
    /// the Delay realises; once realised the thunk slot is left in
    /// place (the next-gen Phase-15 lock activation may revisit
    /// whether to clear it).
    thunk: Value,
    /// Realised value. Undefined while `state == .pending`.
    cached: Value = .nil_val,

    comptime {
        std.debug.assert(@alignOf(Delay) >= 8);
        std.debug.assert(@offsetOf(Delay, "header") == 0);
    }
};

pub fn alloc(rt: *Runtime, thunk: Value) !Value {
    const d = try rt.gc.alloc(Delay);
    d.* = .{
        .header = HeapHeader.init(.delay),
        .thunk = thunk,
    };
    return Value.encodeHeapPtr(.delay, d);
}

pub fn isDelay(v: Value) bool {
    return v.tag() == .delay;
}

/// Force the Delay's thunk on first call; return cached value on
/// subsequent calls. `(deref d)` dispatches here when `d.tag() ==
/// .delay`. Caller threads `rt` + `env` so the thunk can invoke
/// through `rt.vtable.callFn`.
pub fn force(rt: *Runtime, env: anytype, v: Value, loc: anytype) !Value {
    std.debug.assert(v.tag() == .delay);
    const d_const = v.decodePtr(*const Delay);
    if (d_const.state == .realised) return d_const.cached;
    const d: *Delay = @constCast(d_const);
    const vtable = rt.vtable orelse return error.InternalError;
    const result = try vtable.callFn(rt, env, d.thunk, &.{}, loc);
    d.cached = result;
    d.state = .realised;
    return result;
}

pub fn isRealised(v: Value) bool {
    if (v.tag() != .delay) return false;
    return v.decodePtr(*const Delay).state == .realised;
}

pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const d: *Delay = @ptrCast(@alignCast(header));
    if (d.thunk.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    if (d.state == .realised) {
        if (d.cached.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    }
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.delay, &traceGc);
}

const testing = std.testing;

test "Delay alloc + isDelay round-trip" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const d = try alloc(&rt, .nil_val);
    try testing.expect(isDelay(d));
    try testing.expect(!isRealised(d));
    try testing.expect(!isDelay(Value.initInteger(7)));
}
