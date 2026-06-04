// SPDX-License-Identifier: EPL-2.0
//! Symbol interning (F-004 Group A slot 1 impl).
//!
//! Symbols are interned: identical (ns, name) pairs share one heap
//! pointer, so equality reduces to a pointer comparison. Mirrors the
//! Keyword interner (`src/runtime/keyword.zig`) shape exactly — same
//! cell layout (header + ns + name + hash_cache), same rt-aware
//! top-level entry, same `std.Io.Mutex` pre-wired for the Phase B
//! concurrency rollout.
//!
//! ### Why a mirror of Keyword
//!
//! Both Symbol and Keyword are identity-bearing Values: their equality
//! contract is pointer-eq, they are pinned for the Runtime lifetime
//! (interner-owned, gpa-allocated, no GC sweep), and they fall through
//! the NaN-box `u64` compare with no per-tag branch. Diverging the
//! interner shape between the two would force every collection /
//! dispatch helper that handles "interned identity Values uniformly"
//! into a two-case branch — exactly the Cascade smell ADR-0036 +
//! ADR-0037 D6 want to prevent.
//!
//! ### Per-Value metadata is deferred
//!
//! cw v1 explicitly does NOT carry a `meta_ptr: ?*Value` field on
//! Symbol day 1, even though JVM Clojure's Symbol does. Per-Value
//! metadata is cross-cutting (Symbol + Keyword + Var + IObj-protocol
//! Values together) and lands as ADR-0037 D6 + D-075 (Phase 7+
//! metadata layer). Until D-075 lands, pointer-eq IS the finished form
//! within the cw v1 envelope — every interned Symbol is the canonical
//! wrapper, `=` and `identical?` agree by construction. See
//! ADR-0037 D6 for the rationale.

const std = @import("std");
const value = @import("value/value.zig");
const Value = value.Value;
const HeapHeader = value.HeapHeader;
const HeapTag = value.HeapTag;
const hash = @import("hash.zig");
const Runtime = @import("runtime.zig").Runtime;

/// Heap-allocated symbol. Layout-identical to `Keyword` (modulo tag).
/// Per ADR-0037 D6, no `meta_ptr` field on day 1 — deferred to D-075.
pub const Symbol = struct {
    header: HeapHeader,
    _pad: [6]u8 = undefined,
    /// Null for unqualified symbols like `foo`.
    ns: ?[]const u8,
    name: []const u8,
    /// Precomputed Murmur3 hash of `ns/name` (or just `name`).
    hash_cache: u32,

    /// Format as `ns/name` or `name`. No leading colon (that is
    /// Keyword's discipline). Returns a slice of `buf`.
    pub fn formatQualified(self: *const Symbol, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{s}{s}{s}", .{
            if (self.ns) |n| n else "",
            if (self.ns != null) "/" else "",
            self.name,
        }) catch buf[0..@min(buf.len, 1)];
    }
};

/// Process-unique symbol table. Owned by `Runtime.symbols`.
pub const SymbolInterner = struct {
    /// Backing allocator. In production this aliases `Runtime.gpa`.
    alloc: std.mem.Allocator,
    /// Composite key (`"ns/name"` or `"name"`) → `*Symbol`.
    table: std.array_hash_map.String(*Symbol) = .empty,
    /// Guards `table` against concurrent intern / find calls. The
    /// runtime is single-threaded today so this is effectively free;
    /// wiring it now means the Phase B concurrency rollout doesn't need
    /// to touch this file (matching keyword.zig's discipline).
    mutex: std.Io.Mutex = .init,

    pub fn init(alloc: std.mem.Allocator) SymbolInterner {
        return .{ .alloc = alloc };
    }

    pub fn deinit(self: *SymbolInterner) void {
        for (self.table.keys(), self.table.values()) |key, sym| {
            if (sym.ns) |n| self.alloc.free(n);
            self.alloc.free(sym.name);
            self.alloc.destroy(sym);
            self.alloc.free(key);
        }
        self.table.deinit(self.alloc);
        self.table = .empty;
    }

    /// Low-level intern — does **not** lock. Most callers should use
    /// the top-level `intern(rt, ns, name)` instead, which acquires
    /// `mutex` first. Preserved for callers that already hold the
    /// lock or are running in a known-single-threaded path (tests,
    /// fixed-input bootstrap).
    pub fn internUnlocked(self: *SymbolInterner, ns: ?[]const u8, name_: []const u8) !Value {
        const key = try formatKey(self.alloc, ns, name_);

        if (self.table.get(key)) |existing| {
            self.alloc.free(key);
            return Value.encodeHeapPtr(.symbol, existing);
        }

        const sym = try self.alloc.create(Symbol);
        sym.* = .{
            .header = HeapHeader.init(.symbol),
            .ns = if (ns) |n| (try self.alloc.dupe(u8, n)) else null,
            .name = try self.alloc.dupe(u8, name_),
            .hash_cache = computeHash(ns, name_),
        };

        try self.table.put(self.alloc, key, sym);
        return Value.encodeHeapPtr(.symbol, sym);
    }

    /// Low-level lookup — does not lock. See `internUnlocked` for
    /// when to prefer this over the rt-aware top-level `find`.
    pub fn findUnlocked(self: *SymbolInterner, ns: ?[]const u8, name_: []const u8) ?Value {
        const key = formatKey(self.alloc, ns, name_) catch return null;
        defer self.alloc.free(key);

        if (self.table.get(key)) |sym| {
            return Value.encodeHeapPtr(.symbol, sym);
        }
        return null;
    }
};

/// Intern `(ns, name)` against `rt.symbols`, locking via `rt.io`.
pub fn intern(rt: *Runtime, ns: ?[]const u8, name_: []const u8) !Value {
    rt.symbols.mutex.lockUncancelable(rt.io);
    defer rt.symbols.mutex.unlock(rt.io);
    return rt.symbols.internUnlocked(ns, name_);
}

/// Look up an existing interning. Returns `null` if not yet present.
pub fn find(rt: *Runtime, ns: ?[]const u8, name_: []const u8) ?Value {
    rt.symbols.mutex.lockUncancelable(rt.io);
    defer rt.symbols.mutex.unlock(rt.io);
    return rt.symbols.findUnlocked(ns, name_);
}

/// Decode a symbol Value to a `*const Symbol`. No table lookup —
/// pure pointer arithmetic, so no lock needed.
pub fn asSymbol(val: Value) *const Symbol {
    std.debug.assert(val.tag() == .symbol);
    return val.decodePtr(*const Symbol);
}

// --- internal helpers ---

fn formatKey(alloc: std.mem.Allocator, ns: ?[]const u8, name_: []const u8) ![]u8 {
    if (ns) |n| {
        const key = try alloc.alloc(u8, n.len + 1 + name_.len);
        @memcpy(key[0..n.len], n);
        key[n.len] = '/';
        @memcpy(key[n.len + 1 ..], name_);
        return key;
    }
    return try alloc.dupe(u8, name_);
}

fn computeHash(ns: ?[]const u8, name_: []const u8) u32 {
    if (ns) |n| {
        var h: u32 = hash.hashString(n);
        h = h *% 31 +% hash.hashString("/");
        h = h *% 31 +% hash.hashString(name_);
        return h;
    }
    return hash.hashString(name_);
}

// --- tests ---

const testing = std.testing;

const TestFixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,

    fn init(self: *TestFixture, alloc: std.mem.Allocator) void {
        self.threaded = std.Io.Threaded.init(alloc, .{});
        self.rt = Runtime.init(self.threaded.io(), alloc);
    }

    fn deinit(self: *TestFixture) void {
        self.rt.deinit();
        self.threaded.deinit();
    }
};

// --- low-level interner tests ---

test "internUnlocked creates a symbol Value" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const sym = try interner.internUnlocked(null, "foo");
    try testing.expect(sym.tag() == .symbol);

    const s = asSymbol(sym);
    try testing.expect(s.ns == null);
    try testing.expectEqualStrings("foo", s.name);
}

test "internUnlocked returns the same pointer for repeats" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const a = try interner.internUnlocked(null, "bar");
    const b = try interner.internUnlocked(null, "bar");
    try testing.expectEqual(@intFromEnum(a), @intFromEnum(b));
}

test "qualified symbols are distinct from bare via internUnlocked" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const bare = try interner.internUnlocked(null, "foo");
    const qualified = try interner.internUnlocked("ns", "foo");
    try testing.expect(@intFromEnum(bare) != @intFromEnum(qualified));

    const s = asSymbol(qualified);
    try testing.expectEqualStrings("ns", s.ns.?);
    try testing.expectEqualStrings("foo", s.name);
}

test "findUnlocked: hits an interned symbol, misses an unknown one" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    _ = try interner.internUnlocked(null, "findme");
    const result = interner.findUnlocked(null, "findme");
    try testing.expect(result != null);
    try testing.expectEqualStrings("findme", asSymbol(result.?).name);

    try testing.expect(interner.findUnlocked(null, "nonexistent") == null);
}

test "formatQualified renders bare + qualified with no leading colon" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const bare = try interner.internUnlocked(null, "foo");
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("foo", asSymbol(bare).formatQualified(&buf));

    const qualified = try interner.internUnlocked("clojure.core", "map");
    try testing.expectEqualStrings("clojure.core/map", asSymbol(qualified).formatQualified(&buf));
}

test "hash_cache is precomputed" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const sym = try interner.internUnlocked(null, "test");
    try testing.expect(asSymbol(sym).hash_cache != 0);
}

test "HeapHeader carries the symbol tag" {
    var interner = SymbolInterner.init(testing.allocator);
    defer interner.deinit();

    const sym = try interner.internUnlocked(null, "x");
    try testing.expectEqual(@as(u8, @intFromEnum(HeapTag.symbol)), asSymbol(sym).header.tag);
}

// --- rt-aware tests ---

test "intern(rt, ...) creates a symbol and round-trips" {
    var fix: TestFixture = undefined;
    fix.init(testing.allocator);
    defer fix.deinit();

    const sym = try intern(&fix.rt, null, "foo");
    try testing.expect(sym.tag() == .symbol);
    try testing.expectEqualStrings("foo", asSymbol(sym).name);
}

test "intern(rt, ...) is idempotent across calls" {
    var fix: TestFixture = undefined;
    fix.init(testing.allocator);
    defer fix.deinit();

    const a = try intern(&fix.rt, null, "bar");
    const b = try intern(&fix.rt, null, "bar");
    try testing.expectEqual(@intFromEnum(a), @intFromEnum(b));
}

test "find(rt, ...) returns interned and null for missing" {
    var fix: TestFixture = undefined;
    fix.init(testing.allocator);
    defer fix.deinit();

    _ = try intern(&fix.rt, null, "findme");
    const hit = find(&fix.rt, null, "findme");
    try testing.expect(hit != null);
    try testing.expectEqualStrings("findme", asSymbol(hit.?).name);

    try testing.expect(find(&fix.rt, null, "nope") == null);
}

test "two Runtimes maintain independent symbol tables" {
    var fix1: TestFixture = undefined;
    fix1.init(testing.allocator);
    defer fix1.deinit();
    var fix2: TestFixture = undefined;
    fix2.init(testing.allocator);
    defer fix2.deinit();

    const s1 = try intern(&fix1.rt, null, "shared");
    const s2 = try intern(&fix2.rt, null, "shared");
    try testing.expect(@intFromEnum(s1) != @intFromEnum(s2));
}

test "symbol and keyword with same name are distinct Values" {
    // Cross-class sanity check: NaN-box tag discrimination keeps
    // `'foo` and `:foo` apart even though they share a (ns, name).
    const keyword = @import("keyword.zig");
    var fix: TestFixture = undefined;
    fix.init(testing.allocator);
    defer fix.deinit();

    const sym = try intern(&fix.rt, null, "foo");
    const kw = try keyword.intern(&fix.rt, null, "foo");
    try testing.expect(@intFromEnum(sym) != @intFromEnum(kw));
    try testing.expect(sym.tag() == .symbol);
    try testing.expect(kw.tag() == .keyword);
}
