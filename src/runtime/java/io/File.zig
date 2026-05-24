// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.io.File`.
//!
//! Backend: impl-only
//! Impl deps: file_io
//! Clojure peer: clojure.core/slurp, clojure.core/spit
//!
//! Phase 6.8 lands the `___HOST_EXTENSION` declaration. Instance
//! methods (.exists, .length, .getName, .getPath) wire through
//! Phase 7 dispatch on top of `runtime/file_io.zig`.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.io.File",
    .descriptor = &descriptor,
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
