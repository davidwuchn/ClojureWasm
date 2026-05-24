// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.System`.
//!
//! Backend: impl-only
//! Impl deps: clock
//! Clojure peer: none
//!
//! Thin wrapper over `runtime/clock.zig` per F-009. Static methods
//! `currentTimeMillis` and `nanoTime` map directly to
//! `clock.currentMillis` / `clock.nanoTime`. JVM Clojure code reaches
//! these via `(System/currentTimeMillis)` / `(System/nanoTime)`; the
//! actual static-method dispatch lands at Phase 7 (ADR-0008 a1) on
//! top of the `___HOST_EXTENSION` registration this file ships.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.lang.System",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.System",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
