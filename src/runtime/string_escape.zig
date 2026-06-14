// SPDX-License-Identifier: EPL-2.0
//! Clojure string-literal escape decoding (`\n \t \r \\ \" \b \f \uXXXX`),
//! shared between the reader (`eval/reader.zig`, which decodes a `"…"` token) and
//! the host `clojure.lang.LispReader$StringReader` shim (`runtime/io/`, which
//! reads a string literal char-by-char from a `*in*` reader — D-414). Lives in
//! `runtime/` so both the eval-layer reader and the runtime-layer shim can call
//! it without a zone violation (the shim must not import `eval/`).

const std = @import("std");
const error_mod = @import("error/info.zig");
const error_catalog = @import("error/catalog.zig");
const SourceLocation = error_mod.SourceLocation;
const ClojureWasmError = error_mod.ClojureWasmError;

/// Decode the escapes in `s` (the RAW bytes BETWEEN the quotes, no surrounding
/// `"`), returning a freshly-`allocator`-owned slice — or `s` itself when it
/// contains no backslash (the common no-escape fast path; caller must treat the
/// result as borrowed-or-owned accordingly, exactly as the reader always has).
pub fn unescape(allocator: std.mem.Allocator, s: []const u8, loc: SourceLocation) ClojureWasmError![]const u8 {
    if (std.mem.findScalar(u8, s, '\\') == null) return s;

    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\\') {
            i += 1;
            if (i >= s.len)
                return error_catalog.raise(.string_escape_trailing_backslash, loc, .{});
            switch (s[i]) {
                'n' => buf.append(allocator, '\n') catch return error.OutOfMemory,
                't' => buf.append(allocator, '\t') catch return error.OutOfMemory,
                'r' => buf.append(allocator, '\r') catch return error.OutOfMemory,
                '\\' => buf.append(allocator, '\\') catch return error.OutOfMemory,
                '"' => buf.append(allocator, '"') catch return error.OutOfMemory,
                'b' => buf.append(allocator, 0x08) catch return error.OutOfMemory,
                'f' => buf.append(allocator, 0x0C) catch return error.OutOfMemory,
                'u' => {
                    if (i + 4 >= s.len)
                        return error_catalog.raise(.unicode_escape_truncated, loc, .{});
                    const hex = s[i + 1 .. i + 5];
                    const cp = std.fmt.parseInt(u21, hex, 16) catch
                        return error_catalog.raise(.unicode_escape_invalid_hex, loc, .{ .hex = hex });
                    var utf8_buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(cp, &utf8_buf) catch
                        return error_catalog.raise(.unicode_codepoint_invalid, loc, .{ .hex = hex });
                    for (utf8_buf[0..len]) |b| buf.append(allocator, b) catch return error.OutOfMemory;
                    i += 4;
                },
                else => |c| return error_catalog.raise(.string_escape_unknown, loc, .{ .escape = c }),
            }
            i += 1;
        } else {
            buf.append(allocator, s[i]) catch return error.OutOfMemory;
            i += 1;
        }
    }
    return buf.toOwnedSlice(allocator) catch error.OutOfMemory;
}
