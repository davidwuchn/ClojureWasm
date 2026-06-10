// SPDX-License-Identifier: EPL-2.0
//! Arithmetic / comparison intrinsic fast path (ADR-0130).
//!
//! The bytecode VM and the TreeWalk backend both route a 2-arg call to a
//! canonical `clojure.core` arithmetic/comparison Var through
//! `fastBinaryFixnum` BEFORE the generic builtin dispatch. Sharing this single
//! function makes dual-backend parity (ADR-0036 / F-012) STRUCTURAL — there is
//! exactly one fast path, so the differential oracle cannot catch a
//! fast-path-vs-builtin divergence.
//!
//! `fastBinaryFixnum` fires ONLY when both operands are inline fixnums
//! (`.integer`); anything else (float / ratio / bigint / heap-Long / non-number)
//! returns `null`, and the caller falls back to the cached builtin Var via
//! `vt.callFn` — identical to the generic path, including the builtin's
//! arg-precise error translation (F-011). add/sub/mul delegate to the existing
//! `promote.*Promoting` (i64 `@addWithOverflow` → `wrapI64`, so an i48 overflow
//! becomes a heap-Long / BigInt per F-005 — never a silent wrap, never a float).
//! Comparisons are exact i48 (`.integer` is always in-range). The non-overflow
//! integer path allocates nothing → no GC safepoint, no rooting (the O-007
//! no-alloc-fast-path precedent; F-006).
//!
//! The compile-time recogniser (`opcodeFor`, gated on canonical-Var pointer
//! identity + the `core_arith_pristine` deopt flag) lands with the opcodes
//! themselves in a follow-up step; this module is the dispatch-side core.

const std = @import("std");
const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const promote = @import("../../runtime/numeric/promote.zig");

/// The intrinsifiable binary operations (first cut). `/`, `=`, `not=` are
/// intentionally absent (ADR-0130): integer `/` yields a Ratio / divide-by-zero
/// raise, and `=`/`not=` must match full `valueEqual` on the non-numeric tail.
pub const ArithOp = enum { add, sub, mul, lt, le, gt, ge };

/// Fixnum fast path. Returns `null` unless BOTH operands are inline fixnums, so
/// the caller defers every other case (incl. all error cases) to the builtin.
pub fn fastBinaryFixnum(rt: *Runtime, op: ArithOp, a: Value, b: Value) !?Value {
    if (a.tag() != .integer or b.tag() != .integer) return null;
    return switch (op) {
        .add => try promote.addPromoting(rt, a, b),
        .sub => try promote.subPromoting(rt, a, b),
        .mul => try promote.mulPromoting(rt, a, b),
        .lt => Value.initBoolean(a.asInteger() < b.asInteger()),
        .le => Value.initBoolean(a.asInteger() <= b.asInteger()),
        .gt => Value.initBoolean(a.asInteger() > b.asInteger()),
        .ge => Value.initBoolean(a.asInteger() >= b.asInteger()),
    };
}

// --- tests ------------------------------------------------------------------

const testing = std.testing;

const Fixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,

    fn init() Fixture {
        var fix: Fixture = .{
            .threaded = std.Io.Threaded.init(testing.allocator, .{}),
            .rt = undefined,
        };
        fix.rt = Runtime.init(fix.threaded.io(), testing.allocator);
        return fix;
    }
    fn deinit(self: *Fixture) void {
        self.rt.deinit();
        self.threaded.deinit();
    }
};

test "fastBinaryFixnum add/sub/mul on two fixnums" {
    var fix = Fixture.init();
    defer fix.deinit();
    const a = Value.initInteger(7);
    const b = Value.initInteger(5);
    try testing.expectEqual(@as(i48, 12), (try fastBinaryFixnum(&fix.rt, .add, a, b)).?.asInteger());
    try testing.expectEqual(@as(i48, 2), (try fastBinaryFixnum(&fix.rt, .sub, a, b)).?.asInteger());
    try testing.expectEqual(@as(i48, 35), (try fastBinaryFixnum(&fix.rt, .mul, a, b)).?.asInteger());
}

test "fastBinaryFixnum mul overflowing i48 promotes (F-005), not a float" {
    var fix = Fixture.init();
    defer fix.deinit();
    const a = Value.initInteger((1 << 47) - 1); // i48 max
    const v = (try fastBinaryFixnum(&fix.rt, .mul, a, Value.initInteger(2))).?;
    try testing.expect(v.tag() == .big_int); // heap-Long / BigInt, never .float
}

test "fastBinaryFixnum comparisons are exact" {
    var fix = Fixture.init();
    defer fix.deinit();
    const one = Value.initInteger(1);
    const two = Value.initInteger(2);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .lt, one, two)).? == Value.true_val);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .gt, one, two)).? == Value.false_val);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .le, two, two)).? == Value.true_val);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .ge, one, two)).? == Value.false_val);
}

test "fastBinaryFixnum defers (null) when an operand is not an inline fixnum" {
    var fix = Fixture.init();
    defer fix.deinit();
    const i = Value.initInteger(3);
    const f = Value.initFloat(1.5);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .add, i, f)) == null);
    try testing.expect((try fastBinaryFixnum(&fix.rt, .add, f, i)) == null);
}
