// SPDX-License-Identifier: EPL-2.0
//! UUID v4 generation + parsing — namespace-neutral implementation
//! per F-009.
//!
//! Two surfaces consume this file:
//!   1. `lang/primitive/uuid.zig` — Clojure-ns peer (`random-uuid`
//!      / `parse-uuid` in clojure.core).
//!   2. `runtime/java/util/UUID.zig` — Java surface
//!      (`(java.util.UUID/randomUUID)` etc.).
//!
//! Both call into `generateV4(...)` / `format(...)` / `parse(...)`
//! here; neither knows about the other. F-009's "neutral impl,
//! surfaces are thin wrappers" applies.

const std = @import("std");

/// 16-byte UUID payload (RFC 4122 big-endian field order).
pub const Bytes = [16]u8;

/// 36-character lowercase canonical form (`8-4-4-4-12`).
pub const Canonical = [36]u8;

/// Generate a random UUID v4 byte sequence. Sets the version
/// (`bytes[6] = (bytes[6] & 0x0F) | 0x40`) and variant
/// (`bytes[8] = (bytes[8] & 0x3F) | 0x80`) per RFC 4122.
///
/// Phase 6 takes an `std.Io` so the caller chooses between
/// `std.Io.randomSecure` (kernel CSPRNG via getrandom) and
/// `std.Io.random` (fast PRNG fallback). Per F-006 + ADR-0015
/// Tier 1/2 split, the io handle is the single point of
/// pluggability; an `io_interface`-mediated random source can
/// land later if the abstraction grows.
pub fn generateV4(io: std.Io) Bytes {
    var b: Bytes = undefined;
    std.Io.randomSecure(io, &b) catch std.Io.random(io, &b);
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    return b;
}

/// Format a 16-byte UUID as the canonical lowercase 36-char form.
pub fn format(b: Bytes) Canonical {
    var out: Canonical = undefined;
    const hex = "0123456789abcdef";
    var oi: usize = 0;
    for (b, 0..) |byte, i| {
        out[oi] = hex[byte >> 4];
        out[oi + 1] = hex[byte & 0x0F];
        oi += 2;
        if (i == 3 or i == 5 or i == 7 or i == 9) {
            out[oi] = '-';
            oi += 1;
        }
    }
    return out;
}

pub const ParseError = error{InvalidUuid};

/// Parse a 36-char canonical UUID string back into its 16 bytes.
/// Returns `error.InvalidUuid` on length / hyphen-position / hex-
/// digit failures. Accepts upper- or lower-case hex digits.
pub fn parse(s: []const u8) ParseError!Bytes {
    if (s.len != 36) return error.InvalidUuid;
    if (s[8] != '-' or s[13] != '-' or s[18] != '-' or s[23] != '-')
        return error.InvalidUuid;
    var b: Bytes = undefined;
    var si: usize = 0;
    var bi: usize = 0;
    while (bi < 16) : (bi += 1) {
        if (si == 8 or si == 13 or si == 18 or si == 23) si += 1;
        const hi = nibble(s[si]) catch return error.InvalidUuid;
        const lo = nibble(s[si + 1]) catch return error.InvalidUuid;
        b[bi] = (hi << 4) | lo;
        si += 2;
    }
    return b;
}

fn nibble(c: u8) ParseError!u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidUuid,
    };
}

// --- tests ---

const testing = std.testing;

test "generateV4 sets version=4 (high nibble of byte 6) and variant=10xx (high bits of byte 8)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    const b = generateV4(th.io());
    try testing.expectEqual(@as(u8, 0x40), b[6] & 0xF0);
    try testing.expectEqual(@as(u8, 0x80), b[8] & 0xC0);
}

test "format produces 36 chars with hyphens at the right positions" {
    const b: Bytes = .{ 0x12, 0x34, 0x56, 0x78, 0xab, 0xcd, 0x4e, 0xf0, 0x80, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde };
    const s = format(b);
    try testing.expectEqualStrings("12345678-abcd-4ef0-8012-3456789abcde", &s);
}

test "parse round-trips a canonical UUID" {
    const b: Bytes = .{ 0x12, 0x34, 0x56, 0x78, 0xab, 0xcd, 0x4e, 0xf0, 0x80, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde };
    const s = format(b);
    const parsed = try parse(&s);
    try testing.expectEqualSlices(u8, &b, &parsed);
}

test "parse rejects wrong length" {
    try testing.expectError(error.InvalidUuid, parse("too short"));
    try testing.expectError(error.InvalidUuid, parse("12345678-abcd-4ef0-8012-3456789abcdex"));
}

test "parse rejects wrong hyphen positions" {
    try testing.expectError(error.InvalidUuid, parse("12345678xabcd-4ef0-8012-3456789abcde"));
}
