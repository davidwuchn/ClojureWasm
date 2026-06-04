// SPDX-License-Identifier: EPL-2.0
//! Future — Tier A single-shot eager-eval-cached computation.
//!
//! `(future expr)` evaluates `expr` **eagerly at construction time**
//! (= synchronously on the single-thread runtime today) and caches
//! the result. `(deref f)` returns the cached Value. This matches
//! JVM Clojure's "fire-and-cache" timing: the work happens at
//! construction (JVM kicks the thread immediately; cw v1 runs it
//! inline), and `(deref f)` is a cheap cache read. Real threading
//! lands at Phase B (the eager-inline call becomes a spawned thread +
//! wait); the Zig-0.16 threading/sync primitive is chosen at Phase B
//! entry (the pre-0.16 plan referenced removed APIs). The surface and
//! the cached Value layout stay stable (D-114).
//!
//! Exceptions: a thunk that throws is caught at construction time
//! and stashed; subsequent `(deref f)` re-raises so the user sees
//! the error at consistent timing across the inline form today and
//! the thread+wait form at Phase B. JVM's `Future.get` re-raises
//! wrapped in ExecutionException; cw v1 raises the original error
//! directly.
//!
//! Per F-009 the implementation is namespace-neutral.

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");
const mark_sweep = @import("gc/mark_sweep.zig");

pub const FutureState = enum(u8) {
    realised_value = 0,
    realised_error = 1,
};

pub const Future = extern struct {
    header: HeapHeader,
    state: FutureState = .realised_value,
    _pad: [5]u8 = .{ 0, 0, 0, 0, 0 },
    /// Cached value (when state == .realised_value) or the error
    /// signal Value (when state == .realised_error). Re-raise is the
    /// caller's job — deref(future) returns either the value or a
    /// null-and-state-error-signal for the catalog raise.
    cached: Value = .nil_val,

    comptime {
        std.debug.assert(@alignOf(Future) >= 8);
        std.debug.assert(@offsetOf(Future, "header") == 0);
    }
};

/// Eager construction: call the thunk now via `rt.vtable.callFn`,
/// stash the result. If the thunk raises a `ClojureWasmError`-shape
/// error the original error tag is preserved (the side-channel
/// `error_mod` carries the message for the eventual re-raise at
/// deref time); we stash a marker value (`.nil_val`) and set
/// state = `.realised_error`. Today re-raise lands as a fresh
/// `future_thunk_failed` raise (PROVISIONAL — message attribution
/// loses precision until Phase B lands the Value-carried
/// exception channel D-115).
pub fn alloc(rt: *Runtime, env: anytype, thunk: Value, loc: anytype) !Value {
    const f = try rt.gc.alloc(Future);
    f.* = .{ .header = HeapHeader.init(.future) };
    const fut_val = Value.encodeHeapPtr(.future, f);
    const vtable = rt.vtable orelse return error.InternalError;
    // PROVISIONAL: thunk-error attribution loses precision until the Value-carried exception channel lands [refs: D-115, feature_deps.yaml#runtime/future/error_value_channel]
    if (vtable.callFn(rt, env, thunk, &.{}, loc)) |result| {
        f.cached = result;
        f.state = .realised_value;
    } else |_| {
        f.cached = .nil_val;
        f.state = .realised_error;
    }
    return fut_val;
}

pub fn isFuture(v: Value) bool {
    return v.tag() == .future;
}

/// `(deref f)` dispatch: return cached value if realised; the
/// caller (deref primitive) raises `future_thunk_failed` when state
/// is `.realised_error`.
pub fn deref(v: Value) ?Value {
    std.debug.assert(v.tag() == .future);
    const f = v.decodePtr(*const Future);
    if (f.state == .realised_value) return f.cached;
    return null;
}

pub fn isRealised(v: Value) bool {
    return v.tag() == .future;
}

pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const f: *Future = @ptrCast(@alignCast(header));
    if (f.cached.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.future, &traceGc);
}

const testing = std.testing;

test "Future isFuture predicate" {
    try testing.expect(!isFuture(Value.initInteger(7)));
    try testing.expect(!isFuture(.nil_val));
}
