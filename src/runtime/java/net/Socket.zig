// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.net.Socket`.
//!
//! Backend: impl-only
//! Impl deps: net
//! Clojure peer: none
//!
//! TypeDescriptor reservation per ADR-0029 D5 (Phase 14 row 14.3 /
//! D-097 third wave). Backing impl `runtime/net/socket.zig`
//! (TCP client / server primitives) lands in a focused follow-up
//! cycle — tracked by **D-106**. Until then this surface is
//! reachable through `(rt.types.get "cljw.java.net.Socket")` and the
//! `cljw.java.net.Socket` namespace exists, but
//! `(java.net.Socket. host port)` raises until method dispatch
//! wires up.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.net.Socket",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.net.Socket",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
