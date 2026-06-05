// SPDX-License-Identifier: EPL-2.0
//! GC torture mode (D-250): force a stop-the-world collect at every Nth VM
//! back-edge safe point so a missing root surfaces DETERMINISTICALLY (a UAF on
//! the very next collect) instead of as a rare, path-dependent crash.
//!
//! This is a TEST/VALIDATION mode, NOT production auto-collection. It is armed
//! only by the `CLJW_GC_TORTURE` env var (read once at CLI startup) and stays
//! fully inert otherwise — `period == 0` is a single global load + a predicted-
//! not-taken branch on the VM's hottest path. Production threshold-driven
//! auto-collect remains gated (D-244 #4); a test-mode forced collect at a clean
//! safe point is explicitly distinct from that flip.
//!
//! Two-stage arming so torture validates STEADY-STATE user code, not core
//! bootstrap: `configure(n)` (CLI startup) records the requested period but
//! leaves the mode inert; `arm()` (called once AFTER `setupCoreAot`) activates
//! it. Core bootstrap (AOT restore + lib loading) has its own
//! namespace-creation-window concern tracked separately as D-251 — collecting
//! mid-bootstrap is out of #4a' scope, so torture deliberately skips it.
//!
//! Validation scope: the back-edge poll fires BETWEEN bytecode steps, so a
//! torture collect catches gaps in the poll-boundary root set (operand stack,
//! locals, binding frames, ns vars, macro slot, permanent roots). It does NOT
//! exercise the mid-op fabrication window (`gc_self_guard`), which is only a
//! hazard when ANOTHER thread collects while this thread is parked mid-alloc —
//! that needs the alloc-driven multi-thread torture that rides the #4 wiring.

const std = @import("std");

/// Requested period from `CLJW_GC_TORTURE` (0 = unset). Held inert until
/// `arm()` copies it into `period` post-bootstrap.
var pending_period: u32 = 0;

/// Active collect cadence: collect every `period` back-edge polls. `0` =
/// disarmed (the default, and the state during bootstrap before `arm()`).
/// Process-wide single-writer (CLI startup + `arm()`, both before any user
/// eval), then read-only, so a plain global is sufficient (no atomics).
pub var period: u32 = 0;

/// Per-thread poll counter. Threadlocal so each worker's cadence is
/// independent and the count needs no synchronisation.
threadlocal var counter: u32 = 0;

/// Record the requested torture period from the parsed `CLJW_GC_TORTURE`
/// value. Does NOT activate — `arm()` does, post-bootstrap. `n == 0` is a
/// no-op (mode stays off).
pub fn configure(n: u32) void {
    pending_period = n;
}

/// Activate torture mode (called once after core bootstrap completes) by
/// promoting the requested period. Inert if `configure` was never called with
/// a positive value.
pub fn arm() void {
    period = pending_period;
}

/// Advance the per-thread poll counter; return true on every `period`-th call
/// (so the VM should run a torture collect). Always false when disarmed —
/// `period == 0` short-circuits so a direct call is safe even off the hot
/// path (the VM still guards with `if (period != 0)` to skip the increment).
pub fn tick() bool {
    if (period == 0) return false;
    counter += 1;
    if (counter >= period) {
        counter = 0;
        return true;
    }
    return false;
}

const testing = std.testing;

fn reset() void {
    pending_period = 0;
    period = 0;
    counter = 0;
}

test "tick is always false when disarmed (period == 0)" {
    reset();
    for (0..100) |_| try testing.expect(!tick());
}

test "configure alone does not activate; arm() promotes it" {
    reset();
    configure(2);
    try testing.expect(!tick()); // still inert before arm()
    try testing.expect(!tick());
    arm();
    try testing.expect(!tick()); // call 1 after arm
    try testing.expect(tick()); // call 2 -> fire
    reset();
}

test "tick fires every period-th call when armed" {
    reset();
    configure(3);
    arm();
    try testing.expect(!tick());
    try testing.expect(!tick());
    try testing.expect(tick());
    try testing.expect(!tick());
    try testing.expect(!tick());
    try testing.expect(tick());
    reset();
}

test "period == 1 fires on every call" {
    reset();
    configure(1);
    arm();
    for (0..10) |_| try testing.expect(tick());
    reset();
}
