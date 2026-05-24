// SPDX-License-Identifier: EPL-2.0
//! Java-compat surface registry contract (ADR-0029, supersedes ADR-0011).
//!
//! Each Java-stdlib equivalent under `src/runtime/java/<pkg>/<Class>.zig`
//! exports a top-level `___HOST_EXTENSION` declaration whose type is
//! `Extension`. A future aggregator (Phase 6+) uses Zig comptime
//! introspection to collect every such declaration into the Java
//! surface registry without a central edit per addition.
//!
//! Phase 5 entry lands the contract only (this file). The first
//! `<Class>.zig` lands at Phase 6 entry; until then `runtime/java/`
//! holds only this aggregator file. `runtime/cljw/<area>/<Item>.zig`
//! mirrors the same marker pattern for cljw-original surfaces; the
//! two trees share the same `Extension` shape and registry contract
//! per ADR-0029 D1.

const std = @import("std");
const type_descriptor = @import("../type_descriptor.zig");

/// Marker symbol every Java- and cljw-surface file exports under
/// this exact name. See the module docstring for the aggregator
/// scan contract.
pub const MARKER_NAME: []const u8 = "___HOST_EXTENSION";

/// One surface extension entry. Carries the user-facing Clojure name
/// (`cljw.java.util.UUID` for Java surface; `cljw.<area>.<Item>` for
/// cljw-original surface), the corresponding native `TypeDescriptor`,
/// and an optional init function for any one-time setup. The `init`
/// is invoked once at Runtime startup.
pub const Extension = struct {
    /// Clojure-side namespace this entry exposes:
    ///   - Java surface: `cljw.java.<java-pkg>.<Class>` (e.g.,
    ///     `cljw.java.util.UUID`).
    ///   - cljw-original: `cljw.<area>.<Item>` (e.g., `cljw.wasm.Engine`).
    /// Used by Clojure `(:require [cljw.java.util :refer [UUID]])` or
    /// `(:require [cljw.wasm :refer [Engine]])`.
    cljw_ns: []const u8,
    /// Pre-allocated `TypeDescriptor` for this surface entry. Lifetime
    /// is the Runtime — the descriptor lives in the namespace it is
    /// registered into.
    descriptor: *const type_descriptor.TypeDescriptor,
    /// Optional initialiser. `null` means no setup required beyond
    /// descriptor registration.
    init: ?*const fn () anyerror!void = null,
};

const testing = std.testing;

test "Extension struct shape" {
    var td: type_descriptor.TypeDescriptor = .{
        .fqcn = "cljw.java.util.UUID",
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
    };
    const ext: Extension = .{
        .cljw_ns = "cljw.java.util.UUID",
        .descriptor = &td,
    };
    try testing.expectEqualStrings("cljw.java.util.UUID", ext.cljw_ns);
    try testing.expect(ext.init == null);
}

test "MARKER_NAME constant matches the ADR-0029 contract" {
    try testing.expectEqualStrings("___HOST_EXTENSION", MARKER_NAME);
}
