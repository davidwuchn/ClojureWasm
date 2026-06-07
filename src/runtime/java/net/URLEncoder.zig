// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.net.URLEncoder` — static `encode` only (no instances).
//! Landed alongside java.net.URI to unblock hiccup (`hiccup.util/url-encode`).
//!
//! Backend: impl-only
//! Impl deps: url_encode
//! Clojure peer: none.
//!
//! `(java.net.URLEncoder/encode s enc)` percent-encodes `s` per
//! `application/x-www-form-urlencoded` (runtime/net/url_encode.zig). The charset
//! arg is required (clj signature) and validated as a string, but cljw only
//! supports UTF-8 so its value is otherwise unused.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const string_collection = @import("../../collection/string.zig");
const url_encode = @import("../../net/url_encode.zig");

fn encode(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("java.net.URLEncoder/encode", args, 2, loc);
    if (args[0].tag() != .string)
        return error_catalog.raise(.type_arg_not_string, loc, .{ .fn_name = "java.net.URLEncoder/encode", .actual = @tagName(args[0].tag()) });
    if (args[1].tag() != .string)
        return error_catalog.raise(.type_arg_not_string, loc, .{ .fn_name = "java.net.URLEncoder/encode", .actual = @tagName(args[1].tag()) });
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(rt.gpa);
    try url_encode.encode(rt.gpa, &out, string_collection.asString(args[0]));
    return string_collection.alloc(rt, out.items);
}

fn initUrlEncoder(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, 1);
    entries[0] = .{
        .protocol_name = "",
        .method_name = try gpa.dupe(u8, "encode"),
        .method_val = Value.initBuiltinFn(&encode),
    };
    td.method_table = entries;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.net.URLEncoder",
    .descriptor = &descriptor,
    .init = &initUrlEncoder,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "java.net.URLEncoder",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
