// SPDX-License-Identifier: EPL-2.0
//! `java.util.Locale` singleton impl (keyword `locale`) — neutral so the
//! analyzer (static-field resolve) and `Runtime.deinit` reach it without
//! importing the `runtime/java/` surface tree (zone rule). The surface
//! (`runtime/java/util/Locale.zig`) owns the descriptor + static-field table;
//! this file owns the process-lifetime singletons.
//!
//! Each Locale is a `.host_instance` allocated once on `gc.infra` (never
//! GC-swept, like PersistentQueue/EMPTY) + cached on an `rt` slot — a GC leaf
//! with no rooting subtlety. cljw casing is locale-independent (ADR-0050 am1),
//! so the value is opaque: it only needs to exist + carry its tag for `str`.

const Value = @import("value/value.zig").Value;
const HeapHeader = @import("value/value.zig").HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const host_instance = @import("host_instance.zig");

pub const Which = enum(u64) { us = 0, root = 1 };

/// `java.util.Locale.toString()` tag for `which` ("en_US" / "" for ROOT).
pub fn tagString(which: Which) []const u8 {
    return switch (which) {
        .us => "en_US",
        .root => "",
    };
}

/// The process-lifetime Locale singleton for `which` — allocated once on
/// `gc.infra` + cached on the `rt` slot. The descriptor is the surface one in
/// `rt.types` (registered by `installAll` at startup, so present by the time a
/// `Locale/US` static field is first resolved).
pub fn singleton(rt: *Runtime, which: Which) !Value {
    const slot = switch (which) {
        .us => &rt.locale_us,
        .root => &rt.locale_root,
    };
    if (!slot.isNil()) return slot.*;
    // The surface descriptor is registered by installAll at startup, so a miss
    // here is a wiring bug, not a user-reachable path.
    const td = rt.types.get("java.util.Locale") orelse return error.InternalError;
    const inst = try rt.gc.infra.create(host_instance.HostInstance);
    inst.* = .{
        .header = HeapHeader.init(.host_instance),
        .descriptor = td,
        .state = .{ @intFromEnum(which), 0, 0, 0 },
    };
    slot.* = Value.encodeHeapPtr(.host_instance, inst);
    return slot.*;
}

/// Release both Locale singletons (gc.infra-allocated). Called from
/// `Runtime.deinit`; idempotent.
pub fn deinitSingletons(rt: *Runtime) void {
    for ([_]*Value{ &rt.locale_us, &rt.locale_root }) |slot| {
        if (slot.isNil()) continue;
        rt.gc.infra.destroy(@constCast(host_instance.asHostInstance(slot.*)));
        slot.* = .nil_val;
    }
}
