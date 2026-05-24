// SPDX-License-Identifier: EPL-2.0
//! Differential test cases — calls `eval.evaluator.compare` against a
//! Runtime + Env wired with the standard primitive + macro tables
//! (Phase 4 entry suite, ROADMAP §9.6 / 4.10).
//!
//! Lives in `lang/` because the fixture imports `primitive.registerAll`
//! and `macro_transforms.registerInto`, which are zone-1 modules
//! `eval/evaluator.zig` cannot reach (`zone_deps.md`).
//!
//! Each `test "diff: …"` block describes one source form whose
//! tree-walk and VM evaluations must agree. New cases land here as
//! the Phase-4 task list progresses; the harness scales with each
//! addition.

const std = @import("std");
const evaluator = @import("../eval/evaluator.zig");
const macro_dispatch = @import("../eval/macro_dispatch.zig");
const Runtime = @import("../runtime/runtime.zig").Runtime;
const env_mod = @import("../runtime/env.zig");
const Env = env_mod.Env;
const Value = @import("../runtime/value/value.zig").Value;
const primitive = @import("primitive.zig");
const macro_transforms = @import("macro_transforms.zig");

const testing = std.testing;

const Fixture = struct {
    threaded: std.Io.Threaded,
    rt: Runtime,
    env: Env,
    arena: std.heap.ArenaAllocator,
    table: macro_dispatch.Table,

    fn init(alloc: std.mem.Allocator) !Fixture {
        var f: Fixture = undefined;
        f.threaded = std.Io.Threaded.init(alloc, .{});
        f.rt = Runtime.init(f.threaded.io(), alloc);
        f.env = try Env.init(&f.rt);
        f.arena = std.heap.ArenaAllocator.init(alloc);
        f.table = macro_dispatch.Table.init(alloc);
        try primitive.registerAll(&f.env);
        try macro_transforms.registerInto(&f.env, &f.table);
        return f;
    }

    fn deinit(self: *Fixture) void {
        self.table.deinit();
        self.arena.deinit();
        self.env.deinit();
        self.rt.deinit();
        self.threaded.deinit();
    }

    fn check(self: *Fixture, source: []const u8, expected: i64) !void {
        const r = evaluator.compare(&self.rt, &self.env, &self.table, self.arena.allocator(), source);
        try testing.expect(r.equal);
        try testing.expectEqual(expected, (try r.tree_walk).asInteger());
    }
};

test "diff: arithmetic primitive" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("(+ 1 2 3)", 6);
}

test "diff: let* binding" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("(let* [x 5] (+ x 10))", 15);
}

test "diff: fn* immediate invocation" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("((fn* [x y] (+ x y)) 3 4)", 7);
}

test "diff: loop*/recur countdown" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("(loop* [i 0] (if (< i 3) (recur (+ i 1)) i))", 3);
}

test "diff: closure capture via let-then-fn" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("((let* [x 10] (fn* [y] (+ x y))) 5)", 15);
}

test "diff: nested if branches" {
    var f = try Fixture.init(testing.allocator);
    defer f.deinit();
    try f.check("(if (if true false true) 1 2)", 2);
}
