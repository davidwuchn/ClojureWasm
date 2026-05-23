// SPDX-License-Identifier: EPL-2.0
//! Protocol dispatch table — `ProtocolDescriptor` + `MethodEntry`
//! struct declarations (ROADMAP §9.6 / 4.18, ADR-0008).
//!
//! Phase 4 entry ships declarations only. The `dispatch` function
//! lands at Phase 7 alongside the `CallSite` cache (per ADR-0008's
//! Phase 7 entry activation). Phase 4 freezes the struct layout so
//! `TypeDescriptor.method_table` (4.17) and the future call-site
//! cache (4.25) can reference these types now.

const std = @import("std");

/// One method on a protocol — name + arity (Clojure protocols are
/// arity-overloaded). The implementation pointer lives on the
/// implementing `TypeDescriptor.method_table` entry, not here; this
/// descriptor only declares the protocol's surface.
pub const MethodEntry = struct {
    name: []const u8,
    arity: u8,
};

/// One protocol — fully-qualified name + the methods it declares.
/// Implementations are registered on the implementing type's
/// `TypeDescriptor` (4.17), so a protocol descriptor itself carries
/// no `*const fn` pointers.
pub const ProtocolDescriptor = struct {
    /// Fully-qualified name, e.g. `"user/ISeq"`. Interned bytes
    /// owned by the runtime's symbol pool.
    fqcn: []const u8,
    /// The declared methods. Insertion order matches the order of
    /// `defprotocol` clauses; dispatch (Phase 7) uses linear scan
    /// over this slice plus the per-call-site cache.
    methods: []const MethodEntry,
};

// --- tests ---

const testing = std.testing;

test "MethodEntry shape" {
    const m: MethodEntry = .{ .name = "first", .arity = 1 };
    try testing.expectEqualStrings("first", m.name);
    try testing.expectEqual(@as(u8, 1), m.arity);
}

test "ProtocolDescriptor: fqcn + method list shape" {
    const methods = [_]MethodEntry{
        .{ .name = "first", .arity = 1 },
        .{ .name = "rest", .arity = 1 },
        .{ .name = "cons", .arity = 2 },
    };
    const pd: ProtocolDescriptor = .{ .fqcn = "user/ISeq", .methods = &methods };
    try testing.expectEqualStrings("user/ISeq", pd.fqcn);
    try testing.expectEqual(@as(usize, 3), pd.methods.len);
}
