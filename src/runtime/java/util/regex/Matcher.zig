// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.regex.Matcher`.
//!
//! Backend: impl-only
//! Impl deps: regex
//! Clojure peer: clojure.core/re-find, clojure.core/re-matches,
//!   clojure.core/re-seq, clojure.core/re-groups
//!
//! Thin wrapper over `runtime/regex/match.zig` per F-009. The
//! Clojure-ns peers in `lang/primitive/regex.zig` carry the
//! behaviour; this file is the reserved entry point for
//! `(java.util.regex.Matcher/find m)` and similar Java-style
//! method invocations.
//!
//! TypeDescriptor reservation per ADR-0029 D5. The method_table is
//! empty: method-level wiring (`find` / `group` / `start` / `end`)
//! is unbuilt, and Matcher instances are not yet produced by
//! `Pattern.matcher`.

const host_api = @import("../../_host_api.zig");
const type_descriptor = @import("../../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.regex.Matcher",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.util.regex.Matcher",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
