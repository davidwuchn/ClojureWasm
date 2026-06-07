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
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");

/// Inline state-word count. Random needs 3 (seed + gaussian value + flag); the
/// 4th is a spare so a small future host type need not widen the struct.
pub const STATE_WORDS = 4;

comptime {
    // `TypeDescriptor.host_finalise` hardcodes `*[4]u64` to avoid importing this
    // module (circular); pin the two equal so a future widening can't drift.
    std.debug.assert(STATE_WORDS == 4);
}

pub const HostInstance = extern struct {
    header: HeapHeader,
    /// The rt.types surface descriptor (FQCN-keyed). Identifies the host type +
    /// carries its instance method_table. Process-lifetime (not GC-traced).
    descriptor: *const TypeDescriptor,
    /// Fixed inline payload. Interpretation is per-host-type (see the surface).
    /// CONDITIONALLY non-leaf: a host type whose `descriptor.host_trace` is set
    /// stores a live `Value` here (java.util.Iterator's cursor seq in state[0]),
    /// marked by the shared `.host_instance` tracer via that hook (D-294 closed).
    /// Leaf types (Random / URI / StringBuilder) leave `host_trace` null and hold
    /// only non-Value words. GC-ROOT: a Value stored here is a raw `u64` the
    /// standard field-walker cannot see as a pointer, so a FUTURE moving GC must
    /// RELOCATE it through `host_trace` (mark-only suffices for the current
    /// non-moving GC) [ref: .dev/gc_rooting.md §H, debt D-318].
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

/// Shared `.host_instance` tag finaliser: route to the descriptor's
/// `host_finalise` hook (URI / StringBuilder free their heap state; Random's hook
/// is null). Most host types are GC-leaf; this is a best-effort free for those
/// that own heap state.
fn finaliseGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const inst: *HostInstance = @ptrCast(@alignCast(header));
    if (inst.descriptor.host_finalise) |f| f(gc.infra, &inst.state);
}

/// Shared `.host_instance` tag tracer: route to the descriptor's `host_trace`
/// hook (java.util.Iterator marks its cursor seq Value). `null` for leaf host
/// types (Random / URI / StringBuilder store only non-Value words), so they pay
/// no trace cost.
fn traceGc(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const inst: *HostInstance = @ptrCast(@alignCast(header));
    if (inst.descriptor.host_trace) |f| f(gc_ptr, &inst.state);
}

pub fn registerGcHooks() void {
    tag_ops.registerFinaliser(.host_instance, &finaliseGc);
    tag_ops.registerTrace(.host_instance, &traceGc);
}
