// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.Thread` static methods (Phase B).
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: none
//!
//! First slice: `(Thread/sleep millis)` blocks the calling thread for `millis`
//! milliseconds via `io_default.sleep` (`std.Thread.sleep` is gone in Zig 0.16
//! — sleep routes through the io). Thread objects / start / interrupt /
//! currentThread are later slices; cljw concurrency is `future`/`agent`/STM, not
//! raw Threads, so `Thread/sleep` (timing in tests / polling demos) is the
//! high-value static to land first.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const io_default = @import("../../concurrency/io_default.zig");

/// Implements `(Thread/sleep millis)` — block the calling thread for `millis`
/// milliseconds, return nil. JVM reference: java.lang.Thread#sleep(long). A
/// non-positive `millis` is a no-op (JVM throws on negative — cljw treats <= 0
/// as "do not sleep", the only difference being the pathological negative case).
fn sleep(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Thread/sleep", args, 1, loc);
    const ms = try error_catalog.expectInteger(args[0], "Thread/sleep", loc);
    if (ms > 0) {
        io_default.sleep(@as(u64, @intCast(ms)) * std.time.ns_per_ms);
    }
    return Value.nil_val;
}

fn initThread(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const specs = .{
        .{ "sleep", &sleep },
    };
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.lang.Thread",
    .descriptor = &descriptor,
    .init = &initThread,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.Thread",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .static_fields = &.{},
    .parent = null,
    .meta = .nil_val,
};
