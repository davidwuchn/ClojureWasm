// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.security.MessageDigest`.
//!
//! Backend: impl-only
//! Impl deps: digest
//! Clojure peer: none
//!
//! TypeDescriptor reservation per ADR-0029 D5 (Phase 14 row 14.3 /
//! D-097 third wave). Backing impl `runtime/crypto/message_digest.zig`
//! (SHA-256 / SHA-1 / MD5 via Zig std.crypto) lands in a focused
//! follow-up cycle — tracked by **D-106**. Until then this surface
//! is reachable through `(rt.types.get "cljw.java.security.MessageDigest")`
//! and the namespace exists, but
//! `(java.security.MessageDigest/getInstance "SHA-256")` raises
//! until method dispatch wires up.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.security.MessageDigest",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.security.MessageDigest",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
