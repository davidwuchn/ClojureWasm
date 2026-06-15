// SPDX-License-Identifier: EPL-2.0
//! Lazy DFA backend (ADR-0147 Stage 3, Alt 2) — a caching subset-construction over
//! the byte automaton in `compile.zig`'s `Program`. This is the regex engine's
//! throughput backend: where the Pike VM (`match.zig`) simulates every live thread
//! per input byte, this determinizes on the fly — one DFA state = the set of NFA PCs
//! reachable so far (in PRIORITY order, cut at the first `.match`), advancing one
//! state per byte via a memoized `(state, byte) → state` transition. The first time
//! an edge is taken it is computed (epsilon-closure of the successors) and cached;
//! later visits are a map lookup.
//!
//! ## Status (this increment): forward, anchored, span-only — NOT yet wired in.
//! This file builds the FORWARD half: `matchEndAnchored` returns the leftmost-first
//! greedy match END for a match that BEGINS at a given offset, byte-identical to the
//! Pike VM's `matchAnchored` (the equivalence test below locks this). The reverse
//! DFA (leftmost START → O(input) `find`) and the `find`/`findAll` wire-in land in
//! the completing commit (ADR-0147 S3 = forward+reverse, Alt 2). Until then the Pike
//! VM in `match.zig` remains the sole user-facing matcher; this module is exercised
//! only by its own unit tests. Span-only: captures stay the two-pass Pike VM.
//!
//! ## Leftmost-FIRST (matches the Pike VM, post-2026-06-16 cut-on-match fix)
//! Determinization keeps the NFA PCs in priority order and CUTS on match — a `.match`
//! in a state's PC-list means lower-priority PCs do not advance on a transition
//! (they cannot beat a higher-priority match). So a span never disagrees with the
//! Pike VM (`a|ab` on "ab" → "a", not "ab").
//!
//! ## Eligibility
//! Anchors (`^`/`$`/`\b`) and lookaround are position-dependent and are NOT encoded
//! in a byte-DFA state — `eligible(program)` returns false for them, and the caller
//! falls back to the Pike VM. (Folding anchors into the DFA state is the deferred
//! Alt-3 follow-up; see ADR-0147.)

const std = @import("std");
const compile = @import("compile.zig");
const Program = compile.Program;

pub const StateId = u32;

/// A determinized state: the epsilon-closed NFA PC-set in priority order (the same
/// order `match.zig:addThread` produces), plus whether it is accepting. The `pcs`
/// slice is owned by the `LazyDfa` that interned it.
const State = struct {
    pcs: []const u32,
    is_match: bool,
};

/// Returns true iff every match of `program` must consume a determinable byte
/// sequence with no position-dependent assertion — i.e. the program has no
/// `.anchor` and no `.look` inst. Only such programs are byte-DFA-representable.
pub fn eligible(program: *const Program) bool {
    for (program.insts) |inst| {
        switch (inst) {
            .anchor, .look => return false,
            else => {},
        }
    }
    return true;
}

const PcSliceCtx = struct {
    pub fn hash(_: PcSliceCtx, key: []const u32) u64 {
        return std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(key));
    }
    pub fn eql(_: PcSliceCtx, a: []const u32, b: []const u32) bool {
        return std.mem.eql(u32, a, b);
    }
};

const StateMap = std.HashMapUnmanaged([]const u32, StateId, PcSliceCtx, std.hash_map.default_max_load_percentage);

/// Lazy DFA over one `Program`. Owns the interned states + the transition cache;
/// `deinit` frees everything. Build once per match call (or reuse across a scan).
pub const LazyDfa = struct {
    program: *const Program,
    alloc: std.mem.Allocator,
    states: std.ArrayList(State) = .empty,
    intern: StateMap = .empty,
    /// `(state_id << 8) | byte` → next state id. A miss is computed + cached.
    trans: std.AutoHashMapUnmanaged(u64, StateId) = .empty,
    /// Scratch reused across closure builds (visited stamps + the ordered output).
    visited: []u32,
    gen: u32 = 1,
    scratch: std.ArrayList(u32) = .empty,

    pub fn init(alloc: std.mem.Allocator, program: *const Program) std.mem.Allocator.Error!LazyDfa {
        const visited = try alloc.alloc(u32, program.insts.len);
        @memset(visited, 0);
        return .{ .program = program, .alloc = alloc, .visited = visited };
    }

    pub fn deinit(self: *LazyDfa) void {
        for (self.states.items) |st| self.alloc.free(st.pcs);
        self.states.deinit(self.alloc);
        self.intern.deinit(self.alloc);
        self.trans.deinit(self.alloc);
        self.alloc.free(self.visited);
        self.scratch.deinit(self.alloc);
    }

    /// Epsilon-closure of `seed` into `self.scratch` (priority order, dedup), mirroring
    /// `match.zig:addThread`: `jmp`/`split`/`save` are walked, consuming + `.match`
    /// insts are emitted. Eligible programs have no `.anchor`/`.look`.
    fn closure(self: *LazyDfa, seed: []const u32) std.mem.Allocator.Error!void {
        self.scratch.clearRetainingCapacity();
        // O(1) visited clear via generation bump (same idiom as ThreadList.seen).
        if (self.gen == std.math.maxInt(u32)) {
            @memset(self.visited, 0);
            self.gen = 1;
        } else {
            self.gen += 1;
        }
        for (seed) |pc| try self.addClosure(pc);
    }

    fn addClosure(self: *LazyDfa, pc: u32) std.mem.Allocator.Error!void {
        if (self.visited[pc] == self.gen) return;
        self.visited[pc] = self.gen;
        switch (self.program.insts[pc]) {
            .jmp => |t| try self.addClosure(t),
            .split => |s| {
                try self.addClosure(s.a);
                try self.addClosure(s.b);
            },
            .save => try self.addClosure(pc + 1),
            // Consuming insts + `.match` are the state's members. `.anchor`/`.look`
            // never reach here (eligible() excludes them); treat as a dead end.
            .char, .range, .class, .match => try self.scratch.append(self.alloc, pc),
            .anchor, .look => {},
        }
    }

    /// Intern the closure currently in `self.scratch` → its StateId (creating it on
    /// first sight). `is_match` = the closure contains a `.match` PC.
    fn intern_scratch(self: *LazyDfa) std.mem.Allocator.Error!StateId {
        const gop = try self.intern.getOrPut(self.alloc, self.scratch.items);
        if (gop.found_existing) return gop.value_ptr.*;
        const owned = try self.alloc.dupe(u32, self.scratch.items);
        gop.key_ptr.* = owned;
        var is_match = false;
        for (owned) |pc| {
            if (self.program.insts[pc] == .match) {
                is_match = true;
                break;
            }
        }
        const id: StateId = @intCast(self.states.items.len);
        try self.states.append(self.alloc, .{ .pcs = owned, .is_match = is_match });
        gop.value_ptr.* = id;
        return id;
    }

    /// The start state = closure of pc 0.
    fn startState(self: *LazyDfa) std.mem.Allocator.Error!StateId {
        try self.closure(&[_]u32{0});
        return self.intern_scratch();
    }

    /// Transition `state` on byte `c` → next StateId, or null for the dead state
    /// (no thread survives). Cut at the first `.match` PC in priority order so a
    /// lower-priority longer alternative does not advance (leftmost-first).
    fn transition(self: *LazyDfa, state_id: StateId, c: u8) std.mem.Allocator.Error!?StateId {
        const key = (@as(u64, state_id) << 8) | c;
        if (self.trans.get(key)) |nx| return if (nx == DEAD) null else nx;
        // Compute the seed = advanced consuming PCs before the first match, into scratch.
        self.scratch.clearRetainingCapacity();
        // Snapshot the source PCs first: `closure` (called below) reuses `scratch`,
        // and `self.states` may reallocate when interning grows it.
        const pcs = self.states.items[state_id].pcs;
        var seed_buf: std.ArrayList(u32) = .empty;
        defer seed_buf.deinit(self.alloc);
        for (pcs) |pc| {
            switch (self.program.insts[pc]) {
                .match => break, // cut lower-priority threads
                .char => |cc| if (c == cc) try seed_buf.append(self.alloc, pc + 1),
                .class => |cls| if (cls.contains(c)) try seed_buf.append(self.alloc, pc + 1),
                .range => |r| if (c >= r.lo and c <= r.hi) try seed_buf.append(self.alloc, pc + 1),
                else => {},
            }
        }
        if (seed_buf.items.len == 0) {
            try self.trans.put(self.alloc, key, DEAD);
            return null;
        }
        try self.closure(seed_buf.items);
        const nx = try self.intern_scratch();
        try self.trans.put(self.alloc, key, nx);
        return nx;
    }

    const DEAD: StateId = std.math.maxInt(StateId);

    /// Leftmost-first greedy match END for a match anchored at `start`, or null.
    /// Byte-identical to `match.zig:matchAnchored(...).end`. The match span is
    /// `[start, returned)`.
    pub fn matchEndAnchored(self: *LazyDfa, input: []const u8, start: u32) std.mem.Allocator.Error!?u32 {
        var state_id = try self.startState();
        var pos: u32 = start;
        var best: ?u32 = if (self.states.items[state_id].is_match) pos else null;
        while (pos < input.len) {
            const nx = (try self.transition(state_id, input[pos])) orelse break;
            pos += 1;
            state_id = nx;
            if (self.states.items[state_id].is_match) best = pos;
        }
        return best;
    }
};

// --- tests: equivalence vs the Pike VM (match.zig:matchAnchored) ---

const testing = std.testing;
const match = @import("match.zig");

/// Assert dfa.matchEndAnchored == pikeVM matchAnchored(...).end for `pat` over every
/// suffix-start of `input` — the exhaustive anchored-equivalence check.
fn expectDfaMatchesPike(pat: []const u8, input: []const u8) !void {
    var prog = try compile.compile(testing.allocator, pat, .{});
    defer prog.deinit(testing.allocator);
    try testing.expect(eligible(&prog)); // these test patterns are all DFA-eligible

    var dfa = try LazyDfa.init(testing.allocator, &prog);
    defer dfa.deinit();

    var start: u32 = 0;
    while (start <= input.len) : (start += 1) {
        const pike = try match.matchAnchored(testing.allocator, &prog, input, start);
        const pike_end: ?u32 = if (pike) |m| m.end else null;
        const dfa_end = try dfa.matchEndAnchored(input, start);
        try testing.expectEqual(pike_end, dfa_end);
    }
}

test "dfa eligible: anchors and lookaround are declined" {
    inline for (.{ "^a", "a$", "\\bword", "a(?=b)" }) |pat| {
        var prog = try compile.compile(testing.allocator, pat, .{});
        defer prog.deinit(testing.allocator);
        try testing.expect(!eligible(&prog));
    }
    inline for (.{ "\\d+", "a|ab", "[a-z]+", "(ab)+" }) |pat| {
        var prog = try compile.compile(testing.allocator, pat, .{});
        defer prog.deinit(testing.allocator);
        try testing.expect(eligible(&prog));
    }
}

test "dfa==pike: leftmost-first alternation a|ab" {
    try expectDfaMatchesPike("a|ab", "ab");
    try expectDfaMatchesPike("a|ab|abc", "abc");
    try expectDfaMatchesPike("foo|foobar", "foobar");
}

test "dfa==pike: greedy quantifiers" {
    try expectDfaMatchesPike("a*", "aaa");
    try expectDfaMatchesPike("a+", "aaab");
    try expectDfaMatchesPike("ab?", "ab");
    try expectDfaMatchesPike("a{2,3}", "aaaa");
}

test "dfa==pike: classes and digit runs" {
    try expectDfaMatchesPike("\\d+", "a12b345");
    try expectDfaMatchesPike("[a-z]+", "ABCdefGHI");
    try expectDfaMatchesPike("\\w+", "foo bar");
    try expectDfaMatchesPike("[^0-9]+", "abc123");
}

test "dfa==pike: alternation and groups (span only)" {
    try expectDfaMatchesPike("cat|dog", "xcatydog");
    try expectDfaMatchesPike("(ab)+", "ababab");
    try expectDfaMatchesPike("(a|b)+", "abba");
    try expectDfaMatchesPike("(foo|foobar)baz", "foobarbaz");
}

test "dfa==pike: no match and empty-capable" {
    try expectDfaMatchesPike("z", "abc");
    try expectDfaMatchesPike("x*", "");
    try expectDfaMatchesPike("a*", "bbb");
    try expectDfaMatchesPike("\\d+", "no digits here");
}
