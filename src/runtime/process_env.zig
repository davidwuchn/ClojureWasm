// SPDX-License-Identifier: EPL-2.0
//! Process environment access for the runtime surface (`System/getenv`, and any
//! future env-reading host fn). Juicy Main owns the `EnvMap` (`init.environ_map`);
//! `cli.zig` publishes a borrowed pointer here once at startup.
//!
//! The OS environment is process-global read-only config — every Runtime in the
//! process observes the same env — so a module-level pointer is the correct shape
//! (not per-Runtime mutable state; F-006 governs runtime STATE, and this is
//! startup config, like `gc_torture.pending_period` / `error_render.logFilePath`).
//! The pointed-to `EnvMap` lives for the whole process (owned by `init`), so the
//! borrow never dangles.
const std = @import("std");

const EnvMap = std.process.Environ.Map;

var environ: ?*const EnvMap = null;

/// Publish the process env map (called once from `cli.zig` with
/// `init.environ_map`, which is already a `*Environ.Map`). Idempotent.
pub fn publish(map: *const EnvMap) void {
    environ = map;
}

/// The value of `key`, or null if unset (or env not yet published — e.g. a unit
/// test that never called `publish`).
pub fn get(key: []const u8) ?[]const u8 {
    return if (environ) |m| m.get(key) else null;
}

/// The whole published env map, or null before `publish` — the 0-arg
/// `(System/getenv)` surface iterates it (ADR-0174 D5).
pub fn all() ?*const EnvMap {
    return environ;
}

// --- tests ---

const testing = std.testing;

test "get returns null before publish, and the mapped value after" {
    environ = null; // isolate from any prior publish in the test process
    try testing.expect(get("CLJW_PROCESS_ENV_TEST_KEY") == null);

    var map = EnvMap.init(testing.allocator);
    defer map.deinit();
    try map.put("CLJW_PROCESS_ENV_TEST_KEY", "hello");
    publish(&map);
    try testing.expectEqualStrings("hello", get("CLJW_PROCESS_ENV_TEST_KEY").?);
    try testing.expect(get("CLJW_PROCESS_ENV_MISSING") == null);

    environ = null; // do not leak a dangling pointer to the freed map
}
