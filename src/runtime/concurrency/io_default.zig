// SPDX-License-Identifier: EPL-2.0
//! Process-wide default `std.Io` accessor for call sites that hold no `io`.
//!
//! Phase B concurrency (ADR-0090). Pinned Zig 0.16 moved the sync primitives
//! off `std.Thread.{Mutex,Condition}` onto `std.Io.Mutex` / `Io.Condition`,
//! whose `lock`/`wait` take an `io` argument. The `Runtime` carries `rt.io`
//! (runtime.zig), so call sites that have `rt` use that directly. But two
//! classes of call site have NO `io` in hand:
//!
//!   1. `std.mem.Allocator.VTable` callbacks — the GC allocator's alloc/free
//!      run behind the vtable, which cannot take an `io` arg (the global heap
//!      lock that makes allocation thread-safe under F-006 must reach `io`
//!      from here).
//!   2. process-/module-level mutexes (interned keywords, namespaces, hooks)
//!      that lock before any `rt` exists.
//!
//! This module is the single shared `std.Io` those sites reach. It defaults
//! lazily to a single-threaded io (tests + pre-init), and production entry
//! points (`runner`/`main`) call `set(rt.io)` early to upgrade it to the
//! real threaded io. Re-derived cljw-clean from cw v0's `io_default.zig`
//! (no_copy_from_v1: reference, not copy); cljw keeps only the sync-primitive
//! surface here (env/time helpers, if needed, live with their own concerns).

const std = @import("std");

var single_threaded: std.Io.Threaded = .init_single_threaded;
var current_io: std.Io = undefined;
var initialized: bool = false;

/// The process-wide default io. Lazily initialises to a single-threaded io on
/// first use so tests and pre-init callers need not call `set()` first.
pub fn get() std.Io {
    if (!initialized) {
        current_io = single_threaded.io();
        initialized = true;
    }
    return current_io;
}

/// Upgrade the default io to the production (threaded) one. `runner`/`main`
/// call this with `rt.io` early so vtable + module-level locks pick it up.
pub fn set(io: std.Io) void {
    current_io = io;
    initialized = true;
}

// Convenience wrappers mirroring the deleted std.Thread.{Mutex,Condition}
// shape, so a no-io call site keeps the old `lock(&m)` ergonomics. Uncancelable
// (these back internal invariants, not user-cancelable operations).

/// Lock via the default io. Uncancelable — matches the old `Mutex.lock()` shape.
pub fn lockMutex(m: *std.Io.Mutex) void {
    m.lockUncancelable(get());
}

pub fn unlockMutex(m: *std.Io.Mutex) void {
    m.unlock(get());
}

/// `std.Io.Condition.wait`, uncancelable, on the default io.
pub fn condWait(cond: *std.Io.Condition, mutex: *std.Io.Mutex) void {
    cond.waitUncancelable(get(), mutex);
}

pub fn condSignal(cond: *std.Io.Condition) void {
    cond.signal(get());
}

pub fn condBroadcast(cond: *std.Io.Condition) void {
    cond.broadcast(get());
}

/// Sleep `ns` nanoseconds on the default io. Replaces `std.Thread.sleep`.
pub fn sleep(ns: u64) void {
    std.Io.sleep(get(), .fromNanoseconds(@intCast(ns)), .awake) catch {};
}

// ---------------------------------------------------------------------------

const testing = std.testing;

test "get() lazily initialises a usable io" {
    // First call must not panic and must return a stable value.
    const a = get();
    const b = get();
    try testing.expect(a.userdata == b.userdata);
}

test "lockMutex/unlockMutex round-trip via the default singleton" {
    var m: std.Io.Mutex = .init;
    lockMutex(&m);
    // While held, a tryLock must fail.
    try testing.expect(!m.tryLock());
    unlockMutex(&m);
    // After unlock, a fresh tryLock must succeed; release it again.
    try testing.expect(m.tryLock());
    unlockMutex(&m);
}

test "condSignal/condBroadcast on an unwaited condition are no-ops (no waiters)" {
    var cond: std.Io.Condition = .init;
    // No waiters: signalling must be safe and not block.
    condSignal(&cond);
    condBroadcast(&cond);
}
