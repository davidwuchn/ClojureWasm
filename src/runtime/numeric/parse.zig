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

/// Parse an f64 from `s`, matching Java/Clojure `Double.parseDouble` /
/// `parse-double`. Unlike integer parsing, Java's `Double.parseDouble`
/// TRIMS surrounding whitespace (via `String.trim`), so `(parse-double
/// " 3.14 ")` is `3.14` in real clj — Zig's bare `parseFloat` would
/// reject it. Underscores are rejected as for integers. Zig already
/// accepts the `Infinity` / `-Infinity` / `NaN` spellings clj uses.
///
/// Known residual divergence (recorded, not fixed): Zig's `parseFloat`
/// also accepts the lenient `inf` / `nan` / `infinity` spellings that
/// Java rejects, and rejects Java's trailing `d`/`f` suffix + hex
/// floats — matching Java's full FloatingDecimal grammar is
/// disproportionate for those rare edges.
pub fn parseFloat(s: []const u8) ParseError!f64 {
    if (std.mem.findScalar(u8, s, '_') != null) return error.InvalidNumberFormat;
    const trimmed = std.mem.trim(u8, s, &std.ascii.whitespace);
    return std.fmt.parseFloat(f64, trimmed) catch error.InvalidNumberFormat;
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
