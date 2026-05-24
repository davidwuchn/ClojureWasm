// SPDX-License-Identifier: EPL-2.0
//! UTF-8 charset helpers per ADR-0014 (cw v1 internal string is
//! UTF-8). Namespace-neutral implementation per F-009.
//!
//! cw v1 stores all strings as `[]const u8` byte slices in UTF-8.
//! Clojure-level `count` / `subs` / `nth` over strings need
//! codepoint-aware indexing because users expect "あいう" to be
//! 3 chars, not 9. This file provides the bytes ↔ codepoint mapping.
//!
//! Surfaces (Phase 6+):
//!   - `lang/primitive/string.zig` — clojure.core `count` / `subs` /
//!     `nth` over string. Lands at 6.9 alongside clojure.string.
//!   - `runtime/java/nio/charset/Charset.zig` — Phase 14+ surface
//!     for `Charset.forName("UTF-8")` etc. The Java legacy
//!     `String#charAt` semantics (UTF-16 code unit) is **not**
//!     supported in cw v1; Java surface returns codepoint-based
//!     positions instead (ADR-0014 D-014a).

const std = @import("std");

pub const Utf8Error = error{InvalidUtf8};

/// Count codepoints in `s`. Returns `InvalidUtf8` on malformed
/// input — std.unicode.utf8CountCodepoints already does the
/// validation pass.
pub fn codepointCount(s: []const u8) Utf8Error!usize {
    return std.unicode.utf8CountCodepoints(s) catch error.InvalidUtf8;
}

/// Codepoint at index `i` (0-based). `InvalidUtf8` on malformed
/// input; `error.IndexOutOfBounds` when `i >= codepointCount(s)`.
pub fn codepointAt(s: []const u8, i: usize) (Utf8Error || error{IndexOutOfBounds})!u21 {
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    var n: usize = 0;
    while (iter.nextCodepoint()) |cp| {
        if (n == i) return cp;
        n += 1;
    }
    return error.IndexOutOfBounds;
}

/// Byte slice from codepoint index `start` (inclusive) to `end`
/// (exclusive). Returns the empty slice when `start == end`.
pub fn substring(s: []const u8, start: usize, end: usize) Utf8Error![]const u8 {
    std.debug.assert(start <= end);
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    var n: usize = 0;
    var byte_start: usize = 0;
    var byte_end: usize = s.len;
    var found_start = false;
    while (true) {
        if (n == start) {
            byte_start = iter.i;
            found_start = true;
        }
        if (n == end) {
            byte_end = iter.i;
            break;
        }
        if (iter.nextCodepoint() == null) {
            if (!found_start) byte_start = iter.i;
            byte_end = iter.i;
            break;
        }
        n += 1;
    }
    return s[byte_start..byte_end];
}

// --- tests ---

const testing = std.testing;

test "codepointCount on ASCII matches byte length" {
    try testing.expectEqual(@as(usize, 5), try codepointCount("hello"));
}

test "codepointCount on multibyte UTF-8" {
    try testing.expectEqual(@as(usize, 3), try codepointCount("あいう"));
    try testing.expectEqual(@as(usize, 5), try codepointCount("aあbいc"));
}

test "codepointAt returns the right codepoint at an offset" {
    const s = "aあbいc";
    try testing.expectEqual(@as(u21, 'a'), try codepointAt(s, 0));
    try testing.expectEqual(@as(u21, 0x3042), try codepointAt(s, 1)); // あ
    try testing.expectEqual(@as(u21, 'b'), try codepointAt(s, 2));
    try testing.expectEqual(@as(u21, 0x3044), try codepointAt(s, 3)); // い
    try testing.expectEqual(@as(u21, 'c'), try codepointAt(s, 4));
}

test "codepointAt out-of-bounds raises" {
    try testing.expectError(error.IndexOutOfBounds, codepointAt("ab", 5));
}

test "substring slices on codepoint boundaries" {
    const s = "aあbいc";
    try testing.expectEqualStrings("a", try substring(s, 0, 1));
    try testing.expectEqualStrings("あb", try substring(s, 1, 3));
    try testing.expectEqualStrings("いc", try substring(s, 3, 5));
    try testing.expectEqualStrings("", try substring(s, 2, 2));
}
