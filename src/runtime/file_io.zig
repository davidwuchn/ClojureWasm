// SPDX-License-Identifier: EPL-2.0
//! Filesystem I/O primitives — namespace-neutral implementation
//! per F-009.
//!
//! Surfaces consume this:
//!   - `lang/primitive/io.zig` — `clojure.core/slurp` /
//!     `clojure.core/spit`.
//!   - `runtime/java/io/File.zig` — `java.io.File` instance
//!     methods (.exists / .length / read / write).
//!   - `runtime/java/nio/file/Files.zig` — a future surface for
//!     modern NIO methods (not yet present).
//!
//! This file covers whole-file read + write. Streaming / append-mode /
//! transactional rename are future additions.

const std = @import("std");

/// Read the entire file at `path` into a freshly-allocated byte
/// slice. Caller owns the returned slice and must free it via
/// `allocator`.
pub fn readAll(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &read_buf);
    return try file_reader.interface.allocRemaining(allocator, .unlimited);
}

/// Write `content` to `path`, replacing any existing file.
pub fn writeAll(io: std.Io, path: []const u8, content: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &write_buf);
    try file_writer.interface.writeAll(content);
    try file_writer.interface.flush();
}

/// Predicate: does `path` exist (file or directory)?
pub fn exists(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

// --- tests ---

const testing = std.testing;

test "writeAll then readAll round-trips" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    const io = th.io();

    const tmp_path = "/tmp/cljw_file_io_test_67";
    defer std.Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    try writeAll(io, tmp_path, "hello world");
    const content = try readAll(io, testing.allocator, tmp_path);
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("hello world", content);
}

test "exists distinguishes present from missing" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    const io = th.io();

    const tmp_path = "/tmp/cljw_file_io_test_exists";
    defer std.Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    try testing.expect(!exists(io, tmp_path));
    try writeAll(io, tmp_path, "x");
    try testing.expect(exists(io, tmp_path));
}
