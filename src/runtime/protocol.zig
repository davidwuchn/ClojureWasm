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
const Runtime = @import("runtime.zig").Runtime;
const td_mod = @import("type_descriptor.zig");
const TypeDescriptor = td_mod.TypeDescriptor;

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

/// Row 7.3 cycle 1: append `new_impls` to `td.method_table` and bump
/// `rt.protocol_generation`. The TypeDescriptor's `method_table` is
/// re-allocated on `rt.gc.infra` (process-lifetime) so the new slice
/// pointer stays valid for the descriptor's lifetime; the old slice
/// is leaked to infra rather than freed because live CallSite caches
/// may still reference the stale pointer until the next dispatch
/// invalidates them via the generation check.
///
/// Per survey §5.2 + ADR-0008 amendment 1 Alt 1 ("generation deferred
/// to 7.3 / extend-type"). cycle 2 wires CallSite.cached_generation
/// + the lookupWithCache predicate that consumes the bump.
pub fn extendTypeWithImpls(
    rt: *Runtime,
    td: *TypeDescriptor,
    new_impls: []const TypeDescriptor.MethodEntry,
) !void {
    const old = td.method_table;
    const combined = try rt.gc.infra.alloc(TypeDescriptor.MethodEntry, old.len + new_impls.len);
    @memcpy(combined[0..old.len], old);
    @memcpy(combined[old.len..], new_impls);
    td.method_table = combined;
    rt.protocol_generation +%= 1;
}

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

test "extendTypeWithImpls bumps protocol_generation and grows method_table" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    // Synthetic descriptor with empty method_table on `rt.gc.infra`.
    // Production deftype / defrecord analysers register descriptors
    // into `rt.types` (which Runtime.deinit then walks); this test
    // pre-empts that machinery by managing the descriptor's lifetime
    // explicitly.
    const td = try rt.gc.infra.create(TypeDescriptor);
    defer rt.gc.infra.destroy(td);
    td.* = .{
        .fqcn = "user/Foo",
        .kind = .deftype,
        .field_layout = null,
        .protocol_impls = &[_][]const u8{},
        .method_table = &[_]TypeDescriptor.MethodEntry{},
        .parent = null,
        .meta = @import("value/value.zig").Value.nil_val,
    };

    try testing.expectEqual(@as(u32, 0), rt.protocol_generation);
    try testing.expectEqual(@as(usize, 0), td.method_table.len);

    const new_impls = [_]TypeDescriptor.MethodEntry{
        .{ .protocol_name = "user/IFoo", .method_name = "bar", .fn_ptr = null },
    };
    try extendTypeWithImpls(&rt, td, &new_impls);
    // Per the "re-alloc + swap, never free old" policy, the heap-
    // allocated slice replacing the empty static one must be freed
    // explicitly when the test exits. Production code accepts the
    // leak because live CallSite caches may still reference the
    // stale pointer until the generation check invalidates them.
    defer rt.gc.infra.free(td.method_table);

    try testing.expectEqual(@as(u32, 1), rt.protocol_generation);
    try testing.expectEqual(@as(usize, 1), td.method_table.len);
    try testing.expectEqualStrings("bar", td.method_table[0].method_name);
    try testing.expectEqualStrings("user/IFoo", td.method_table[0].protocol_name);
}
