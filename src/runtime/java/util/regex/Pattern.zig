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
//! Status: Phase 6.6 cycle 1 SKELETON — `___HOST_EXTENSION`
//! marker declared, descriptor populated lazily after the
//! `runtime/regex/` impl reaches first-green. ADR-0031's
//! "skeleton-then-rewrite" boundary applies.

const host_api = @import("../../_host_api.zig");

/// `___HOST_EXTENSION` declaration scanned by the host aggregator
/// (`runtime/java/_host_api.zig`). `init` is null because there
/// is no per-Runtime setup beyond descriptor registration; the
/// pattern compile cache lives in `runtime/regex/compile.zig`
/// (or a future `runtime/regex/cache.zig` per D-052 Alt-3
/// promotion).
pub const ___HOST_EXTENSION: host_api.Extension = .{
    .fqn = "java.util.regex.Pattern",
    .cljw_ns = "cljw.host.java.util.regex.Pattern",
    .descriptor = null,
    .init = null,
};
