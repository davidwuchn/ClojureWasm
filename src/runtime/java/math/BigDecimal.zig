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
//! through that impl; this file lets `(java.math.BigDecimal/valueOf
//! 42)` and the Java-style method dispatch resolve once Phase 7
//! TypeDescriptor.method_table is populated for this surface.
//!
//! Phase 14 row 14.2 (D-097): TypeDescriptor reservation ships
//! per ADR-0029 D5. Phase 14 row 14.4 (D-014a) completes the
//! observable numeric-tower auto-promotion that uses this surface.

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
