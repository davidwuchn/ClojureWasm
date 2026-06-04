// SPDX-License-Identifier: EPL-2.0
//! STM LockingTransaction engine (Phase B #5, ADR-0090 §3 — MVCC retry-only).
//!
//! `(dosync body...)` → `(__run-in-transaction (fn* [] body...))` runs the
//! body thunk inside a transaction on the CALLING thread (not a spawned
//! worker — unlike `future`). Inside the transaction, `ref-set` / `alter`
//! write to a per-transaction value cache (`vals`); `deref` of a Ref reads
//! through the cache (a transaction sees its own writes); at commit the
//! written Refs' locks are taken, a commit-point is stamped, and a new TVal is
//! spliced/recycled into each Ref's MVCC history ring.
//!
//! **This increment (#5-i) is the single-ref, single-thread slice**: no retry
//! loop (a single thread never conflicts), no multi-ref lock ordering (one
//! ref → no deadlock surface), no commute/ensure, no snapshot read-point walk
//! (no concurrent commit can change a Ref mid-transaction). Those land in
//! later increments (#5-ii multi-ref lock ordering via a `Ref.id`, #5-iii
//! retry + the read-point walk + the concurrent serializability test + AD-013,
//! #5-iv commute, #5-v ensure). The retry/conflict machinery + the GC rooting
//! of the in-txn maps (a peer collect racing a live `dosync` — dormant until
//! auto-collect `#4a'`) are the remaining hardening.
//!
//! `current_tx` is a threadlocal (mirroring `env.current_frame`): the
//! transaction context for the running thread. Nested `(dosync (dosync ...))`
//! reuses the outer transaction (clj semantics).

const std = @import("std");
const value_mod = @import("../value/value.zig");
const Value = value_mod.Value;
const Runtime = @import("../runtime.zig").Runtime;
const Env = @import("../env.zig").Env;
const ref_mod = @import("../stm/ref.zig");
const Ref = ref_mod.Ref;
const tval_mod = @import("../stm/tval.zig");
const TVal = tval_mod.TVal;
const heap_header = @import("../value/heap_header.zig");
const HeapHeader = heap_header.HeapHeader;
const error_catalog = @import("../error/catalog.zig");
const SourceLocation = @import("../error/info.zig").SourceLocation;

/// Bounded retry count for a conflicting transaction (clj `RETRY_LIMIT`).
const RETRY_LIMIT: u32 = 10000;

/// Monotonic point counter — `getReadPoint`/`getCommitPoint` both
/// increment-and-get (clj `lastPoint.incrementAndGet()`), so a read-point and
/// a commit-point are distinct ordered ids.
var last_point: std.atomic.Value(i64) = .init(0);

fn nextPoint() i64 {
    return last_point.fetchAdd(1, .monotonic) + 1;
}

pub const LockingTransaction = struct {
    read_point: i64,
    /// In-transaction value cache: a Ref's value AS SEEN by this transaction
    /// (its own writes included). Keyed by the GC-heap `*Ref`.
    vals: std.AutoHashMapUnmanaged(*Ref, Value) = .empty,
    /// Refs explicitly written (`ref-set`/`alter`) — the commit write set.
    sets: std.AutoHashMapUnmanaged(*Ref, void) = .empty,
    gpa: std.mem.Allocator,
};

/// The running transaction for THIS thread, or null outside any `dosync`.
/// Threadlocal — mirrors `env.current_frame`. (The GC rooting of a live
/// transaction's `vals` map is the #4a' hardening; dormant while auto-collect
/// is off — no collect fires during a `dosync` today.)
pub threadlocal var current_tx: ?*LockingTransaction = null;

/// True when a transaction is running on this thread.
pub fn inTransaction() bool {
    return current_tx != null;
}

/// `(__run-in-transaction thunk)` — run the 0-arg `thunk` in a transaction and
/// return its value. Nested `dosync` reuses the outer transaction. #5-i is
/// single-thread: the body runs once and commits (no conflict → no retry).
pub fn runInTransaction(rt: *Runtime, env: *Env, thunk: Value, loc: SourceLocation) !Value {
    if (current_tx != null) {
        // Nested — accumulate into the outer transaction, no new commit here.
        return callThunk(rt, env, thunk, loc);
    }
    var tx: LockingTransaction = .{ .read_point = 0, .gpa = rt.gpa };
    defer tx.vals.deinit(rt.gpa);
    defer tx.sets.deinit(rt.gpa);
    current_tx = &tx;
    defer current_tx = null;

    // Bounded retry loop (clj `run`): each try takes a fresh read-point + clean
    // maps; a commit-time conflict (a peer committed a newer version after our
    // snapshot) re-runs the body. Retry-only — no barge (AD-013). A single
    // thread never conflicts, so this is a one-pass loop there.
    var attempt: u32 = 0;
    while (attempt < RETRY_LIMIT) : (attempt += 1) {
        tx.read_point = nextPoint();
        tx.vals.clearRetainingCapacity();
        tx.sets.clearRetainingCapacity();
        const ret = callThunk(rt, env, thunk, loc) catch |e| {
            if (e == error.StmRetry) continue;
            return e; // a real user error propagates out of the transaction
        };
        commit(rt, &tx) catch |e| {
            if (e == error.StmRetry) continue;
            return e;
        };
        return ret;
    }
    return error_catalog.raise(.stm_retry_limit, loc, .{});
}

fn callThunk(rt: *Runtime, env: *Env, thunk: Value, loc: SourceLocation) !Value {
    const vtable = rt.vtable orelse return error.InternalError;
    return vtable.callFn(rt, env, thunk, &.{}, loc);
}

/// In-transaction read of a Ref: the transaction's own cached write if any,
/// else the Ref's current committed value. (#5-i: no snapshot read-point ring
/// walk — a single thread sees no concurrent commit; #5-iii adds the walk +
/// the fault-driven retry.)
pub fn doGet(tx: *LockingTransaction, ref: *Ref) Value {
    if (tx.vals.get(ref)) |v| return v;
    return ref.tvals.val;
}

/// In-transaction write of a Ref (`ref-set`). Records the Ref in the write set
/// + caches the value. Returns the written value.
pub fn doSet(tx: *LockingTransaction, ref: *Ref, val: Value) !Value {
    try tx.vals.put(tx.gpa, ref, val);
    try tx.sets.put(tx.gpa, ref, {});
    return val;
}

/// Commit: for each written Ref, take its lock, check the read-point conflict,
/// stamp a commit-point, and splice/recycle a new TVal into its history ring.
/// `error.StmRetry` (a peer committed after our snapshot) re-runs the whole
/// transaction. (#5-iii: single-ref conflict + retry. Multi-ref needs
/// id-ordered all-locks-before-any-write atomicity — #5-ii.)
fn commit(rt: *Runtime, tx: *LockingTransaction) !void {
    var it = tx.vals.iterator();
    while (it.next()) |entry| {
        const ref = entry.key_ptr.*;
        if (!tx.sets.contains(ref)) continue; // only written refs commit
        const newval = entry.value_ptr.*;
        while (!ref.lock.tryLock()) std.atomic.spinLoopHint();
        defer ref.lock.unlock();
        // Read-point conflict: the ref's latest committed version is newer than
        // our snapshot ⇒ a peer committed after we read ⇒ our write is stale.
        if (ref.tvals.point > tx.read_point) return error.StmRetry;
        const commit_point = nextPoint();
        try spliceCommit(rt, ref, newval, commit_point);
    }
}

/// Write `newval@commit_point` into the ring per the JVM ring-growth rule
/// (`Ref.java`): splice a fresh TVal when history is wanted
/// (`faults>0 && hist<max` — #5-i has no faults yet — OR `hist<min`), else
/// recycle the oldest slot. With cljw's default `min_history==0`, #5-i always
/// recycles (a 1-node ring stays 1-node), so no unbounded ring growth.
fn spliceCommit(rt: *Runtime, ref: *Ref, newval: Value, commit_point: i64) !void {
    const hist_count = ringCount(ref.tvals);
    // faults are #5-iii (retry); treat as 0 here.
    const want_splice = hist_count < ref.min_history;
    if (want_splice) {
        const node = try rt.gc.alloc(TVal);
        node.* = .{
            .header = HeapHeader.init(.tval),
            .val = newval,
            .point = commit_point,
            .prior = ref.tvals,
            .next = ref.tvals.next,
        };
        ref.tvals.next.prior = node;
        ref.tvals.next = node;
        ref.tvals = node;
    } else {
        // Recycle the oldest slot (head.next), advance the head onto it.
        ref.tvals = ref.tvals.next;
        ref.tvals.val = newval;
        ref.tvals.point = commit_point;
    }
}

/// Count the nodes in a Ref's doubly-linked self-loop ring.
fn ringCount(head: *TVal) u32 {
    var n: u32 = 1;
    var t = head.next;
    while (t != head) : (t = t.next) n += 1;
    return n;
}

// --- tests ---

const testing = std.testing;

test "nextPoint is strictly monotonic" {
    const a = nextPoint();
    const b = nextPoint();
    try testing.expect(b > a);
}

test "ringCount on a fresh 1-node ring is 1" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const seed = try tval_mod.allocSelfLoop(&rt, Value.initInteger(0), 0, 0);
    try testing.expectEqual(@as(u32, 1), ringCount(seed));
}

test "doSet caches + doGet reads the in-txn write; commit recycles the ring head" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    const rv = try ref_mod.alloc(&rt, Value.initInteger(0));
    const ref: *Ref = @constCast(rv.decodePtr(*const Ref));

    var tx: LockingTransaction = .{ .read_point = nextPoint(), .gpa = rt.gpa };
    defer tx.vals.deinit(rt.gpa);
    defer tx.sets.deinit(rt.gpa);

    // Before any write, doGet reads the committed value.
    try testing.expectEqual(@as(i64, 0), doGet(&tx, ref).asInteger());
    _ = try doSet(&tx, ref, Value.initInteger(42));
    // The transaction sees its own write.
    try testing.expectEqual(@as(i64, 42), doGet(&tx, ref).asInteger());
    // Not yet committed — the ring head is unchanged.
    try testing.expectEqual(@as(i64, 0), ref.tvals.val.asInteger());

    try commit(&rt, &tx);
    // min_history==0 → recycled in place; the ring stays 1-node with the new value.
    try testing.expectEqual(@as(i64, 42), ref.tvals.val.asInteger());
    try testing.expectEqual(@as(u32, 1), ringCount(ref.tvals));
}
