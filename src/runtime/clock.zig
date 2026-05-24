// SPDX-License-Identifier: EPL-2.0
//! Clock primitives — namespace-neutral implementation per F-009.
//!
//! Two surfaces consume this file:
//!   1. `runtime/java/lang/System.zig` — `(System/currentTimeMillis)` /
//!      `(System/nanoTime)`.
//!   2. (future) `lang/primitive/clock.zig` — when a Clojure-level
//!      wrapper like `(cljw/now)` lands. Today no Clojure peer exists
//!      (Clojure idiomatic time access goes through the Java surface).

const std = @import("std");

/// Milliseconds since the Unix epoch. Mirrors JVM
/// `System.currentTimeMillis()`. Wall clock; subject to NTP jumps.
pub fn currentMillis() i64 {
    return @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_ms));
}

/// Monotonic nanoseconds. Mirrors JVM `System.nanoTime()`. The
/// absolute value is meaningless; only differences are. Unaffected by
/// wall-clock adjustments.
pub fn nanoTime() i64 {
    return @intCast(std.time.nanoTimestamp());
}

// --- tests ---

const testing = std.testing;

test "currentMillis returns a positive epoch milliseconds value" {
    const ms = currentMillis();
    // 2026-05-24 ≈ 1.77e12 ms past the Unix epoch.
    try testing.expect(ms > 1_700_000_000_000);
}

test "nanoTime advances monotonically across two consecutive calls" {
    const t1 = nanoTime();
    const t2 = nanoTime();
    try testing.expect(t2 >= t1);
}
