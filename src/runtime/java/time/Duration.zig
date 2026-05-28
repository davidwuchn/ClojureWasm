// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.time.Duration`.
//!
//! Backend: impl-only
//! Impl deps: time
//! Clojure peer: none
//!
//! TypeDescriptor reservation per ADR-0029 D5 (Phase 14 row 14.2 /
//! D-097). Interval semantics (between / plus / minus / toMillis /
//! toNanos) over `runtime/time/instant.zig` land in a focused
//! follow-up cycle — tracked by **D-105**.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.time.Duration",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.time.Duration",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
