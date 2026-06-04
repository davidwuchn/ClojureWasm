// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.time.Instant`.
//!
//! Backend: impl-only
//! Impl deps: instant
//! Clojure peer: none (clojure.instant has its own parser)
//!
//! Java 8+ canonical time class. The `___HOST_EXTENSION` declaration
//! is registered, but the method_table is empty: instance methods
//! (now / toEpochMilli / getEpochSecond / getNano / parse) over the
//! existing `runtime/time/instant.zig` impl are not yet wired.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.time.Instant",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.time.Instant",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
