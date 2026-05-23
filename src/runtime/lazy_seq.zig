// SPDX-License-Identifier: EPL-2.0
//! Lazy sequence struct skeleton (ROADMAP §9.6 / 4.24).
//!
//! Phase 4 entry declares the data shape only. `force()` lands at
//! Phase 5 per ADR-0009 (heap-only lock activation) + the
//! trampoline pattern that drives thunk evaluation without growing
//! the call stack on long chains.
//!
//! `seq_cache` is an `atomic.Value(?*Seq)` so the first `force()`
//! publishes the realised cons cell with release semantics and
//! readers see the result without taking the lock. `lock` guards
//! the thunk-evaluation path so two threads racing the first
//! `force()` collapse to one evaluation.

const std = @import("std");
const HeapHeader = @import("value.zig").HeapHeader;
const Value = @import("value.zig").Value;

/// Forward declaration — the realised cons cell type lives in
/// `runtime/collection/cons.zig` (or its Phase-5 replacement). We
/// don't import it here to avoid an upward zone reach; the
/// pointer is read via `@ptrCast` at the consumer.
const SeqOpaque = anyopaque;

/// One lazy-sequence object. Backs `(lazy-seq …)` / `(map …)` /
/// `(iterate …)` style constructs that don't realise their elements
/// until `seq` / `first` / `rest` walks them.
pub const LazySeq = struct {
    header: HeapHeader,
    /// Thunk function pointer. Called by `force()` on first access;
    /// produces the next cons cell (or `null` for end-of-seq).
    /// `ctx` is the user-supplied closure environment.
    thunk: *const fn (ctx: *anyopaque) anyerror!?*SeqOpaque,
    ctx: *anyopaque,
    /// Realised value cache. Read with acquire semantics; published
    /// once with release semantics by the winning force() call.
    seq_cache: std.atomic.Value(?*SeqOpaque),
    /// First-force guard. `std.atomic.Mutex` is the lock-free
    /// `tryLock` / `unlock` shape that fits Phase 5's
    /// double-checked-locking pattern; Phase 4 just reserves the
    /// slot. A blocking variant (`std.Io.Mutex`) lands later if the
    /// bench harness shows contention warrants it.
    lock: std.atomic.Mutex,

    pub fn initShape(
        header: HeapHeader,
        thunk_fn: *const fn (ctx: *anyopaque) anyerror!?*SeqOpaque,
        ctx_ptr: *anyopaque,
    ) LazySeq {
        return .{
            .header = header,
            .thunk = thunk_fn,
            .ctx = ctx_ptr,
            .seq_cache = .init(null),
            .lock = .unlocked,
        };
    }
};

// --- tests ---

const testing = std.testing;

fn dummyThunk(ctx: *anyopaque) anyerror!?*SeqOpaque {
    _ = ctx;
    return null;
}

test "LazySeq struct shape: header + thunk + ctx + cache + lock" {
    var ctx_storage: u64 = 0;
    const hdr: HeapHeader = .{
        .tag = @intFromEnum(@import("value.zig").HeapTag.lazy_seq),
        .flags = .{},
    };
    var ls: LazySeq = .initShape(hdr, &dummyThunk, &ctx_storage);
    try testing.expectEqual(@as(u8, @intFromEnum(@import("value.zig").HeapTag.lazy_seq)), ls.header.tag);
    try testing.expect(ls.seq_cache.load(.acquire) == null);
}
