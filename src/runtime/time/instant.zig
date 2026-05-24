// SPDX-License-Identifier: EPL-2.0
//! `java.time.Instant` namespace-neutral implementation per F-009.
//!
//! Two surfaces consume this file:
//!   1. `runtime/java/time/Instant.zig` — Java 8+ canonical
//!      time class (`(java.time.Instant/now)` /
//!      `(.toEpochMilli inst)`).
//!   2. `runtime/java/util/Date.zig` — legacy `java.util.Date`,
//!      which internally tracks epoch-millis the same way.
//!
//! No Clojure peer at this layer; clojure.instant has its own
//! parser and lives in `lang/clj/clojure/instant.clj`.

const std = @import("std");
const clock = @import("../clock.zig");

/// Epoch-millis at the moment of the call. Wall clock. Identical
/// numeric value to `(System/currentTimeMillis)`; the Instant
/// abstraction layers on top of the same nanosecond source.
pub fn nowEpochMillis() i64 {
    return clock.currentMillis();
}

/// Epoch-nanos at the moment of the call. Wall clock too — NOT
/// `clock.nanoTime` (which is monotonic-only without an epoch
/// alignment). For sub-millisecond JVM-Instant compatibility use
/// this; for elapsed-time measurements use `clock.nanoTime`.
pub fn nowEpochNanos() i128 {
    return std.time.nanoTimestamp();
}

// --- tests ---

const testing = std.testing;

test "nowEpochMillis returns a sensible 2026-era epoch ms" {
    const ms = nowEpochMillis();
    try testing.expect(ms > 1_700_000_000_000);
}

test "nowEpochNanos is consistent with nowEpochMillis within a 100ms window" {
    const ms = nowEpochMillis();
    const ns = nowEpochNanos();
    const ns_to_ms: i128 = @divTrunc(ns, std.time.ns_per_ms);
    const diff = if (ns_to_ms >= ms) ns_to_ms - ms else ms - ns_to_ms;
    try testing.expect(diff < 100);
}
