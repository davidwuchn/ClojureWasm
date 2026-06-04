// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.math.BigDecimal`.
//!
//! Backend: impl-only
//! Impl deps: big_decimal
//! Clojure peer: clojure.core/bigdec, clojure.core/+, clojure.core/-,
//!   clojure.core/*, clojure.core// (numeric tower auto-promotion)
//!
//! Thin wrapper over `runtime/numeric/big_decimal.zig` per F-009 —
//! the existing impl carries the `(unscaled BigInt, i32 scale)`
//! representation declared by F-005. The Clojure peer in
//! `lang/primitive/math.zig` already exercises BigDecimal arithmetic
//! through that impl. This file is a TypeDescriptor reservation
//! (per ADR-0029 D5): its method_table is empty, so
//! `(java.math.BigDecimal/valueOf 42)` and Java-style method
//! dispatch do not yet resolve (D-097). The observable numeric-tower
//! auto-promotion that uses this surface landed via D-014a.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.math.BigDecimal",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.math.BigDecimal",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
