// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.Locale` — the `Locale/US` / `Locale/ROOT`
//! static-field singletons + `.toString`. Landed to unblock honeysql, which
//! does `(.toUpperCase s java.util.Locale/US)` to force locale-independent
//! casing. cljw casing is ALREADY locale-independent (ADR-0050 am1), so the
//! Locale value is opaque — it only needs to EXIST + be passable to
//! `String.toUpperCase`/`toLowerCase` (which accept + ignore it).
//!
//! Backend: impl-only
//! Impl deps: locale
//! Clojure peer: none.
//!
//! The singletons + rt-slot caching live in the neutral `runtime/locale.zig`
//! (so `Runtime.deinit` + the analyzer reach them without importing this surface
//! tree, per the zone rule). This file owns the descriptor + static-field table.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const host_instance = @import("../../host_instance.zig");
const string_collection = @import("../../collection/string.zig");
const locale = @import("../../locale.zig");

/// `(str loc)` / `(.toString loc)` — the locale tag ("en_US" / "" for ROOT).
fn toString(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("toString", args, 1, loc);
    const which: locale.Which = @enumFromInt(host_instance.asHostInstance(args[0]).state[0]);
    return string_collection.alloc(rt, locale.tagString(which));
}

fn initLocaleDescriptor(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, 1);
    entries[0] = .{ .protocol_name = "", .method_name = try gpa.dupe(u8, "toString"), .method_val = Value.initBuiltinFn(&toString) };
    td.method_table = entries;
}

const static_fields = [_]type_descriptor.TypeDescriptor.StaticField{
    .{ .name = "US", .value = .{ .singleton = .locale_us } },
    .{ .name = "ROOT", .value = .{ .singleton = .locale_root } },
};

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.Locale",
    .descriptor = &descriptor,
    .init = &initLocaleDescriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "java.util.Locale",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .static_fields = &static_fields,
    .parent = null,
    .meta = .nil_val,
};
