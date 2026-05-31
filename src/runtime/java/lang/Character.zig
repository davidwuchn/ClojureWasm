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

fn initCharacter(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
    if (td.method_table.len != 0) return; // idempotent re-run
    const specs = .{
        .{ "isDigit", &Classify("isDigit", charset.isDigitCodepoint).call },
        .{ "isLetter", &Classify("isLetter", charset.isLetterCodepoint).call },
        .{ "isWhitespace", &Classify("isWhitespace", charset.isWhitespaceCodepoint).call },
        .{ "toUpperCase", &CaseFold("toUpperCase", charset.toUpperCodepoint).call },
        .{ "toLowerCase", &CaseFold("toLowerCase", charset.toLowerCodepoint).call },
        .{ "digit", &digit },
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
