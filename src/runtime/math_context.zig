// SPDX-License-Identifier: EPL-2.0
//! `java.math.MathContext` standard-constant singletons (keyword `math_context`)
//! — neutral so the analyzer (static-field resolve) and `Runtime.deinit` reach
//! the singletons without importing the `runtime/java/` surface tree (zone rule).
//! The surface (`runtime/java/math/MathContext.zig`) owns the descriptor +
//! constructor + methods; this file owns the 4 IEEE-754 standard contexts
//! (DECIMAL32/64/128/UNLIMITED) + the process-lifetime singletons.
//!
//! Each constant is a `.host_instance` (state[0]=precision, state[1]=RoundingMode
//! ordinal), cached on an `rt` slot — same discipline as RoundingMode / ChronoUnit
//! / Locale.

const Value = @import("value/value.zig").Value;
const HeapHeader = @import("value/value.zig").HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const host_instance = @import("host_instance.zig");

pub const COUNT = 4;

/// (precision, RoundingMode-ordinal) for the standard constant `which` (0-3 =
/// DECIMAL32 / DECIMAL64 / DECIMAL128 / UNLIMITED). HALF_EVEN=6, HALF_UP=4.
fn params(which: u8) struct { precision: u64, mode: u64 } {
    return switch (which) {
        0 => .{ .precision = 7, .mode = 6 }, // DECIMAL32
        1 => .{ .precision = 16, .mode = 6 }, // DECIMAL64
        2 => .{ .precision = 34, .mode = 6 }, // DECIMAL128
        3 => .{ .precision = 0, .mode = 4 }, // UNLIMITED (precision 0 = exact)
        else => unreachable,
    };
}

/// The process-lifetime MathContext singleton for standard constant `which`
/// (0-3) — allocated once on `gc.infra` + cached on `rt.math_contexts[which]`.
pub fn singleton(rt: *Runtime, which: u8) !Value {
    const slot = &rt.math_contexts[which];
    if (!slot.isNil()) return slot.*;
    const td = rt.types.get("java.math.MathContext") orelse return error.InternalError;
    const p = params(which);
    const inst = try rt.gc.infra.create(host_instance.HostInstance);
    inst.* = .{
        .header = HeapHeader.init(.host_instance),
        .descriptor = td,
        .state = .{ p.precision, p.mode, 0, 0 },
    };
    slot.* = Value.encodeHeapPtr(.host_instance, inst);
    return slot.*;
}

/// Release all MathContext standard-constant singletons (gc.infra-allocated).
/// Called from `Runtime.deinit`; idempotent.
pub fn deinitSingletons(rt: *Runtime) void {
    for (&rt.math_contexts) |*slot| {
        if (slot.isNil()) continue;
        rt.gc.infra.destroy(@constCast(host_instance.asHostInstance(slot.*)));
        slot.* = .nil_val;
    }
}
