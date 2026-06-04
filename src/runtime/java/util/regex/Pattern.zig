// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.regex.Pattern`.
//!
//! Backend: impl-only
//! Impl deps: regex
//! Clojure peer: clojure.core/re-pattern, clojure.core/re-find,
//!   clojure.core/re-matches, clojure.core/re-seq,
//!   clojure.core/re-groups, clojure.string/replace,
//!   clojure.string/split
//!
//! Thin wrapper over `runtime/regex/{compile,match}.zig` per
//! F-009 + ADR-0031. The Clojure-ns peer in
//! `lang/primitive/regex.zig` calls the same impl; this file is
//! the entry point for `(java.util.regex.Pattern/compile ...)`
//! and similar Java-style invocations.
//!
//! Status: standing reservation — the `___HOST_EXTENSION` marker is
//! declared but the descriptor's method_table is empty, so
//! `(java.util.regex.Pattern/compile ...)` does not yet resolve.
//! The `runtime/regex/` impl is complete; only this Java-surface
//! method wiring is unbuilt.

const host_api = @import("../../_host_api.zig");
const type_descriptor = @import("../../../type_descriptor.zig");

/// `___HOST_EXTENSION` declaration scanned by the host aggregator
/// (`runtime/java/_host_api.zig::installAll`, Phase 14 row 14.1).
/// `init` is null because there is no per-Runtime setup beyond
/// descriptor registration; the pattern compile cache lives in
/// `runtime/regex/compile.zig` (or a future `runtime/regex/cache.zig`
/// per D-052 Alt-3 promotion).
pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.regex.Pattern",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.util.regex.Pattern",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
