// SPDX-License-Identifier: EPL-2.0
//! Env-gated coarse startup profiler (`CLJW_PROFILE_STARTUP=1`). Off by
//! default — when the env is unset every method is a single null-check
//! branch and no clock is read, so the cold-start hot path is unchanged.
//! When set, each `mark` prints the delta since the previous mark to
//! stderr, so the ~10 ms cold floor (gap-III perf campaign, D-450 / D-140)
//! can be attributed phase-by-phase without an external sampler (a
//! short-lived process is invisible to `sample`).
//!
//! Lives in `runtime/` (Layer 0) so both `lang/bootstrap.zig` (Layer 2)
//! and `app/runner.zig` (Layer 3) can construct a profiler without an
//! upward import.

const std = @import("std");
const clock = @import("clock.zig");
const process_env = @import("process_env.zig");

pub const Profiler = struct {
    io: std.Io,
    enabled: bool,
    last: i64,

    /// Construct a profiler. Reads `CLJW_PROFILE_STARTUP` once (the env is
    /// published before any startup path runs). When unset, `enabled` is
    /// false and no clock is read here or in `mark`.
    pub fn start(io: std.Io) Profiler {
        const on = process_env.get("CLJW_PROFILE_STARTUP") != null;
        return .{ .io = io, .enabled = on, .last = if (on) clock.nanoTime(io) else 0 };
    }

    /// Print microseconds elapsed since the previous mark (or `start`),
    /// then reset the baseline. No-op when disabled.
    pub fn mark(self: *Profiler, label: []const u8) void {
        if (!self.enabled) return;
        const now = clock.nanoTime(self.io);
        const us = @divTrunc(now - self.last, 1000);
        std.debug.print("[startup] {s}: {d} us\n", .{ label, us });
        self.last = now;
    }
};
