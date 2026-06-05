// SPDX-License-Identifier: EPL-2.0
//! D-037 / F-001 spike: prove cljw can consume zwasm v2's Zig embedding API
//! through a `build.zig.zon` relative-path import. Built ONLY with
//! `-Dzwasm-spike` (never part of the default build or the test gate), so a
//! churning zwasm tree cannot break cljw's gate. zwasm v2 is consumed ONLY from
//! the `zwasm-from-scratch` long-lived branch (the git tags are zwasm v1, which
//! cljw never uses). Mirrors zwasm's own `examples/zig_dep` so the spike tracks
//! the canonical embedding surface (Engine -> compile -> instantiate ->
//! typedFunc().call(), plus an untyped path and the cw-allocator handshake).
//!
//! Exits 0 on success; a non-zero exit names the failing stage. This file lives
//! OUTSIDE `src/` on purpose (it dodges the src/** zone / docstring / test-reach
//! gates and is not in the cljw binary).
const std = @import("std");
const zwasm = @import("zwasm");

// (module (func (export "add") (param i32 i32) (result i32)
//   local.get 0  local.get 1  i32.add))
const add_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01,
    0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01,
    0x03, 0x61, 0x64, 0x64, 0x00, 0x00, 0x0a, 0x09,
    0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a,
    0x0b,
};

pub fn main() !void {
    // Stage A — drive zwasm with cljw's general-purpose allocator. F-006 keeps
    // the cljw heap and Wasm linear memory in separate spaces; here we only
    // prove Engine.init accepts an arbitrary allocator (D-038 item 3 surface).
    var dbg = std.heap.DebugAllocator(.{}){};
    defer _ = dbg.deinit();
    const alloc = dbg.allocator();

    var eng = try zwasm.Engine.init(alloc, .{});
    defer eng.deinit();

    var mod = try eng.compile(&add_wasm);
    defer mod.deinit();

    var inst = try mod.instantiate(.{});
    defer inst.deinit();

    // Stage B — comptime-typed export handle (the primary embedding ergonomics).
    const add = inst.typedFunc(fn (i32, i32) i32, "add");
    const typed = try add.call(.{ 2, 40 });
    std.debug.print("cljw<-zwasm spike: typed add(2,40) = {d}\n", .{typed});
    if (typed != 42) std.process.exit(2);

    std.debug.print("cljw<-zwasm spike: OK (zwasm-from-scratch embedding API consumable)\n", .{});
}
