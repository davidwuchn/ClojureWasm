// SPDX-License-Identifier: EPL-2.0
//! `macroexpand-1` / `macroexpand` (D-229). Expand a quoted form's macro head
//! one level (`macroexpand-1`) or repeatedly until the head is no longer a
//! macro (`macroexpand`). Reuses the analyzer's macro-expansion core
//! (`macro_dispatch.expandIfMacro`) by round-tripping the runtime Value form
//! through `valueToForm` → expand → `formToValue`.
//!
//! Backend: impl-only (drives the analyzer's macro expander)
//! Impl deps: none
//! Clojure peer: clojure.core/macroexpand-1, clojure.core/macroexpand

const std = @import("std");
const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const Var = env_mod.Var;
const error_catalog = @import("../../runtime/error/catalog.zig");
const error_mod = @import("../../runtime/error/info.zig");
const SourceLocation = error_mod.SourceLocation;
const dispatch = @import("../../runtime/dispatch.zig");
const analyzer = @import("../../eval/analyzer/analyzer.zig");
const macro_dispatch = @import("../../eval/macro_dispatch.zig");
const form_mod = @import("../../eval/form.zig");
const Form = form_mod.Form;

/// Resolve a head symbol form to its Var (unqualified → current ns mappings +
/// refers; qualified → the named/aliased ns), or null.
fn resolveHead(env: *Env, head: form_mod.SymbolRef) ?*Var {
    if (head.ns) |ns_name| {
        const target = (if (env.current_ns) |here| here.aliases.get(ns_name) else null) orelse
            env.findNs(ns_name) orelse return null;
        return target.resolve(head.name);
    }
    const here = env.current_ns orelse return null;
    return here.resolve(head.name);
}

/// Expand `form` one level if its head is a macro; null if it is not a macro
/// call (or not a list).
fn expandOneLevel(arena: std.mem.Allocator, rt: *Runtime, env: *Env, form: Form, loc: SourceLocation) !?Form {
    if (form.data != .list) return null;
    const items = form.data.list;
    if (items.len == 0 or items[0].data != .symbol) return null;
    const head = items[0].data.symbol;
    const var_ptr = resolveHead(env, head) orelse return null;
    if (!var_ptr.flags.macro_) return null;
    const table: *const macro_dispatch.Table = @ptrCast(@alignCast(rt.macro_table orelse return null));
    return try macro_dispatch.expandIfMacro(arena, rt, env, table, var_ptr, head.name, items[1..], loc);
}

/// `(macroexpand-1 form)` — expand the macro head once; return `form` unchanged
/// when the head is not a macro.
pub fn macroexpand1Fn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("macroexpand-1", args, 1, loc);
    var arena = std.heap.ArenaAllocator.init(rt.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const form = try analyzer.valueToForm(a, rt, env, args[0], loc);
    const expanded = (try expandOneLevel(a, rt, env, form, loc)) orelse return args[0];
    return try analyzer.formToValue(rt, env, expanded);
}

/// `(macroexpand form)` — repeatedly `macroexpand-1` until the head is no longer
/// a macro (clj: does NOT recurse into sub-forms).
pub fn macroexpandFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("macroexpand", args, 1, loc);
    var arena = std.heap.ArenaAllocator.init(rt.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var form = try analyzer.valueToForm(a, rt, env, args[0], loc);
    var changed = false;
    while (try expandOneLevel(a, rt, env, form, loc)) |next| {
        form = next;
        changed = true;
    }
    if (!changed) return args[0];
    return try analyzer.formToValue(rt, env, form);
}

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const ENTRIES = [_]Entry{
    .{ .name = "macroexpand-1", .f = &macroexpand1Fn },
    .{ .name = "macroexpand", .f = &macroexpandFn },
};

pub fn register(env: *Env, rt_ns: *env_mod.Namespace) !void {
    for (ENTRIES) |it| {
        _ = try env.intern(rt_ns, it.name, Value.initBuiltinFn(it.f), null);
    }
}
