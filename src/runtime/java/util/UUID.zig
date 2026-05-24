// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.UUID`.
//!
//! Backend: impl-only
//! Impl deps: uuid
//! Clojure peer: clojure.core/random-uuid, clojure.core/parse-uuid
//!
//! Thin wrapper over `runtime/uuid.zig` per F-009. The Clojure-ns
//! peer (`lang/primitive/uuid.zig`) calls the same impl; this file
//! is the entry point for `(java.util.UUID/randomUUID)` and
//! similar Java-style invocations.
//!
//! Phase 6.2 lands declaration + the canonical-string return path.
//! `host_instance` Values (so `(.toString u)` works on a real UUID
//! host instance) need Phase 7 protocol dispatch — until then this
//! surface returns the canonical string directly (matches the
//! Clojure peer's shape).

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

/// `___HOST_EXTENSION` declaration scanned by the Phase-6+ host
/// aggregator. The descriptor is process-lifetime (statically
/// allocated below); the `init` is null because there's no
/// per-Runtime setup beyond descriptor registration.
pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.UUID",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.util.UUID",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
