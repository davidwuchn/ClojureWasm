// SPDX-License-Identifier: EPL-2.0
//! `locking` primitive — Clojure-ns surface for `(locking obj body...)`.
//!
//! The `locking` macro (lang/macro_transforms.zig) expands to
//! `(__locking obj (fn* [] body...))`; this primitive holds obj's heap-value
//! monitor (runtime/concurrency/object_monitor.zig — ADR-0009 lock_state bits,
//! NOT a JVM monitor) while it calls the body thunk on the calling thread,
//! releasing on normal OR error exit (defer). Reentrant.

const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const error_mod = @import("../../runtime/error/info.zig");
const error_catalog = @import("../../runtime/error/catalog.zig");
const SourceLocation = error_mod.SourceLocation;
const dispatch = @import("../../runtime/dispatch.zig");
const object_monitor = @import("../../runtime/concurrency/object_monitor.zig");

/// `(__locking obj thunk)` — acquire obj's heap-value monitor, call `(thunk)`,
/// release. An immediate (no `HeapHeader`, hence no identity) cannot be locked.
pub fn lockingFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("locking", args, 2, loc);
    const hdr = args[0].heapHeader() orelse
        return error_catalog.raise(.locking_needs_object, loc, .{});
    object_monitor.enter(hdr) catch
        return error_catalog.raise(.locking_nest_overflow, loc, .{ .cap = object_monitor.HELD_CAP });
    defer object_monitor.exit(hdr);
    const vtable = rt.vtable orelse return error.InternalError;
    return vtable.callFn(rt, env, args[1], &.{}, loc);
}

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const ENTRIES = [_]Entry{
    .{ .name = "__locking", .f = &lockingFn },
};

pub fn register(env: *Env, rt_ns: *env_mod.Namespace) !void {
    for (ENTRIES) |it| {
        _ = try env.intern(rt_ns, it.name, Value.initBuiltinFn(it.f), null);
    }
}
