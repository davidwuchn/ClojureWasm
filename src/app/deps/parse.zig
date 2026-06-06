// SPDX-License-Identifier: EPL-2.0
//! deps.edn source → `DepsConfig` (Convergence Campaign Stage 1.2).
//!
//! Parse-only: turns deps.edn text into a structured config by reusing the
//! cw v1 reader (`eval/reader.zig`) rather than hand-rolling an EDN walk
//! (the v0 `deps.zig` divergence — cw's reader already pre-splits ns/name on
//! keywords/symbols). Resolution (alias merge, `:local/root` join, classpath
//! expansion) lives in the sibling `resolve.zig`; git fetch in `git_fetch.zig`.
//!
//! Source-only by policy (matches v0): `:mvn/version` is rejected, never
//! resolved (slice 2). All allocations are on the caller's allocator (an
//! arena at the call site), so there is no per-field free.

const std = @import("std");
const reader = @import("../../eval/reader.zig");
const form_mod = @import("../../eval/form.zig");
const Form = form_mod.Form;

/// Structured deps.edn. Fields land slice by slice; slice 1 = `:paths`.
pub const DepsConfig = struct {
    /// `:paths` — source directories (becomes the base classpath).
    paths: []const []const u8 = &.{},
};

/// Parse deps.edn `source` into a `DepsConfig`. The top form must be a map;
/// recognised keys are populated, unknown keys ignored (forward-compatible).
/// Strings reference the reader's form storage, so they share the caller's
/// allocator lifetime.
pub fn parseDepsEdn(allocator: std.mem.Allocator, source: []const u8) !DepsConfig {
    const top = try reader.readOne(allocator, source) orelse return .{};
    const pairs = switch (top.data) {
        .map => |kvs| kvs,
        else => return .{},
    };
    var cfg: DepsConfig = .{};
    // Map forms are flat `[k1, v1, k2, v2, ...]`.
    var i: usize = 0;
    while (i + 1 < pairs.len) : (i += 2) {
        const key = pairs[i].data;
        if (key != .keyword or key.keyword.ns != null) continue;
        if (std.mem.eql(u8, key.keyword.name, "paths")) {
            cfg.paths = try collectStringVec(allocator, pairs[i + 1]);
        }
    }
    return cfg;
}

/// Collect a vector-of-strings form into a `[][]const u8`. Non-vectors and
/// non-string elements are skipped (a malformed `:paths` yields the strings
/// it can, matching v0's lenient parse).
fn collectStringVec(allocator: std.mem.Allocator, v: Form) ![]const []const u8 {
    const elems = switch (v.data) {
        .vector => |e| e,
        else => return &.{},
    };
    var out: std.ArrayList([]const u8) = .empty;
    for (elems) |e| switch (e.data) {
        .string => |s| try out.append(allocator, s),
        else => {},
    };
    return out.toOwnedSlice(allocator);
}

test "parse: :paths only" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const cfg = try parseDepsEdn(arena.allocator(), "{:paths [\"src\" \"resources\"]}");
    try testing.expectEqual(@as(usize, 2), cfg.paths.len);
    try testing.expectEqualStrings("src", cfg.paths[0]);
    try testing.expectEqualStrings("resources", cfg.paths[1]);
}
