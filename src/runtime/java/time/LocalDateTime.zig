// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.time.LocalDateTime`.
//!
//! Backend: impl-only
//! Impl deps: time
//! Clojure peer: none
//!
//! TypeDescriptor reservation per ADR-0029 D5. The backing impl
//! `runtime/time/local_date_time.zig` (timezone-agnostic date+time
//! over `runtime/time/instant.zig`) is unbuilt, alongside Duration /
//! ZonedDateTime — tracked by **D-105**. The surface is reachable
//! through `(rt.types.get "cljw.java.time.LocalDateTime")` and the
//! `cljw.java.time.LocalDateTime` namespace exists, but the
//! method_table is empty, so `(java.time.LocalDateTime/now)` does
//! not yet resolve.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.time.LocalDateTime",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.time.LocalDateTime",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
