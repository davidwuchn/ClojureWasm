// SPDX-License-Identifier: EPL-2.0
//! Sorted collections — persistent left-leaning red-black (LLRB) tree
//! (ADR-0057). `SortedMap` is the tree; `SortedSet` wraps a SortedMap
//! (element → element). Keys order by `compare.valueCompare` (default)
//! or a custom comparator (the `-by` ctors — cycle B). assoc/insert is
//! O(log n) path-copy with structural sharing (the persistent contract
//! the HAMT / vector trie honour); the chosen LLRB shape was taken over
//! a flat sorted array per ADR-0057's Devil's-advocate fork (F-002).
//!
//! Cycle A (this file's first landing): build (assoc/conj) + get /
//! contains? / count / seq / keys / vals + sorted-map/sorted-set + sorted?.
//! dissoc / disj (the LLRB delete) + custom `-by` comparators are cycle B;
//! subseq / rsubseq / rseq are cycle C.

const std = @import("std");
const value = @import("../value/value.zig");
const Value = value.Value;
const HeapHeader = value.HeapHeader;
const Runtime = @import("../runtime.zig").Runtime;
const tag_ops = @import("../gc/tag_ops.zig");
const gc_heap_mod = @import("../gc/gc_heap.zig");
const mark_sweep = @import("../gc/mark_sweep.zig");
const compare_mod = @import("../compare.zig");
const list_mod = @import("list.zig");
const vector_mod = @import("vector.zig");
const SourceLocation = @import("../error/info.zig").SourceLocation;

const RED: u8 = 1;
const BLACK: u8 = 0;

/// LLRB interior node. `left`/`right` are `rb_node` Values or nil.
pub const RbNode = extern struct {
    header: HeapHeader,
    color: u8 = RED,
    _pad: [5]u8 = .{ 0, 0, 0, 0, 0 },
    key: Value,
    val: Value,
    left: Value = Value.nil_val,
    right: Value = Value.nil_val,

    comptime {
        std.debug.assert(@alignOf(RbNode) >= 8);
        std.debug.assert(@offsetOf(RbNode, "header") == 0);
    }
};

/// Sorted map: tree root + count + (optional custom) comparator + meta.
pub const SortedMap = extern struct {
    header: HeapHeader,
    _pad: [2]u8 = .{ 0, 0 },
    count: u32 = 0,
    comparator: Value = Value.nil_val, // nil = default valueCompare; custom = cycle B
    root: Value = Value.nil_val, // rb_node or nil
    meta: Value = Value.nil_val,

    comptime {
        std.debug.assert(@alignOf(SortedMap) >= 8);
        std.debug.assert(@offsetOf(SortedMap, "header") == 0);
    }
};

/// Sorted set: wraps a SortedMap (element → element), mirroring
/// PersistentHashSet → map.
pub const SortedSet = extern struct {
    header: HeapHeader,
    _pad: [2]u8 = .{ 0, 0 },
    count: u32 = 0,
    map: Value = Value.nil_val, // a `.sorted_map`
    meta: Value = Value.nil_val,

    comptime {
        std.debug.assert(@alignOf(SortedSet) >= 8);
        std.debug.assert(@offsetOf(SortedSet, "header") == 0);
    }
};

inline fn isRed(v: Value) bool {
    return v.tag() == .rb_node and v.decodePtr(*const RbNode).color == RED;
}

fn newNode(rt: *Runtime, key: Value, val: Value, left: Value, right: Value, color: u8) !Value {
    const n = try rt.gc.alloc(RbNode);
    n.* = .{ .header = HeapHeader.init(.rb_node), .color = color, .key = key, .val = val, .left = left, .right = right };
    return Value.encodeHeapPtr(.rb_node, n);
}

/// Three-way key order. Default (nil comparator) = valueCompare; a custom
/// comparator (sorted-map-by) is cycle B.
fn compareKeys(rt: *Runtime, comparator: Value, a: Value, b: Value, loc: SourceLocation) !std.math.Order {
    if (comparator.isNil()) return compare_mod.valueCompare(rt, a, b, loc);
    return error.SortedCustomComparatorNotImplemented; // cycle B
}

// --- functional LLRB rotations (all allocate fresh nodes — persistent) ---

fn rotateLeft(rt: *Runtime, h: Value) !Value {
    const hn = h.decodePtr(*const RbNode);
    const x = hn.right.decodePtr(*const RbNode);
    const new_h = try newNode(rt, hn.key, hn.val, hn.left, x.left, RED);
    return newNode(rt, x.key, x.val, new_h, x.right, hn.color);
}

fn rotateRight(rt: *Runtime, h: Value) !Value {
    const hn = h.decodePtr(*const RbNode);
    const x = hn.left.decodePtr(*const RbNode);
    const new_h = try newNode(rt, hn.key, hn.val, x.right, hn.right, RED);
    return newNode(rt, x.key, x.val, x.left, new_h, hn.color);
}

fn recolorFlip(rt: *Runtime, v: Value) !Value {
    const n = v.decodePtr(*const RbNode);
    return newNode(rt, n.key, n.val, n.left, n.right, if (n.color == RED) BLACK else RED);
}

fn flipColors(rt: *Runtime, h: Value) !Value {
    const hn = h.decodePtr(*const RbNode);
    const nl = try recolorFlip(rt, hn.left);
    const nr = try recolorFlip(rt, hn.right);
    return newNode(rt, hn.key, hn.val, nl, nr, if (hn.color == RED) BLACK else RED);
}

fn balance(rt: *Runtime, h: Value) !Value {
    var n = h;
    const hn = n.decodePtr(*const RbNode);
    if (isRed(hn.right) and !isRed(hn.left)) n = try rotateLeft(rt, n);
    const n2 = n.decodePtr(*const RbNode);
    if (isRed(n2.left) and isRed(n2.left.decodePtr(*const RbNode).left)) n = try rotateRight(rt, n);
    const n3 = n.decodePtr(*const RbNode);
    if (isRed(n3.left) and isRed(n3.right)) n = try flipColors(rt, n);
    return n;
}

const InsResult = struct { node: Value, added: bool };

fn insert(rt: *Runtime, comparator: Value, h: Value, key: Value, val: Value, loc: SourceLocation) !InsResult {
    if (h.tag() != .rb_node) {
        return .{ .node = try newNode(rt, key, val, Value.nil_val, Value.nil_val, RED), .added = true };
    }
    const hn = h.decodePtr(*const RbNode);
    const order = try compareKeys(rt, comparator, key, hn.key, loc);
    var added = false;
    var built: Value = undefined;
    switch (order) {
        .lt => {
            const r = try insert(rt, comparator, hn.left, key, val, loc);
            added = r.added;
            built = try newNode(rt, hn.key, hn.val, r.node, hn.right, hn.color);
        },
        .gt => {
            const r = try insert(rt, comparator, hn.right, key, val, loc);
            added = r.added;
            built = try newNode(rt, hn.key, hn.val, hn.left, r.node, hn.color);
        },
        .eq => {
            built = try newNode(rt, hn.key, val, hn.left, hn.right, hn.color);
        },
    }
    return .{ .node = try balance(rt, built), .added = added };
}

fn makeBlack(rt: *Runtime, root: Value) !Value {
    if (root.tag() != .rb_node) return root;
    const rn = root.decodePtr(*const RbNode);
    if (rn.color == BLACK) return root;
    return newNode(rt, rn.key, rn.val, rn.left, rn.right, BLACK);
}

// --- SortedMap public API ---

pub fn emptyMap(rt: *Runtime) !Value {
    const m = try rt.gc.alloc(SortedMap);
    m.* = .{ .header = HeapHeader.init(.sorted_map) };
    return Value.encodeHeapPtr(.sorted_map, m);
}

pub fn isSortedMap(v: Value) bool {
    return v.tag() == .sorted_map;
}

pub fn count(v: Value) u32 {
    return switch (v.tag()) {
        .sorted_map => v.decodePtr(*const SortedMap).count,
        .sorted_set => v.decodePtr(*const SortedSet).count,
        else => 0,
    };
}

pub fn assoc(rt: *Runtime, m_val: Value, key: Value, val: Value, loc: SourceLocation) !Value {
    const m = m_val.decodePtr(*const SortedMap);
    const r = try insert(rt, m.comparator, m.root, key, val, loc);
    const black = try makeBlack(rt, r.node);
    const nm = try rt.gc.alloc(SortedMap);
    nm.* = .{
        .header = HeapHeader.init(.sorted_map),
        .count = if (r.added) m.count + 1 else m.count,
        .comparator = m.comparator,
        .root = black,
        .meta = m.meta,
    };
    return Value.encodeHeapPtr(.sorted_map, nm);
}

pub fn get(rt: *Runtime, m_val: Value, key: Value, loc: SourceLocation) !Value {
    const m = m_val.decodePtr(*const SortedMap);
    var h = m.root;
    while (h.tag() == .rb_node) {
        const hn = h.decodePtr(*const RbNode);
        switch (try compareKeys(rt, m.comparator, key, hn.key, loc)) {
            .lt => h = hn.left,
            .gt => h = hn.right,
            .eq => return hn.val,
        }
    }
    return Value.nil_val;
}

pub fn contains(rt: *Runtime, m_val: Value, key: Value, loc: SourceLocation) !bool {
    const m = m_val.decodePtr(*const SortedMap);
    var h = m.root;
    while (h.tag() == .rb_node) {
        const hn = h.decodePtr(*const RbNode);
        switch (try compareKeys(rt, m.comparator, key, hn.key, loc)) {
            .lt => h = hn.left,
            .gt => h = hn.right,
            .eq => return true,
        }
    }
    return false;
}

// In-order walk variants. `consHeap` prepends, so processing
// right→node→left yields ascending order at the front.
fn keysInto(rt: *Runtime, h: Value, acc: Value) !Value {
    if (h.tag() != .rb_node) return acc;
    const hn = h.decodePtr(*const RbNode);
    var result = try keysInto(rt, hn.right, acc);
    result = try list_mod.consHeap(rt, hn.key, result);
    return keysInto(rt, hn.left, result);
}

fn valsInto(rt: *Runtime, h: Value, acc: Value) !Value {
    if (h.tag() != .rb_node) return acc;
    const hn = h.decodePtr(*const RbNode);
    var result = try valsInto(rt, hn.right, acc);
    result = try list_mod.consHeap(rt, hn.val, result);
    return valsInto(rt, hn.left, result);
}

fn seqInto(rt: *Runtime, h: Value, acc: Value) !Value {
    if (h.tag() != .rb_node) return acc;
    const hn = h.decodePtr(*const RbNode);
    var result = try seqInto(rt, hn.right, acc);
    var pair = vector_mod.empty();
    pair = try vector_mod.conj(rt, pair, hn.key);
    pair = try vector_mod.conj(rt, pair, hn.val);
    result = try list_mod.consHeap(rt, pair, result);
    return seqInto(rt, hn.left, result);
}

pub fn keys(rt: *Runtime, v: Value) !Value {
    return switch (v.tag()) {
        .sorted_map => try keysInto(rt, v.decodePtr(*const SortedMap).root, Value.nil_val),
        .sorted_set => try keysInto(rt, mapOf(v).decodePtr(*const SortedMap).root, Value.nil_val),
        else => Value.nil_val,
    };
}

pub fn vals(rt: *Runtime, v: Value) !Value {
    return try valsInto(rt, v.decodePtr(*const SortedMap).root, Value.nil_val);
}

pub fn seq(rt: *Runtime, v: Value) !Value {
    return switch (v.tag()) {
        .sorted_map => try seqInto(rt, v.decodePtr(*const SortedMap).root, Value.nil_val),
        .sorted_set => try keysInto(rt, mapOf(v).decodePtr(*const SortedMap).root, Value.nil_val),
        else => Value.nil_val,
    };
}

// --- SortedSet public API (wraps a SortedMap, element → element) ---

inline fn mapOf(set_val: Value) Value {
    return set_val.decodePtr(*const SortedSet).map;
}

pub fn emptySet(rt: *Runtime) !Value {
    const inner = try emptyMap(rt);
    const s = try rt.gc.alloc(SortedSet);
    s.* = .{ .header = HeapHeader.init(.sorted_set), .map = inner };
    return Value.encodeHeapPtr(.sorted_set, s);
}

pub fn isSortedSet(v: Value) bool {
    return v.tag() == .sorted_set;
}

pub fn conjSet(rt: *Runtime, set_val: Value, elem: Value, loc: SourceLocation) !Value {
    const s = set_val.decodePtr(*const SortedSet);
    const new_map = try assoc(rt, s.map, elem, elem, loc);
    const ns = try rt.gc.alloc(SortedSet);
    ns.* = .{ .header = HeapHeader.init(.sorted_set), .count = new_map.decodePtr(*const SortedMap).count, .map = new_map, .meta = s.meta };
    return Value.encodeHeapPtr(.sorted_set, ns);
}

pub fn setContains(rt: *Runtime, set_val: Value, elem: Value, loc: SourceLocation) !bool {
    return contains(rt, mapOf(set_val), elem, loc);
}

// --- GC traces ---

pub fn traceRbNode(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const n: *RbNode = @ptrCast(@alignCast(header));
    if (n.key.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (n.val.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (n.left.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (n.right.heapHeader()) |h| mark_sweep.mark(gc, h);
}

pub fn traceSortedMap(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const m: *SortedMap = @ptrCast(@alignCast(header));
    if (m.comparator.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (m.root.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (m.meta.heapHeader()) |h| mark_sweep.mark(gc, h);
}

pub fn traceSortedSet(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const s: *SortedSet = @ptrCast(@alignCast(header));
    if (s.map.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (s.meta.heapHeader()) |h| mark_sweep.mark(gc, h);
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.rb_node, &traceRbNode);
    tag_ops.registerTrace(.sorted_map, &traceSortedMap);
    tag_ops.registerTrace(.sorted_set, &traceSortedSet);
}

// --- tests ---

const testing = std.testing;

test "SortedMap assoc keeps key order + get + count + dup-replace" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const noloc: SourceLocation = .{};
    var m = try emptyMap(&rt);
    // insert 0..49 in a shuffled-ish order (i*17 mod 50 is a permutation)
    var i: i48 = 0;
    while (i < 50) : (i += 1) {
        const k = @mod(i * 17, 50);
        m = try assoc(&rt, m, Value.initInteger(k), Value.initInteger(k * 10), noloc);
    }
    try testing.expectEqual(@as(u32, 50), count(m));
    // every key reads back
    i = 0;
    while (i < 50) : (i += 1) {
        try testing.expectEqual(@as(i48, i * 10), (try get(&rt, m, Value.initInteger(i), noloc)).asInteger());
    }
    // dup key replaces, count unchanged
    m = try assoc(&rt, m, Value.initInteger(7), Value.initInteger(-1), noloc);
    try testing.expectEqual(@as(u32, 50), count(m));
    try testing.expectEqual(@as(i48, -1), (try get(&rt, m, Value.initInteger(7), noloc)).asInteger());
    try testing.expect(!try contains(&rt, m, Value.initInteger(999), noloc));
}
