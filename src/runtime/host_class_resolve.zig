// SPDX-License-Identifier: EPL-2.0
//! Host-class name resolution over the `rt.types` registry — the ONE
//! place the "what does a class symbol mean" rules live (ADR-0050 §R3
//! java.lang auto-import, D-235 per-ns `(:import …)` map, the
//! BigDecimal/BigInteger java.math default imports). Shared by the
//! analyzer's `resolveJavaSurface` (Class/static resolution, `Class.`
//! constructors) and the completion surface (introspect.zig's class +
//! static-member candidate sources) so the two can never drift: a name
//! completes exactly when it resolves.

const std = @import("std");
const Runtime = @import("runtime.zig").Runtime;
const TypeDescriptor = @import("type_descriptor.zig").TypeDescriptor;
const Namespace = @import("env.zig").Namespace;

/// Resolve `head` (a class symbol's text) to its TypeDescriptor:
///   1. `rt.types.get(head)` — exact key (deftype names, `clojure.lang.*`,
///      an already-`cljw.`-qualified name).
///   2. `rt.types.get("cljw." ++ head)` — the Java prefix translation
///      (`"java.util.UUID"` → `"cljw.java.util.UUID"`).
///   3. For dot-free heads: the per-ns `(:import …)` simple-name map
///      (D-235), then the `java.lang.*` auto-import (ADR-0050 §R3),
///      then the `java.math.BigDecimal`/`BigInteger` default imports.
/// `imports_ns` supplies the `(:import …)` map (null → skip that step).
pub fn resolve(rt: *Runtime, imports_ns: ?*const Namespace, head: []const u8) ?*const TypeDescriptor {
    if (rt.types.get(head)) |td| return td;
    var buf: [256]u8 = undefined;
    const prefixed = std.fmt.bufPrint(&buf, "cljw.{s}", .{head}) catch return null;
    if (rt.types.get(prefixed)) |td| return td;
    if (std.mem.findScalar(u8, head, '.') == null) {
        if (imports_ns) |ns| {
            if (ns.imports.get(head)) |fqcn| {
                if (rt.types.get(fqcn)) |td| return td;
                var ibuf: [256]u8 = undefined;
                const iprefixed = std.fmt.bufPrint(&ibuf, "cljw.{s}", .{fqcn}) catch return null;
                if (rt.types.get(iprefixed)) |td| return td;
            }
        }
        var buf2: [256]u8 = undefined;
        const auto = std.fmt.bufPrint(&buf2, "cljw.java.lang.{s}", .{head}) catch return null;
        if (rt.types.get(auto)) |td| return td;
        if (std.mem.eql(u8, head, "BigDecimal") or std.mem.eql(u8, head, "BigInteger")) {
            var buf3: [256]u8 = undefined;
            const m = std.fmt.bufPrint(&buf3, "cljw.java.math.{s}", .{head}) catch return null;
            if (rt.types.get(m)) |td| return td;
        }
    }
    return null;
}

/// The JVM-visible spelling of a registry key: `cljw.java.lang.Character`
/// reads `java.lang.Character` (the `cljw.` implementation prefix is not
/// part of the user-facing class name); every other key is itself.
pub fn displayName(key: []const u8) []const u8 {
    if (std.mem.startsWith(u8, key, "cljw.java.")) return key["cljw.".len..];
    return key;
}

/// Whether the registry key is reachable as a BARE simple name from
/// `imports_ns` — the java.lang.* / java.math default imports, or a
/// per-ns `(:import …)` entry. Returns the simple name when it is.
pub fn bareName(imports_ns: ?*const Namespace, key: []const u8) ?[]const u8 {
    const simple = if (std.mem.findScalarLast(u8, key, '.')) |dot| key[dot + 1 ..] else key;
    if (std.mem.startsWith(u8, key, "cljw.java.lang.")) return simple;
    if (std.mem.startsWith(u8, key, "cljw.java.math.Big")) return simple;
    if (imports_ns) |ns| {
        if (ns.imports.get(simple)) |fqcn| {
            const display = displayName(key);
            if (std.mem.eql(u8, fqcn, display) or std.mem.eql(u8, fqcn, key)) return simple;
        }
    }
    return null;
}

test "displayName strips only the cljw.java prefix" {
    try std.testing.expectEqualStrings("java.lang.Character", displayName("cljw.java.lang.Character"));
    try std.testing.expectEqualStrings("clojure.lang.PersistentQueue", displayName("clojure.lang.PersistentQueue"));
    try std.testing.expectEqualStrings("cljw.http.server", displayName("cljw.http.server"));
}
