// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.System`.
//!
//! Backend: impl-only
//! Impl deps: clock
//! Clojure peer: none
//!
//! Thin wrapper over `runtime/clock.zig` per F-009. Static methods
//! `currentTimeMillis` and `nanoTime` map to `clock.currentMillis` /
//! `clock.nanoTime`. JVM Clojure code reaches these via
//! `(System/currentTimeMillis)` / `(System/nanoTime)`; cw v1 enforces
//! the FQCN form `(java.lang.System/...)` for v0.1.0 (bare-class
//! aliases are Phase 14+ ergonomic).
//!
//! D-121 + ADR-0050: populates `method_table` for `currentTimeMillis`
//! and `nanoTime`. Dispatched via `InteropCallNode { .kind =
//! .static_method }`. Runtime init per UUID.zig rationale.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const clock = @import("../../clock.zig");

/// Implements `(java.lang.System/currentTimeMillis)`.
/// Spec: returns the current epoch milliseconds as a long.
/// JVM reference: java.lang.System#currentTimeMillis.
/// cw v1 tier: A (Phase 14 / D-121).
fn currentTimeMillis(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("java.lang.System/currentTimeMillis", args, 0, loc);
    return Value.initInteger(clock.currentMillis(rt.io));
}

/// Implements `(java.lang.System/nanoTime)`.
/// Spec: returns a monotonic nanosecond counter as a long. The
/// absolute value has no meaning; only differences are meaningful.
/// JVM reference: java.lang.System#nanoTime.
/// cw v1 tier: A (Phase 14 / D-121).
fn nanoTime(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("java.lang.System/nanoTime", args, 0, loc);
    return Value.initInteger(clock.nanoTime(rt.io));
}

const std = @import("std");

fn initSystem(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, 2);
    entries[0] = .{
        .protocol_name = "",
        .method_name = try gpa.dupe(u8, "currentTimeMillis"),
        .method_val = Value.initBuiltinFn(&currentTimeMillis),
    };
    entries[1] = .{
        .protocol_name = "",
        .method_name = try gpa.dupe(u8, "nanoTime"),
        .method_val = Value.initBuiltinFn(&nanoTime),
    };
    td.method_table = entries;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.lang.System",
    .descriptor = &descriptor,
    .init = &initSystem,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.System",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
