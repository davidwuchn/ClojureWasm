// SPDX-License-Identifier: EPL-2.0
//! Thread-local dynamic-binding stack (ROADMAP §9.6 / 4.22).
//!
//! Clojure's `(binding [*x* 1] body)` creates per-thread bindings that
//! `Var.deref` consults before falling back to the root. The
//! infrastructure exists in `env.zig` (BindingFrame / current_frame /
//! pushFrame / popFrame / findBinding) and is consulted via
//! `Var.deref` on dynamic Vars; this file re-exports the contract
//! under the names ROADMAP §9.6 row 4.22 prescribes so external
//! callers (REPL, primitive `binding`, future thread-spawn
//! inheritance per Phase 14-15) have a single seam to import.

const env_mod = @import("env.zig");
const Value = @import("value.zig").Value;

/// One `(binding [...])` frame. Aliases the existing struct so
/// existing call sites and tests continue to work without rename.
pub const DvalFrame = env_mod.BindingFrame;

/// Top of the current thread's dynamic-binding chain. `null` when
/// no `(binding ...)` is active.
pub inline fn topFrame() ?*DvalFrame {
    return env_mod.current_frame;
}

/// Push a frame at `binding` entry. Pair with `popBindings`,
/// typically via `defer` at the call site.
pub inline fn pushBindings(frame: *DvalFrame) void {
    env_mod.pushFrame(frame);
}

/// Pop the innermost frame. No-op when no frame is active.
pub inline fn popBindings() void {
    env_mod.popFrame();
}

/// Walk the dynamic-binding chain looking for a value bound for
/// `v`. Returns `null` when none is set (caller falls back to
/// `Var.root`).
pub inline fn findBinding(v: *const env_mod.Var) ?Value {
    return env_mod.findBinding(v);
}

/// Resolve a Var to its currently-active Value — dynamic binding
/// first (when `v.flags.dynamic`), root otherwise. Thin alias over
/// `Var.deref`; included here so consumer code can import the whole
/// dynamic-binding surface from one file.
pub inline fn varDeref(v: *const env_mod.Var) Value {
    return v.deref();
}

// --- tests ---

const std = @import("std");
const testing = std.testing;
const Runtime = @import("runtime.zig").Runtime;
const Env = env_mod.Env;

test "binding_stack: push then pop restores prior top" {
    try testing.expect(topFrame() == null);
    var f: DvalFrame = .{};
    pushBindings(&f);
    try testing.expect(topFrame() == &f);
    popBindings();
    try testing.expect(topFrame() == null);
}

test "binding_stack: varDeref returns root when no frame is active" {
    var threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    var rt = Runtime.init(threaded.io(), testing.allocator);
    defer rt.deinit();
    var env = try Env.init(&rt);
    defer env.deinit();

    const ns = env.current_ns.?;
    const v_ptr = try env.intern(ns, "x", Value.true_val);
    try testing.expectEqual(Value.true_val, varDeref(v_ptr));
}
