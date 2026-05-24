// SPDX-License-Identifier: EPL-2.0
//! Free-pool recycling for cw v1 mark-sweep GC per ADR-0028 §3.
//!
//! **Phase 5 row 5.3.a skeleton.** The struct shapes land here:
//!   - `FreeNode { next: ?*FreeNode }` — intrusive linked-list node
//!     overlaid in the freed object's payload **at offset 8** (per
//!     ADR-0028 §3 DIVERGENCE from cw v0 which overlaid at offset 0
//!     and clobbered the header).
//!   - `FreePoolKey { size, alignment }` — hash key for the per-
//!     (size, alignment) pool head map.
//!   - `FreePoolMap` — `std.AutoHashMapUnmanaged(FreePoolKey, ?*FreeNode)`
//!     wrapper with `empty` / `deinit` / `push` / `pop` methods.
//!
//! Behaviour-bearing methods are stubs at 5.3.a; 5.3.c wires the
//! intrusive overlay + push/pop fast-path + the per-size-class
//! optimisation (Devil's-advocate Wildcard Alt 3 candidate — quantise
//! sizes to N power-of-2 classes and replace the HashMap with a flat
//! `[N]?*FreeNode` array; 5.3 owner picks per measured size-class
//! distribution per ADR-0028 §6 F-003 deferral).
//!
//! Minimum allocation size: **16 bytes** (per ADR-0028 §3) so the
//! freed payload can host `@sizeOf(FreeNode) = 8` bytes after the
//! 8-byte HeapHeader. Allocations under 16 bytes round up.

const std = @import("std");
const testing = std.testing;

/// Intrusive free-list node, overlaid in the freed object's payload
/// at offset 8 (after the 8-byte HeapHeader). The freed block's
/// payload must be ≥ `@sizeOf(FreeNode) = 8` bytes — combined with
/// the 8-byte header this gives the 16-byte minimum allocation that
/// ADR-0028 §3 enforces.
pub const FreeNode = struct {
    next: ?*FreeNode = null,
};

/// Per-(size, alignment) free pool key. Alignment is always 8 per
/// ADR-0027 §1 `align(8)` invariant, so an optimised future shape
/// can collapse to a size-only key + per-size-class array (the
/// Devil's-advocate Wildcard Alt 3 candidate captured in ADR-0028 §3
/// + §6's F-003 deferral).
pub const FreePoolKey = struct {
    size: usize,
    alignment: std.mem.Alignment,

    pub fn eql(self: FreePoolKey, other: FreePoolKey) bool {
        return self.size == other.size and self.alignment == other.alignment;
    }
};

/// Per-(size, alignment) free pool head map. **Phase 5.3.c.2 body.**
/// Push lands freed memory at the head of the matching pool (intrusive
/// overlay at offset 8 per ADR-0028 §3); pop returns the memory base
/// to caller for reuse. Deinit walks every pool and `rawFree`s each
/// node's backing memory back to `infra`.
///
/// Memory layout convention (per ADR-0028 §3): the freed block's
/// bytes 0..7 hold the (preserved-but-stale) HeapHeader; bytes 8..15
/// host the `FreeNode { next }` overlay. The returned `[*]u8` from
/// `pop` points at offset 0 (the HeapHeader position) so the caller
/// can cast to `*T` with HeapHeader at offset 0.
pub const FreePoolMap = struct {
    /// HashMap from key to pool head. `null` head = pool exists with
    /// no free nodes; absent key = pool not yet observed at any size.
    /// Devil's-advocate Wildcard Alt 3 (size-class quantised flat
    /// array) defers to a future ADR per ADR-0028 §3 + §6 F-003.
    map: std.AutoHashMap(FreePoolKey, ?*FreeNode) = undefined,

    pub const empty: FreePoolMap = .{ .map = undefined };

    /// Two-step init pattern: create the map with the infra allocator
    /// at GcHeap.init time. `empty` literal defers map construction
    /// to a follow-up `initMap(infra)` call so the `FreePoolMap` can
    /// live as a default-initialised field on `GcHeap`.
    pub fn initMap(self: *FreePoolMap, infra: std.mem.Allocator) void {
        self.map = std.AutoHashMap(FreePoolKey, ?*FreeNode).init(infra);
    }

    pub fn deinit(self: *FreePoolMap, infra: std.mem.Allocator) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            var maybe_node = entry.value_ptr.*;
            while (maybe_node) |node| {
                const next = node.next;
                // Recover the memory base (offset 0, HeapHeader
                // position) from the FreeNode address (offset 8).
                const mem_base: [*]u8 = @ptrFromInt(@intFromPtr(node) - 8);
                infra.rawFree(mem_base[0..key.size], key.alignment, @returnAddress());
                maybe_node = next;
            }
        }
        self.map.deinit();
    }

    /// Push a freed memory block onto the matching (size, alignment)
    /// pool. `mem` must be the memory base (offset 0, HeapHeader
    /// position) — the FreeNode is overlaid at offset 8.
    /// Requires `key.size >= 16` so the payload can host the FreeNode.
    pub fn push(self: *FreePoolMap, key: FreePoolKey, mem: [*]u8) !void {
        std.debug.assert(key.size >= 16);
        const node_ptr: *FreeNode = @ptrCast(@alignCast(mem + 8));
        const gop = try self.map.getOrPut(key);
        if (!gop.found_existing) gop.value_ptr.* = null;
        node_ptr.* = .{ .next = gop.value_ptr.* };
        gop.value_ptr.* = node_ptr;
    }

    /// Pop a freed memory block from the matching pool, or return
    /// null if the pool is empty / absent. Returns the memory base
    /// (offset 0, HeapHeader position) suitable for caller cast.
    pub fn pop(self: *FreePoolMap, key: FreePoolKey) ?[*]u8 {
        const head_entry = self.map.getPtr(key) orelse return null;
        const node = head_entry.* orelse return null;
        head_entry.* = node.next;
        const mem_base: [*]u8 = @ptrFromInt(@intFromPtr(node) - 8);
        return mem_base;
    }
};

// --- tests ---

test "FreeNode is at most 16 bytes (intrusive overlay budget)" {
    // @sizeOf(FreeNode) ≤ 8 ensures it fits in the payload of the
    // 16-byte minimum allocation after the 8-byte HeapHeader. On 64-
    // bit targets this is exactly 8 bytes (single `?*FreeNode`).
    try testing.expect(@sizeOf(FreeNode) <= 8);
}

test "FreePoolKey eql" {
    const k1 = FreePoolKey{ .size = 32, .alignment = .@"8" };
    const k2 = FreePoolKey{ .size = 32, .alignment = .@"8" };
    const k3 = FreePoolKey{ .size = 64, .alignment = .@"8" };

    try testing.expect(k1.eql(k2));
    try testing.expect(!k1.eql(k3));
}

test "FreePoolMap init / deinit empty" {
    var pool: FreePoolMap = .empty;
    pool.initMap(testing.allocator);
    defer pool.deinit(testing.allocator);

    try testing.expectEqual(@as(u32, 0), pool.map.count());
}

test "FreePoolMap push then pop returns the same memory base (LIFO)" {
    var pool: FreePoolMap = .empty;
    pool.initMap(testing.allocator);
    defer pool.deinit(testing.allocator);

    const align_t: std.mem.Alignment = .@"8";
    const key = FreePoolKey{ .size = 16, .alignment = align_t };

    // Manually allocate a 16-byte block (header + payload) and push.
    const raw_a = testing.allocator.rawAlloc(16, align_t, @returnAddress()) orelse
        return error.OutOfMemory;
    try pool.push(key, raw_a);

    const popped = pool.pop(key) orelse return error.PopMissed;
    try testing.expectEqual(raw_a, popped);
    try testing.expect(pool.pop(key) == null);

    testing.allocator.rawFree(popped[0..16], align_t, @returnAddress());
}

test "FreePoolMap push twice + pop twice (LIFO order)" {
    var pool: FreePoolMap = .empty;
    pool.initMap(testing.allocator);
    defer pool.deinit(testing.allocator);

    const align_t: std.mem.Alignment = .@"8";
    const key = FreePoolKey{ .size = 16, .alignment = align_t };

    const raw_a = testing.allocator.rawAlloc(16, align_t, @returnAddress()) orelse
        return error.OutOfMemory;
    const raw_b = testing.allocator.rawAlloc(16, align_t, @returnAddress()) orelse
        return error.OutOfMemory;
    try pool.push(key, raw_a);
    try pool.push(key, raw_b);

    // LIFO: pop returns most-recently pushed first.
    const first_pop = pool.pop(key) orelse return error.PopMissed;
    const second_pop = pool.pop(key) orelse return error.PopMissed;
    try testing.expectEqual(raw_b, first_pop);
    try testing.expectEqual(raw_a, second_pop);

    testing.allocator.rawFree(raw_a[0..16], align_t, @returnAddress());
    testing.allocator.rawFree(raw_b[0..16], align_t, @returnAddress());
}

test "FreePoolMap.pop on absent key returns null" {
    var pool: FreePoolMap = .empty;
    pool.initMap(testing.allocator);
    defer pool.deinit(testing.allocator);

    const key = FreePoolKey{ .size = 32, .alignment = .@"8" };
    try testing.expect(pool.pop(key) == null);
}
