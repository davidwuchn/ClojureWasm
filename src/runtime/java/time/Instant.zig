// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.time.Instant`.
//!
//! Backend: impl-only
//! Impl deps: instant
//! Clojure peer: none (clojure.instant has its own parser)
//!
//! Java 8+ canonical time class. Phase 6.5 lands the
//! `___HOST_EXTENSION` declaration; instance methods (now /
//! toEpochMilli / getEpochSecond / getNano / parse) wire through
//! Phase 7 dispatch on top of `runtime/time/instant.zig`.

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
