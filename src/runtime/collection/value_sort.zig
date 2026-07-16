// SPDX-License-Identifier: EPL-2.0
//! ONE shared `std.mem.sort` instantiation for every `[]Value` sort site
//! (ADR-0172 L6). `std.mem.sort` monomorphizes ~25 KB of block sort per
//! (element, context, comparator) triple; funnelling the Value sites
//! through a runtime fn-pointer comparator keeps the binary at one
//! instantiation while the comparators stay site-local. The indirect call
//! per comparison is marginal next to the `valueCompare`/eval work every
//! comparator already does.

const std = @import("std");
const Value = @import("../value/value.zig").Value;

/// Site-local comparator: `ctx` is the site's own context struct, passed
/// back opaquely (cast with `@ptrCast(@alignCast(ctx))`).
pub const LessFn = *const fn (ctx: *anyopaque, a: Value, b: Value) bool;

const Shim = struct { ctx: *anyopaque, less: LessFn };

fn shimLess(s: Shim, a: Value, b: Value) bool {
    return s.less(s.ctx, a, b);
}

/// Stable sort of `items` via the shared instantiation.
pub fn sort(items: []Value, ctx: *anyopaque, less: LessFn) void {
    std.mem.sort(Value, items, Shim{ .ctx = ctx, .less = less }, shimLess);
}

test "value_sort sorts through an opaque comparator" {
    const C = struct {
        fn less(_: *anyopaque, a: Value, b: Value) bool {
            return a.asInteger() < b.asInteger();
        }
    };
    var items = [_]Value{ Value.initInteger(3), Value.initInteger(1), Value.initInteger(2) };
    var dummy: u8 = 0;
    sort(&items, @ptrCast(&dummy), &C.less);
    try std.testing.expectEqual(@as(i48, 1), items[0].asInteger());
    try std.testing.expectEqual(@as(i48, 2), items[1].asInteger());
    try std.testing.expectEqual(@as(i48, 3), items[2].asInteger());
}
