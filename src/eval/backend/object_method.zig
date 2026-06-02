// SPDX-License-Identifier: EPL-2.0
//! Universal `java.lang.Object` instance-method fallback (D-207 / clj-parity
//! C3, ADR-0076 §9.2.P). `.toString` / `.equals` / `.hashCode` / `.getClass`
//! apply to EVERY value, so they cannot be per-class method-table entries —
//! they are a DISPATCH-LEVEL fallback both backends consult after a
//! method-table miss, delegating to the cljw native equivalents
//! (`str` / `=` / `hash` / `class`). Shared by `tree_walk` + `vm` so the
//! parity is one source (ADR-0036). Layer 1: imports `runtime/` only.

const std = @import("std");
const value_mod = @import("../../runtime/value/value.zig");
const Value = value_mod.Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const Env = @import("../../runtime/env.zig").Env;
const equal = @import("../../runtime/equal.zig");
const print_mod = @import("../../runtime/print.zig");
const string_mod = @import("../../runtime/collection/string.zig");
const td_mod = @import("../../runtime/type_descriptor.zig");

/// If `name` is a universal `java.lang.Object` instance method at the right
/// arity, return its result delegating to the cljw native equivalent;
/// otherwise `null` so the caller raises its original "no method" error.
/// `td` is the receiver's already-resolved descriptor; `args` EXCLUDES the
/// receiver.
///
/// - `.toString` → `str` (single source `print.writeStrValue`; clj-MATCHES).
/// - `.equals`   → `=` (`valueEqual`; clj-MATCHES incl. cross-type seq).
/// - `.hashCode` → `hash` (`valueHash`; VALUE diverges from JVM — AD-009).
/// - `.getClass` → `class` (the descriptor ref; prints the simple name per
///   AD-003).
///
/// nil receiver → `null`: clj throws on a method call on nil; raising the
/// caller's error (format differs per F-011) is closer than a silent value.
pub fn tryObjectMethod(
    rt: *Runtime,
    env: *Env,
    receiver: Value,
    td: *const td_mod.TypeDescriptor,
    name: []const u8,
    args: []const Value,
) !?Value {
    if (receiver.tag() == .nil) return null;
    if (args.len == 0 and std.mem.eql(u8, name, "toString")) {
        var aw: std.Io.Writer.Allocating = .init(rt.gpa);
        defer aw.deinit();
        try print_mod.writeStrValue(rt, env, &aw.writer, receiver);
        return try string_mod.alloc(rt, aw.writer.buffered());
    }
    if (args.len == 0 and std.mem.eql(u8, name, "hashCode")) {
        return Value.initInteger(@as(i32, @bitCast(equal.valueHash(receiver))));
    }
    if (args.len == 1 and std.mem.eql(u8, name, "equals")) {
        return Value.initBoolean(try equal.valueEqual(rt, env, receiver, args[0]));
    }
    if (args.len == 0 and std.mem.eql(u8, name, "getClass")) {
        return try td_mod.makeTypeDescriptorRef(rt, td);
    }
    return null;
}
