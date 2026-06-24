// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.lang.Character` static methods.
//!
//! Backend: impl-only
//! Impl deps: charset
//! Clojure peer: none
//!
//! Thin wrapper over the single-codepoint classification + case-folding
//! helpers in the neutral `runtime/charset.zig` leaf (F-009). isDigit /
//! isLetter / isWhitespace return bool; toUpperCase / toLowerCase return
//! a char (non-letters unchanged); digit returns the radix digit value
//! or -1. Classification + case folding are ASCII-only, matching cljw's
//! existing string case behaviour (D-057 Unicode caveat); the JVM uses
//! full Unicode tables, so a non-ASCII codepoint diverges (recorded).
//! The arg is a cljw `.char` Value (built with `(char N)` / a `\x`
//! literal); a non-char arg is a type error.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const string_collection = @import("../../collection/string.zig");
const java_array = @import("../../collection/java_array.zig");
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const charset = @import("../../charset.zig");

/// Extract the codepoint from a `.char` arg, else a type error.
fn argChar(v: Value, fn_name: []const u8, loc: SourceLocation) anyerror!u21 {
    if (v.tag() != .char)
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = fn_name, .expected = "char", .actual = @tagName(v.tag()) });
    return v.asChar();
}

/// `Character/isDigit` / `isLetter` / `isWhitespace`: classify a char,
/// return a bool. JVM reference: java.lang.Character#is*.
fn Classify(comptime name: []const u8, comptime f: fn (u21) bool) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = rt;
            _ = env;
            try error_catalog.checkArity("Character/" ++ name, args, 1, loc);
            const cp = try argChar(args[0], "Character/" ++ name, loc);
            return if (f(cp)) .true_val else .false_val;
        }
    };
}

/// `Character/toUpperCase` / `toLowerCase`: fold a char's case, return a
/// char (non-letters unchanged). JVM reference: java.lang.Character#to*Case.
fn CaseFold(comptime name: []const u8, comptime f: fn (u21) u21) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = rt;
            _ = env;
            try error_catalog.checkArity("Character/" ++ name, args, 1, loc);
            const cp = try argChar(args[0], "Character/" ++ name, loc);
            return Value.initChar(f(cp));
        }
    };
}

/// Implements `(Character/digit ch radix)`. Spec: the value of `ch` as a
/// digit in `radix` (0-9 then a-z/A-Z = 10-35), or -1 if it is not such a
/// digit or radix is outside 2..36. JVM reference: java.lang.Character#digit.
/// cw v1 tier: A (§A26 clj differential sweep).
fn digit(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/digit", args, 2, loc);
    const cp = try argChar(args[0], "Character/digit", loc);
    const r = try error_catalog.expectInteger(args[1], "Character/digit", loc);
    if (r < 2 or r > 36) return Value.initInteger(-1);
    const v = charset.digitValue(cp, @intCast(r)) orelse return Value.initInteger(-1);
    return Value.initInteger(@as(i64, v));
}

/// Implements `(Character/getNumericValue ch)`. Spec: the numeric value of
/// `ch` (digits `0`-`9`, letters `a`-`z`/`A`-`Z` = 10-35), or -1 if none
/// (ASCII subset; D-057 Unicode caveat). JVM ref: Character#getNumericValue.
fn getNumericValue(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/getNumericValue", args, 1, loc);
    const cp = try argChar(args[0], "Character/getNumericValue", loc);
    const v = charset.digitValue(cp, 36) orelse return Value.initInteger(-1);
    return Value.initInteger(@as(i64, v));
}

/// Implements `(Character/forDigit d radix)`. Spec: the char for digit value
/// `d` in `radix` (`0`-`9` then `a`-`z`), or `\0` when out of range. JVM
/// ref: Character#forDigit.
fn forDigit(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/forDigit", args, 2, loc);
    const d = try error_catalog.expectInteger(args[0], "Character/forDigit", loc);
    const r = try error_catalog.expectInteger(args[1], "Character/forDigit", loc);
    if (d < 0 or d > 255 or r < 0 or r > 255) return Value.initChar(0);
    return Value.initChar(charset.forDigit(@intCast(d), @intCast(r)));
}

/// `(Character/codePointAt text index)` — the codepoint at `index`. cljw
/// chars ARE codepoints (no UTF-16 surrogates), so for a native string this
/// is the D-217 codepoint indexer; a CharSequence deftype (instaparse's
/// Segment) dispatches its `.charAt`. Index semantics are cljw's
/// codepoint-based indexing (the string_indexed divergence family).
fn codePointAt(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("Character/codePointAt", args, 2, loc);
    const idx = try error_catalog.expectInteger(args[1], "Character/codePointAt", loc);
    const text = args[0];
    if (text.tag() == .string) {
        const sbytes = string_collection.asString(text);
        if (idx >= 0) {
            if (string_collection.codepointAt(sbytes, @intCast(idx))) |cp| {
                return Value.initInteger(@intCast(cp));
            }
        }
        return error_catalog.raise(.index_out_of_range, loc, .{ .fn_name = "Character/codePointAt" });
    }
    // CharSequence deftype: dispatch its charAt; the char IS the codepoint.
    const td_of: ?*const type_descriptor.TypeDescriptor = switch (text.tag()) {
        .typed_instance => text.decodePtr(*const type_descriptor.TypedInstance).descriptor,
        .reified_instance => text.decodePtr(*const type_descriptor.ReifiedInstance).descriptor,
        else => null,
    };
    if (td_of) |t| {
        if (t.lookupMethod(null, "charAt")) |me| {
            const vt = rt.vtable orelse return error.NoVTable;
            const c = try vt.callFn(rt, env, me.method_val, &.{ text, args[1] }, loc);
            if (c.tag() == .char) return Value.initInteger(@intCast(c.asChar()));
            return c;
        }
    }
    return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "Character/codePointAt", .expected = "CharSequence", .actual = @tagName(text.tag()) });
}

/// `(Character/toChars cp)` — a char array for the codepoint. cljw chars are
/// codepoints, so this is always a 1-element array (the JVM's surrogate-pair
/// 2-element case cannot arise).
fn toChars(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("Character/toChars", args, 1, loc);
    const cp = try error_catalog.expectInteger(args[0], "Character/toChars", loc);
    if (cp < 0 or cp > 0x10FFFF) {
        return error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = "Character/toChars", .expected = "valid codepoint", .actual = "out-of-range int" });
    }
    return java_array.fromSlice(rt, &.{Value.initChar(@intCast(cp))});
}

/// Codepoint from a `.char` OR an `.integer` — Java's `int codePoint` overloads
/// (e.g. `(Character/isAlphabetic (int \a))`).
fn argCodepoint(v: Value, fn_name: []const u8, loc: SourceLocation) anyerror!u21 {
    return switch (v.tag()) {
        .char => v.asChar(),
        .integer => blk: {
            const i = v.asInteger();
            if (i < 0 or i > 0x10FFFF)
                return error_catalog.raise(.index_out_of_range, loc, .{ .fn_name = fn_name });
            break :blk @intCast(i);
        },
        else => error_catalog.raise(.type_arg_invalid, loc, .{ .fn_name = fn_name, .expected = "char or codepoint int", .actual = @tagName(v.tag()) }),
    };
}

/// `(Character/isAlphabetic cp)` — whether the codepoint is a letter. Java's
/// isAlphabetic also admits LETTER_NUMBER (rare); cljw uses the letter
/// predicate, which matches for the common surface. Takes a char or an int.
fn isAlphabetic(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/isAlphabetic", args, 1, loc);
    const cp = try argCodepoint(args[0], "Character/isAlphabetic", loc);
    return if (charset.isLetterCodepoint(cp)) .true_val else .false_val;
}

/// `(Character/toString c)` — a one-char string. JVM Character.toString(char).
fn toStringChar(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("Character/toString", args, 1, loc);
    const cp = try argChar(args[0], "Character/toString", loc);
    var buf: [4]u8 = undefined;
    const n = std.unicode.utf8Encode(cp, &buf) catch
        return error_catalog.raise(.index_out_of_range, loc, .{ .fn_name = "Character/toString" });
    return string_collection.alloc(rt, buf[0..n]);
}

// Surrogate / control range predicates over a UTF-16 code unit. cljw chars
// ARE codepoints, so a surrogate value (0xD800..0xDFFF) is held numerically
// even though it is not a standalone Unicode scalar — the range tests still
// hold. These functions take a char OR an int (argCodepoint).
fn isSurrogateCp(cp: u21) bool {
    return cp >= 0xD800 and cp <= 0xDFFF;
}
fn isHighSurrogateCp(cp: u21) bool {
    return cp >= 0xD800 and cp <= 0xDBFF;
}
fn isLowSurrogateCp(cp: u21) bool {
    return cp >= 0xDC00 and cp <= 0xDFFF;
}
fn isISOControlCp(cp: u21) bool {
    return cp <= 0x1F or (cp >= 0x7F and cp <= 0x9F);
}

/// `Character/isSurrogate` / `isHighSurrogate` / `isLowSurrogate` /
/// `isISOControl` — boolean range tests over a char-or-int codepoint.
fn CpPred(comptime name: []const u8, comptime f: fn (u21) bool) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = rt;
            _ = env;
            try error_catalog.checkArity("Character/" ++ name, args, 1, loc);
            const cp = try argCodepoint(args[0], "Character/" ++ name, loc);
            return if (f(cp)) .true_val else .false_val;
        }
    };
}

// Codepoint validity predicates over a raw `int` (any value, so an
// out-of-codepoint-range int is simply `false` rather than a range error —
// `argCodepoint` would reject it). JVM reference: java.lang.Character.
fn isBmpCp(cp: i64) bool {
    return cp >= 0 and cp <= 0xFFFF;
}
fn isValidCp(cp: i64) bool {
    return cp >= 0 and cp <= 0x10FFFF;
}
fn isSupplementaryCp(cp: i64) bool {
    return cp >= 0x10000 and cp <= 0x10FFFF;
}

/// `Character/isBmpCodePoint` / `isValidCodePoint` / `isSupplementaryCodePoint`
/// — boolean tests over a raw `int` codepoint (no range error).
fn IntCpPred(comptime name: []const u8, comptime f: fn (i64) bool) type {
    return struct {
        fn call(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = rt;
            _ = env;
            try error_catalog.checkArity("Character/" ++ name, args, 1, loc);
            const cp = try error_catalog.expectInteger(args[0], "Character/" ++ name, loc);
            return if (f(cp)) .true_val else .false_val;
        }
    };
}

/// `(Character/charCount cp)` — UTF-16 code units for `cp`: 2 for a
/// supplementary codepoint (≥ 0x10000), else 1. JVM ref: Character#charCount.
fn charCount(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/charCount", args, 1, loc);
    const cp = try error_catalog.expectInteger(args[0], "Character/charCount", loc);
    return Value.initInteger(if (cp >= 0x10000) 2 else 1);
}

/// `(Character/highSurrogate cp)` / `lowSurrogate cp` — the high / low UTF-16
/// surrogate char for a supplementary codepoint, via Java's bit formulas
/// (`(cp >>> 10) + 0xD7C0` and `(cp & 0x3FF) + 0xDC00`). JVM reference:
/// java.lang.Character#highSurrogate / #lowSurrogate.
fn highSurrogate(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/highSurrogate", args, 1, loc);
    const cp: u64 = @bitCast(@as(i64, try error_catalog.expectInteger(args[0], "Character/highSurrogate", loc)));
    return Value.initChar(@as(u16, @truncate((cp >> 10) + 0xD7C0)));
}
fn lowSurrogate(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/lowSurrogate", args, 1, loc);
    const cp: u64 = @bitCast(@as(i64, try error_catalog.expectInteger(args[0], "Character/lowSurrogate", loc)));
    return Value.initChar(@as(u16, @truncate((cp & 0x3FF) + 0xDC00)));
}

/// `(Character/toCodePoint high low)` — combine a high + low surrogate char
/// pair into the supplementary codepoint. JVM ref: Character#toCodePoint.
fn toCodePoint(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/toCodePoint", args, 2, loc);
    const high = try argCodepoint(args[0], "Character/toCodePoint", loc);
    const low = try argCodepoint(args[1], "Character/toCodePoint", loc);
    const cp: i64 = 0x10000 + (@as(i64, high) - 0xD800) * 1024 + (@as(i64, low) - 0xDC00);
    return Value.initInteger(cp);
}

/// `(Character/isSurrogatePair high low)` — `high` is a high surrogate AND
/// `low` is a low surrogate. JVM reference: Character#isSurrogatePair.
fn isSurrogatePair(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/isSurrogatePair", args, 2, loc);
    const high = try argCodepoint(args[0], "Character/isSurrogatePair", loc);
    const low = try argCodepoint(args[1], "Character/isSurrogatePair", loc);
    return if (isHighSurrogateCp(high) and isLowSurrogateCp(low)) .true_val else .false_val;
}

/// `(Character/hashCode c)` — Java returns the char's codepoint as an int.
/// JVM reference: java.lang.Character#hashCode.
fn hashCode(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    try error_catalog.checkArity("Character/hashCode", args, 1, loc);
    const cp = try argChar(args[0], "Character/hashCode", loc);
    return Value.initInteger(@as(i64, cp));
}

fn initCharacter(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const specs = .{
        .{ "isDigit", &Classify("isDigit", charset.isDigitCodepoint).call },
        .{ "isLetter", &Classify("isLetter", charset.isLetterCodepoint).call },
        .{ "isLetterOrDigit", &Classify("isLetterOrDigit", charset.isLetterOrDigitCodepoint).call },
        .{ "isWhitespace", &Classify("isWhitespace", charset.isWhitespaceCodepoint).call },
        .{ "isUpperCase", &Classify("isUpperCase", charset.isUpperCodepoint).call },
        .{ "isLowerCase", &Classify("isLowerCase", charset.isLowerCodepoint).call },
        .{ "toUpperCase", &CaseFold("toUpperCase", charset.toUpperCodepoint).call },
        .{ "toLowerCase", &CaseFold("toLowerCase", charset.toLowerCodepoint).call },
        .{ "digit", &digit },
        .{ "getNumericValue", &getNumericValue },
        .{ "forDigit", &forDigit },
        .{ "codePointAt", &codePointAt },
        .{ "toChars", &toChars },
        .{ "isAlphabetic", &isAlphabetic },
        .{ "toString", &toStringChar },
        .{ "charCount", &charCount },
        .{ "isSurrogate", &CpPred("isSurrogate", isSurrogateCp).call },
        .{ "isHighSurrogate", &CpPred("isHighSurrogate", isHighSurrogateCp).call },
        .{ "isLowSurrogate", &CpPred("isLowSurrogate", isLowSurrogateCp).call },
        .{ "isISOControl", &CpPred("isISOControl", isISOControlCp).call },
        .{ "isBmpCodePoint", &IntCpPred("isBmpCodePoint", isBmpCp).call },
        .{ "isValidCodePoint", &IntCpPred("isValidCodePoint", isValidCp).call },
        .{ "isSupplementaryCodePoint", &IntCpPred("isSupplementaryCodePoint", isSupplementaryCp).call },
        .{ "highSurrogate", &highSurrogate },
        .{ "lowSurrogate", &lowSurrogate },
        .{ "toCodePoint", &toCodePoint },
        .{ "isSurrogatePair", &isSurrogatePair },
        .{ "hashCode", &hashCode },
    };
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
}

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.lang.Character",
    .descriptor = &descriptor,
    .init = &initCharacter,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.lang.Character",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
