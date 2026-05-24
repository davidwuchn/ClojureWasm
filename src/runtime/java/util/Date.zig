// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.Date` (legacy time class kept around
//! for pre-Java-8 corpus compatibility).
//!
//! Backend: impl-only
//! Impl deps: instant
//! Clojure peer: none
//!
//! `java.util.Date` is essentially an epoch-ms wrapper; cw v1
//! routes through `runtime/time/instant.zig` rather than a separate
//! impl. Phase 6.5 lands the `___HOST_EXTENSION` declaration;
//! instance methods (getTime / setTime / toString / toInstant) wire
//! through Phase 7 dispatch.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.Date",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.util.Date",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
