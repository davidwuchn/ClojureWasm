// SPDX-License-Identifier: EPL-2.0
//! Regex primitives for the `rt/` namespace — Clojure-ns surface.
//!
//! `re-find`, `re-matches`, `re-seq`, `re-groups`, `re-pattern`
//! from clojure.core; `clojure.string/replace` and
//! `clojure.string/split` also dispatch here. All wrap
//! `runtime/regex/{compile,match}.zig` per F-009 — the same impl
//! is shared with the Java surface in
//! `runtime/java/util/regex/Pattern.zig`.
//!
//! Status: Phase 6.6 cycle 1 SKELETON — module declared with no
//! primitives registered yet. `register(...)` is a no-op until
//! the parser + Pike VM reach green; at that point the five core
//! primitives (re-find / re-matches / re-seq / re-groups /
//! re-pattern) land in one batch with their unit tests.

const env_mod = @import("../../runtime/env.zig");

/// Phase 6.6 cycle 1 SKELETON — no entries yet. The shape mirrors
/// `lang/primitive/uuid.zig` (Entry struct + ENTRIES array) so the
/// next commit just appends rows.
pub fn register(env: *env_mod.Env, rt_ns: *env_mod.Namespace) !void {
    _ = env;
    _ = rt_ns;
    // Phase 6.6 cycle 1: parser + Pike VM land in follow-up
    // commits. Once green, the five clojure.core primitives
    // (re-find / re-matches / re-seq / re-groups / re-pattern)
    // are registered here in one batch.
}
