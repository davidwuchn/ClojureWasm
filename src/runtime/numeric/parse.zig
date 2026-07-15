// SPDX-License-Identifier: EPL-2.0
//! Java/Clojure-compatible numeric string parsing (neutral leaf).
//!
//! The single integer-parse mechanism shared by the Clojure-ns
//! `parse-long` primitive and the Java-ns `Integer/parseInt` /
//! `Long/parseLong` statics (F-009 neutral home, F-011 DRY). Surfaces
//! map the error to `nil` (Clojure `parse-*`) or NumberFormatException
//! (Java `parse*`); the acceptance rule lives here, in one place.
//!
//! Zig's `std.fmt.parseInt` accepts `_` digit separators (`1_000`) that
//! Java `Integer.parseInt` and Clojure `parse-long` both reject —
//! `(parse-long "1_000")` is `nil` in real Clojure. This leaf rejects
//! the underscore so every surface matches the oracle; everything else
//! (optional leading `+`/`-`, no surrounding whitespace) already agrees
//! between Zig and Java/Clojure.

const std = @import("std");

/// The single error a malformed numeric string yields. Surfaces decide
/// whether it becomes `nil` or a thrown NumberFormatException.
pub const ParseError = error{InvalidNumberFormat};

/// Parse a signed integer of type `T` from `s` in `radix`, matching
/// Java/Clojure acceptance. `T` is the surface's value range:
/// `i32` for `Integer/parseInt` (out-of-int-range string ⇒ error, as
/// real clj throws), `i64` for `Long/parseLong` and `parse-long`.
pub fn parseSigned(comptime T: type, s: []const u8, radix: u8) ParseError!T {
    if (std.mem.findScalar(u8, s, '_') != null) return error.InvalidNumberFormat;
    return std.fmt.parseInt(T, s, radix) catch error.InvalidNumberFormat;
}

/// Parse an UNSIGNED integer of type `T` from `s` in `radix`, matching Java's
/// `Integer.parseUnsignedInt` / `Long.parseUnsignedLong`: the full unsigned
/// range parses (so `"18446744073709551615"` is a valid `u64`), and the
/// surface bitcasts the result to the signed width before boxing. Underscores
/// are rejected as for `parseSigned`.
pub fn parseUnsigned(comptime T: type, s: []const u8, radix: u8) ParseError!T {
    if (std.mem.findScalar(u8, s, '_') != null) return error.InvalidNumberFormat;
    return std.fmt.parseUnsigned(T, s, radix) catch error.InvalidNumberFormat;
}

/// Parse an f64 from `s`, matching Java's `Double.parseDouble`
/// (FloatingDecimal grammar): surrounding whitespace TRIMMED
/// (`String.trim`), optional sign + EXACT-case `Infinity` / `NaN`
/// (lowercase `inf`/`nan`/`infinity` reject, unlike Zig's lenient
/// parser), an optional trailing `d`/`D`/`f`/`F` suffix on numeric
/// forms, and hex floats (`0x1.8p1`). Underscores reject as for
/// integers.
pub fn parseFloat(s: []const u8) ParseError!f64 {
    if (std.mem.findScalar(u8, s, '_') != null) return error.InvalidNumberFormat;
    const trimmed = std.mem.trim(u8, s, &std.ascii.whitespace);
    if (trimmed.len == 0) return error.InvalidNumberFormat;
    var body = trimmed;
    var neg = false;
    if (body[0] == '+' or body[0] == '-') {
        neg = body[0] == '-';
        body = body[1..];
    }
    if (std.mem.eql(u8, body, "Infinity"))
        return if (neg) -std.math.inf(f64) else std.math.inf(f64);
    if (std.mem.eql(u8, body, "NaN")) return std.math.nan(f64);
    // Numeric forms may carry one trailing d/D/f/F (incl. hex floats).
    var num = trimmed;
    if (num.len >= 2) switch (num[num.len - 1]) {
        'd', 'D', 'f', 'F' => num = num[0 .. num.len - 1],
        else => {},
    };
    // Every remaining valid form starts (post-sign) with a digit or '.'
    // — this is what rejects Zig's lenient `inf` / `nan` spellings.
    var chk = num;
    if (chk.len > 0 and (chk[0] == '+' or chk[0] == '-')) chk = chk[1..];
    if (chk.len == 0 or !(std.ascii.isDigit(chk[0]) or chk[0] == '.'))
        return error.InvalidNumberFormat;
    // Java's hex-float grammar REQUIRES the binary exponent (`0x1f`
    // rejects, `0x1fp0` parses); Zig's parser would accept the bare form.
    if (chk.len > 1 and chk[0] == '0' and (chk[1] == 'x' or chk[1] == 'X')) {
        if (std.mem.findAny(u8, chk[2..], "pP") == null) return error.InvalidNumberFormat;
    }
    return std.fmt.parseFloat(f64, num) catch error.InvalidNumberFormat;
}

const testing = std.testing;

test "parseSigned base-10 accepts sign, rejects underscore + whitespace" {
    try testing.expectEqual(@as(i64, 42), try parseSigned(i64, "42", 10));
    try testing.expectEqual(@as(i64, -10), try parseSigned(i64, "-10", 10));
    try testing.expectEqual(@as(i64, 5), try parseSigned(i64, "+5", 10));
    try testing.expectError(error.InvalidNumberFormat, parseSigned(i64, "1_000", 10));
    try testing.expectError(error.InvalidNumberFormat, parseSigned(i64, " 5", 10));
    try testing.expectError(error.InvalidNumberFormat, parseSigned(i64, "abc", 10));
}

test "parseSigned honours radix" {
    try testing.expectEqual(@as(i32, 255), try parseSigned(i32, "ff", 16));
    try testing.expectEqual(@as(i32, 8), try parseSigned(i32, "10", 8));
}

test "parseSigned i32 range models Java int overflow" {
    // 9999999999 fits i64 but not i32 — real clj (Integer/parseInt) throws.
    try testing.expectError(error.InvalidNumberFormat, parseSigned(i32, "9999999999", 10));
    try testing.expectEqual(@as(i64, 9999999999), try parseSigned(i64, "9999999999", 10));
}

test "parseUnsigned covers the full unsigned range + honours radix" {
    try testing.expectEqual(@as(u64, std.math.maxInt(u64)), try parseUnsigned(u64, "18446744073709551615", 10));
    try testing.expectEqual(@as(u32, std.math.maxInt(u32)), try parseUnsigned(u32, "4294967295", 10));
    try testing.expectEqual(@as(u64, 255), try parseUnsigned(u64, "ff", 16));
    // A leading '-' is not an unsigned number; underscore still rejected.
    try testing.expectError(error.InvalidNumberFormat, parseUnsigned(u64, "-1", 10));
    try testing.expectError(error.InvalidNumberFormat, parseUnsigned(u32, "1_0", 10));
}

test "parseFloat trims whitespace + rejects underscore, accepts specials" {
    try testing.expectEqual(@as(f64, 3.14), try parseFloat("3.14"));
    try testing.expectEqual(@as(f64, 3.14), try parseFloat("  3.14\t")); // Java trims
    try testing.expect(std.math.isPositiveInf(try parseFloat("Infinity")));
    try testing.expect(std.math.isNegativeInf(try parseFloat("-Infinity")));
    try testing.expect(std.math.isNan(try parseFloat("NaN")));
    try testing.expectError(error.InvalidNumberFormat, parseFloat("1_0.5"));
    try testing.expectError(error.InvalidNumberFormat, parseFloat("x"));
    try testing.expectError(error.InvalidNumberFormat, parseFloat(""));
}
