// SPDX-License-Identifier: EPL-2.0
//! `application/x-www-form-urlencoded` percent-encoding — the
//! `java.net.URLEncoder/encode` surface impl (keyword `url_encode`).
//!
//! Unreserved bytes (`A-Z a-z 0-9 - _ . *`) pass through, space becomes `+`,
//! every other byte is `%XX` (uppercase hex of the UTF-8 byte). This matches
//! java.net.URLEncoder under a UTF-8 charset, which is the only charset cljw
//! supports (the encoding arg is validated but otherwise UTF-8 is assumed).

const std = @import("std");

/// Append the URL-encoded form of `s` to `out` (allocated through `gpa`).
pub fn encode(gpa: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (s) |b| {
        if (std.ascii.isAlphanumeric(b) or b == '-' or b == '_' or b == '.' or b == '*') {
            try out.append(gpa, b);
        } else if (b == ' ') {
            try out.append(gpa, '+');
        } else {
            try out.append(gpa, '%');
            try out.append(gpa, hex[b >> 4]);
            try out.append(gpa, hex[b & 0x0F]);
        }
    }
}

const testing = std.testing;

test "encode: unreserved pass-through, space to plus, reserved percent" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try encode(testing.allocator, &out, "a b&c");
    try testing.expectEqualStrings("a+b%26c", out.items);
}

test "encode: keeps -_.* and alnum" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try encode(testing.allocator, &out, "a-b_c.d*e9Z");
    try testing.expectEqualStrings("a-b_c.d*e9Z", out.items);
}

test "encode: multibyte UTF-8 percent-encodes each byte" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try encode(testing.allocator, &out, "\u{00e9}"); // é = C3 A9
    try testing.expectEqualStrings("%C3%A9", out.items);
}
