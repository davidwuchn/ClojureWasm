// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.io.File`.
//!
//! Backend: impl-only
//! Impl deps: file_io
//! Clojure peer: clojure.core/slurp, clojure.core/spit
//!
//! D-121 + ADR-0050: declares a one-field layout (`path: string`) so
//! `(java.io.File. path)` flows through the existing deftype
//! `allocInstance` path and produces a `typed_instance` Value the
//! user can pass around. Instance methods (.exists / .length /
//! .getName / .getPath) ride Phase 7+ dispatch on top of
//! `runtime/file_io.zig` — they are not part of D-121's minimum cut
//! (a separate row carries each).
//!
//! field_layout is GPA-allocated via `initFile` per the
//! `_host_api.Extension.init` ownership contract (`Runtime.deinit`
//! frees `td.field_layout` + each entry's `name` via `rt.gpa`).

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

fn initFile(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.field_layout != null) return; // idempotent re-run
    const layout = try gpa.alloc(type_descriptor.TypeDescriptor.FieldEntry, 1);
    layout[0] = .{
        .name = try gpa.dupe(u8, "path"),
        .index = 0,
    };
    td.field_layout = layout;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.io.File",
    .descriptor = &descriptor,
    .init = &initFile,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.io.File",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
