// SPDX-License-Identifier: EPL-2.0
//! General stateful-host-object container (`.host_instance` tag, ADR-0106).
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: none (host surfaces register instance methods on the carried
//! descriptor; java.util.Random is the first user — runtime/java/util/Random.zig).
//!
//! cljw has NO free Value tag (F-004 64-slot ceiling), so the long-dead
//! `host_instance` slot (29) is repurposed as the ONE home for every stateful
//! host object (java.util.Random now; SecureRandom / stateful Matcher / … later).
//! Each instance carries its SURFACE `TypeDescriptor` (the rt.types descriptor,
//! keyed by FQCN) so the constructor's `<init>` lookup and instance-member
//! dispatch share one method_table; dispatch reads the descriptor FROM THE
//! INSTANCE (`receiverDescriptor`), not the tag (a tag-keyed descriptor would
//! force all host types to share one method_table).
//!
//! `state` is a fixed inline `[4]u64` — Random uses state[0]=seed,
//! state[1]=nextGaussian bits, state[2]=have-gaussian flag; the 4th word is a
//! spare. A future host type needing unbounded state stores a `gc.infra`
//! pointer in state[0] and registers its own finaliser.

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const type_descriptor = @import("type_descriptor.zig");
const TypeDescriptor = type_descriptor.TypeDescriptor;

/// Inline state-word count. Random needs 3 (seed + gaussian value + flag); the
/// 4th is a spare so a small future host type need not widen the struct.
pub const STATE_WORDS = 4;

pub const HostInstance = extern struct {
    header: HeapHeader,
    /// The rt.types surface descriptor (FQCN-keyed). Identifies the host type +
    /// carries its instance method_table. Process-lifetime (not GC-traced).
    descriptor: *const TypeDescriptor,
    /// Fixed inline payload. Interpretation is per-host-type (see the surface).
    /// LEAF: holds only non-Value words today, so the `.host_instance` tag needs
    /// NO GC trace. A host type that stores a Value here MUST add a
    /// per-descriptor trace hook + register a tag trace dispatcher first (D-294).
    state: [STATE_WORDS]u64,

    comptime {
        std.debug.assert(@alignOf(HostInstance) >= 8);
        std.debug.assert(@offsetOf(HostInstance, "header") == 0);
    }
};

/// Allocate a host instance carrying `descriptor` + `state`. Returns a
/// `.host_instance` Value.
pub fn alloc(rt: *Runtime, descriptor: *const TypeDescriptor, state: [STATE_WORDS]u64) !Value {
    const inst = try rt.gc.alloc(HostInstance);
    inst.* = .{
        .header = HeapHeader.init(.host_instance),
        .descriptor = descriptor,
        .state = state,
    };
    return Value.encodeHeapPtr(.host_instance, inst);
}

/// Decode a `.host_instance` Value to its `*HostInstance`. `*const` is enough —
/// `state` is mutated in place through the pointer (no write barrier; leaf).
pub fn asHostInstance(v: Value) *const HostInstance {
    return v.decodePtr(*const HostInstance);
}

/// In-place write of one state word (identity-preserving, mirrors
/// `TypedInstance.setField` / atom mutation).
pub fn setState(v: Value, index: usize, word: u64) void {
    @constCast(asHostInstance(v)).state[index] = word;
}
