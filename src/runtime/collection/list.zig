//! PersistentList — Clojure's singly-linked cons-cell list.
//!
//! Each `Cons` cell holds `first` (head), `rest` (tail: `nil` or another
//! list pointer), `meta` (`nil` or a metadata map), and `count` (O(1)
//! length). Lists are immutable and structurally shared — `cons(x, ys)`
//! reuses `ys` directly.

const std = @import("std");
const value = @import("../value/value.zig");
const Value = value.Value;
const HeapHeader = value.HeapHeader;
const HeapTag = value.HeapTag;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");
const mark_sweep = @import("../gc/mark_sweep.zig");

/// Cons cell — fundamental list-building block. `extern struct` so
/// declaration order is preserved + HeapHeader lands at offset 0
/// (required by `gc.alloc(T)` per the comptime check).
pub const Cons = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    first: Value,
    rest: Value,
    meta: Value,
    count: u32,

    comptime {
        std.debug.assert(@alignOf(Cons) >= 8);
        std.debug.assert(@offsetOf(Cons, "header") == 0);
    }
};

/// Allocate a new cons cell prepending `head` to `tail`. `tail` must be
/// `nil` or a list Value; `count` is precomputed so callers see O(1)
/// length.
pub fn cons(alloc: std.mem.Allocator, head: Value, tail: Value) !Value {
    const cell = try alloc.create(Cons);
    cell.* = .{
        .header = HeapHeader.init(.list),
        .first = head,
        .rest = tail,
        .meta = .nil_val,
        .count = 1 + countOf(tail),
    };
    return Value.encodeHeapPtr(.list, cell);
}

/// Allocate a new cons cell on the GC heap, so the resulting Value
/// outlives any per-eval arena (e.g. when the list ends up bound to
/// a global Var). Use this for quoted-list literals and any list a
/// primitive needs to return to caller-land. Tests + per-test arenas
/// keep using the plain `cons` above when they don't need long-lived
/// Values.
///
/// 5.3.d.5 migration: rt.gpa.create + trackHeap → rt.gc.alloc; the
/// per-tag trace fn (registered by `registerGcHooks`) walks
/// first / rest / meta so the GC sees the outgoing pointers and
/// keeps reachable children alive.
pub fn consHeap(rt: *Runtime, head: Value, tail: Value) !Value {
    const cell = try rt.gc.alloc(Cons);
    cell.* = .{
        .header = HeapHeader.init(.list),
        .first = head,
        .rest = tail,
        .meta = .nil_val,
        .count = 1 + countOf(tail),
    };
    return Value.encodeHeapPtr(.list, cell);
}

/// Per-tag trace fn called by mark phase to walk outgoing GC-managed
/// pointers per ADR-0028 §5 + the cw v0 D100 "transitive trace"
/// requirement. Cons has no owned non-GC resources so no finaliser
/// is needed.
pub fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const c: *Cons = @ptrCast(@alignCast(header));
    if (c.first.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    if (c.rest.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
    if (c.meta.heapHeader()) |hdr| mark_sweep.mark(gc, hdr);
}

/// Register Cons's trace fn into `tag_ops.tag_trace_table[.list]`.
/// Idempotent at the same fn pointer; called from `Runtime.init`.
pub fn registerGcHooks() void {
    tag_ops.registerTrace(.list, &traceGc);
}

/// First element. `nil` for non-list inputs (matches Clojure's `first`).
pub fn first(val: Value) Value {
    return switch (val.tag()) {
        .list => val.decodePtr(*Cons).first,
        else => .nil_val,
    };
}

/// Rest of a list. `nil` for non-list inputs and at the tail end.
pub fn rest(val: Value) Value {
    return switch (val.tag()) {
        .list => val.decodePtr(*Cons).rest,
        else => .nil_val,
    };
}

/// O(1) length. `0` for non-list inputs.
pub fn countOf(val: Value) u32 {
    return switch (val.tag()) {
        .list => val.decodePtr(*Cons).count,
        else => 0,
    };
}

/// Sequence view: `val` itself if non-empty, otherwise `nil`. Mirrors
/// Clojure's `(seq xs)` — empty colls become `nil`.
pub fn seq(val: Value) Value {
    return switch (val.tag()) {
        .list => if (val.decodePtr(*Cons).count > 0) val else .nil_val,
        else => .nil_val,
    };
}

/// Raw `Cons` pointer view. Caller must already know `val` is a list.
pub fn asCons(val: Value) *Cons {
    std.debug.assert(val.tag() == .list);
    return val.decodePtr(*Cons);
}

// --- tests ---

const testing = std.testing;

test "Cons alignment" {
    try testing.expect(@alignOf(Cons) >= 8);
}

test "cons creates a single-element list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lst = try cons(alloc, Value.initInteger(42), .nil_val);

    try testing.expect(lst.tag() == .list);
    try testing.expectEqual(@as(u32, 1), countOf(lst));
    try testing.expectEqual(@as(i48, 42), first(lst).asInteger());
    try testing.expect(rest(lst).isNil());
}

fn consHeapFailingHarness(alloc_inner: std.mem.Allocator) !void {
    var th = std.Io.Threaded.init(alloc_inner, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), alloc_inner);
    defer rt.deinit();
    _ = try consHeap(&rt, Value.initInteger(42), .nil_val);
}

test "consHeap returns OOM without leaking under each allocation failure (uniform errdefer)" {
    try testing.checkAllAllocationFailures(testing.allocator, consHeapFailingHarness, .{});
}

test "cons creates a multi-element list (1 2 3)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const l3 = try cons(alloc, Value.initInteger(3), .nil_val);
    const l2 = try cons(alloc, Value.initInteger(2), l3);
    const l1 = try cons(alloc, Value.initInteger(1), l2);

    try testing.expectEqual(@as(u32, 3), countOf(l1));
    try testing.expectEqual(@as(u32, 2), countOf(l2));
    try testing.expectEqual(@as(u32, 1), countOf(l3));

    try testing.expectEqual(@as(i48, 1), first(l1).asInteger());
    try testing.expectEqual(@as(i48, 2), first(rest(l1)).asInteger());
    try testing.expectEqual(@as(i48, 3), first(rest(rest(l1))).asInteger());
    try testing.expect(rest(rest(rest(l1))).isNil());
}

test "first / rest / countOf on nil" {
    try testing.expect(first(.nil_val).isNil());
    try testing.expect(rest(.nil_val).isNil());
    try testing.expectEqual(@as(u32, 0), countOf(.nil_val));
}

test "seq is itself for non-empty, nil for empty input" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lst = try cons(alloc, Value.initInteger(1), .nil_val);
    try testing.expect(!seq(lst).isNil());
    try testing.expect(seq(.nil_val).isNil());
}

test "HeapHeader carries the list tag and starts unmarked / unfrozen" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lst = try cons(alloc, .true_val, .nil_val);
    const cell = asCons(lst);
    try testing.expectEqual(@as(u8, @intFromEnum(HeapTag.list)), cell.header.tag);
    // GC mark bit lives in gc_and_lock.gc_mark per ADR-0009 a2 +
    // 5.3.d.9 (Flags.marked removed; mark bit 0 of gc_mark).
    try testing.expectEqual(@as(u30, 0), cell.header.gc_and_lock.gc_mark & 1);
    try testing.expect(!cell.header.flags.frozen);
}

test "meta defaults to nil" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lst = try cons(alloc, Value.initInteger(1), .nil_val);
    try testing.expect(asCons(lst).meta.isNil());
}

test "structural sharing across cons calls" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const tail = try cons(alloc, Value.initInteger(2), try cons(alloc, Value.initInteger(3), .nil_val));
    const a = try cons(alloc, Value.initInteger(1), tail);
    const b = try cons(alloc, Value.initInteger(0), tail);

    try testing.expectEqual(@intFromEnum(rest(a)), @intFromEnum(rest(b)));
    try testing.expectEqual(@as(u32, 3), countOf(a));
    try testing.expectEqual(@as(u32, 3), countOf(b));
}
