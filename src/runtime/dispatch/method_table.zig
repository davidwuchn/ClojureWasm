// SPDX-License-Identifier: EPL-2.0
//! Per-call-site dispatch cache for `.method` invocations
//! (ROADMAP §9.6 / 4.25, ADR-0008).
//!
//! Phase 4 entry ships the `CallSite` struct declaration only. The
//! `dispatch(callsite, receiver, method, args)` function lands at
//! Phase 7 (ADR-0008 amendment 1) with cache-fill on miss.
//!
//! Naming note: the actual per-implementation method record lives
//! at `type_descriptor.zig::TypeDescriptor.MethodEntry` (landed at
//! 4.17). `CallSite.last_method` caches a pointer into that table.
//! A separate `MethodEntry` struct is NOT declared here — see
//! debt D-040 for the cross-file naming reconciliation queued at
//! Phase 7 entry (where the protocol-declaration entry in
//! `protocol.zig` and the type-implementation entry in
//! `type_descriptor.zig` are renamed together with the dispatch
//! function landing).

const std = @import("std");
const TypeDescriptor = @import("../type_descriptor.zig").TypeDescriptor;

/// Per-call-site monomorphic cache slot.
///
/// At analyzer time, every `.method` call site is given a `CallSite`
/// instance whose two cache slots start `null`. The Phase 7 dispatch
/// function consults the cache:
///
///   1. If `last_type == receiver.typeDescriptor()`, jump directly to
///      `last_method.fn_ptr` (monomorphic fast path).
///   2. Otherwise, fall through to `TypeDescriptor.lookupMethod` and
///      refill both slots.
///
/// The two-slot shape mirrors C2 / V8's inline-cache pattern; cw v1
/// does not (yet) escalate to polymorphic or megamorphic states. If
/// benchmarks at Phase 7+ surface megamorphic hot sites, the cache
/// is widened in place — the `CallSite` consumer surface is just
/// "ask + refill", so widening is local to this file.
pub const CallSite = struct {
    last_type: ?*const TypeDescriptor = null,
    last_method: ?*const TypeDescriptor.MethodEntry = null,
};

// --- tests ---

const testing = std.testing;

test "CallSite default-initialises with both cache slots null" {
    const cs: CallSite = .{};
    try testing.expect(cs.last_type == null);
    try testing.expect(cs.last_method == null);
}

test "CallSite cache slots accept TypeDescriptor + MethodEntry pointers" {
    const td: TypeDescriptor = .{
        .fqcn = "user.MyType",
        .kind = .deftype,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
    };
    const me: TypeDescriptor.MethodEntry = .{
        .protocol_name = "ISeq",
        .method_name = "first",
        .fn_ptr = null,
    };
    const cs: CallSite = .{ .last_type = &td, .last_method = &me };
    try testing.expect(cs.last_type.? == &td);
    try testing.expectEqualStrings("first", cs.last_method.?.method_name);
}
