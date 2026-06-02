// SPDX-License-Identifier: EPL-2.0
//! MapEntry — a distinct map-entry value (D-209 / clj-parity C4, ADR-0078).
//!
//! cljw's analogue of `clojure.lang.MapEntry`: it IS-A 2-element vector in
//! every observable way (`vector?`→true, `(= entry [k v])`→true, `nth`/
//! `count`/`seq`/print/destructure all behave as `[k v]`) yet `map-entry?`→
//! true and `class`→MapEntry distinguish it. `conj`/`assoc` DROP the nature
//! (return a plain `.vector`, JVM `asVector()`).
//!
//! Activates the RESERVED F-004 Group-A `.map_entry` slot (HeapTag 15) —
//! consuming a reservation, NOT amending F-004. Substrate mirrors
//! `range.zig` (ADR-0063 / D-178) but owns two `Value` children, so it
//! registers a trace hook (unlike range).

const std = @import("std");
const value = @import("../value/value.zig");
const Value = value.Value;
const HeapHeader = value.HeapHeader;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");
const mark_sweep = @import("../gc/mark_sweep.zig");

/// A map entry: `key` / `val`. `extern struct` so the HeapHeader lands at
/// offset 0 (required by `gc.alloc(T)`) and field order is stable.
pub const MapEntry = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    key: Value,
    val: Value,

    comptime {
        std.debug.assert(@alignOf(MapEntry) >= 8);
        std.debug.assert(@offsetOf(MapEntry, "header") == 0);
    }
};

/// Allocate a `.map_entry` on the GC heap.
pub fn make(rt: *Runtime, k: Value, v: Value) !Value {
    const e = try rt.gc.alloc(MapEntry);
    e.* = .{ .header = HeapHeader.init(.map_entry), .key = k, .val = v };
    return Value.encodeHeapPtr(.map_entry, e);
}

/// The entry's key (index 0).
pub fn keyOf(v: Value) Value {
    return v.decodePtr(*const MapEntry).key;
}

/// The entry's val (index 1).
pub fn valOf(v: Value) Value {
    return v.decodePtr(*const MapEntry).val;
}

/// Positional access (clj `AMapEntry.nth`): 0→key, 1→val. Caller checks
/// bounds (only 0/1 are valid); used by the `nth` primitive's `.map_entry`
/// arm after its own range check.
pub fn nth(v: Value, i: u32) Value {
    const e = v.decodePtr(*const MapEntry);
    return if (i == 0) e.key else e.val;
}

/// Per-tag trace fn: mark both children so they survive GC (ADR-0028 §5).
/// MapEntry owns no non-GC resources, so no finaliser.
pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const e: *MapEntry = @ptrCast(@alignCast(header));
    if (e.key.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    if (e.val.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
}

/// Register MapEntry's trace fn into `tag_ops.tag_trace_table[.map_entry]`.
/// Called from `Runtime.init`.
pub fn registerGcHooks() void {
    tag_ops.registerTrace(.map_entry, &traceGc);
}

// --- tests ---

const testing = std.testing;

test "MapEntry layout + make/accessors round-trip" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const e = try make(&rt, Value.initInteger(7), .true_val);
    try testing.expect(e.tag() == .map_entry);
    try testing.expectEqual(@as(i48, 7), keyOf(e).asInteger());
    try testing.expect(valOf(e).isTruthy());
    try testing.expectEqual(@as(i48, 7), nth(e, 0).asInteger());
    try testing.expect(nth(e, 1).isTruthy());
}
