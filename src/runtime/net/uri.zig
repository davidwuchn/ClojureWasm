// SPDX-License-Identifier: EPL-2.0
//! Minimal URI string parsing — the `java.net.URI` surface impl (keyword `uri`).
//!
//! Scope: scheme / authority-host / path extraction, which is exactly what
//! hiccup.util's `ToString` / `ToURI` protocols read (`.getHost`, `.getPath`,
//! `str`). This is NOT a full RFC 3986 parser — no query/fragment accessors, no
//! userinfo/percent decoding; the surface raises `feature_not_supported` for any
//! accessor not covered here rather than silently returning a wrong value
//! (permanent-no-op forbidden).
//!
//! All functions are pure slices into the input `uri` (no allocation); the
//! surface owns the backing bytes (gpa-duped into the host_instance).

const std = @import("std");

/// Index of the `//` that opens the authority component, or null when the URI
/// has no authority. `//` qualifies only at the very start (scheme-relative) or
/// immediately after a `scheme:` prefix.
fn authoritySlashes(uri: []const u8) ?usize {
    const d = std.mem.find(u8, uri, "//") orelse return null;
    if (d != 0 and uri[d - 1] != ':') return null;
    return d;
}

/// The authority substring (`[userinfo@]host[:port]`), or null when absent.
fn authority(uri: []const u8) ?[]const u8 {
    const d = authoritySlashes(uri) orelse return null;
    const after = uri[d + 2 ..];
    for (after, 0..) |c, i| {
        if (c == '/' or c == '?' or c == '#') return after[0..i];
    }
    return after;
}

/// Index of the scheme-terminating `:`, or null when `uri` has no scheme.
/// Scheme grammar: `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )` then `:`.
fn schemeColon(uri: []const u8) ?usize {
    if (uri.len == 0 or !std.ascii.isAlphabetic(uri[0])) return null;
    for (uri, 0..) |c, i| {
        if (c == ':') return i;
        if (c == '/' or c == '?' or c == '#') return null;
        if (i > 0 and !(std.ascii.isAlphanumeric(c) or c == '+' or c == '-' or c == '.')) return null;
    }
    return null;
}

/// The host component, or null when the URI has no `//authority`. Strips an
/// optional `userinfo@` prefix and `:port` suffix.
pub fn host(uri: []const u8) ?[]const u8 {
    var a = authority(uri) orelse return null;
    if (std.mem.findScalar(u8, a, '@')) |at| a = a[at + 1 ..];
    if (std.mem.findScalarLast(u8, a, ':')) |colon| a = a[0..colon];
    if (a.len == 0) return null;
    return a;
}

/// The path component, or null for an opaque URI (`scheme:` with a non-`/`
/// body, e.g. `mailto:x`). A URI with authority returns the path after the
/// authority (`""` when none); a relative reference returns the whole string
/// up to `?`/`#`.
pub fn path(uri: []const u8) ?[]const u8 {
    if (authoritySlashes(uri)) |d| {
        // After the authority: scan past host to the first '/', then take the
        // path up to '?'/'#'.
        const after = uri[d + 2 ..];
        var ps: usize = after.len;
        for (after, 0..) |c, i| {
            if (c == '/' or c == '?' or c == '#') {
                ps = i;
                break;
            }
        }
        return upToQueryOrFragment(after[ps..]);
    }
    if (schemeColon(uri)) |c| {
        // scheme present, no authority: hierarchical (`scheme:/path`) keeps the
        // path; opaque (`scheme:body`) has a null path.
        if (c + 1 >= uri.len or uri[c + 1] != '/') return null;
        return upToQueryOrFragment(uri[c + 1 ..]);
    }
    // Pure relative reference: the whole string is the path.
    return upToQueryOrFragment(uri);
}

fn upToQueryOrFragment(s: []const u8) []const u8 {
    for (s, 0..) |c, i| {
        if (c == '?' or c == '#') return s[0..i];
    }
    return s;
}

const testing = std.testing;

test "host: absolute hierarchical" {
    try testing.expectEqualStrings("example.com", host("http://example.com/x").?);
    try testing.expectEqualStrings("example.com", host("http://u@example.com:8080/p").?);
    try testing.expectEqualStrings("a", host("http://a").?);
}

test "host: relative reference has none" {
    try testing.expect(host("/relative") == null);
    try testing.expect(host("products") == null);
    try testing.expect(host("mailto:a@b") == null);
}

test "path: absolute / relative / empty / opaque" {
    try testing.expectEqualStrings("/x", path("http://example.com/x").?);
    try testing.expectEqualStrings("/p", path("http://u@example.com:8080/p").?);
    try testing.expectEqualStrings("", path("http://a").?);
    try testing.expectEqualStrings("/relative", path("/relative").?);
    try testing.expectEqualStrings("products", path("products").?);
    try testing.expect(path("mailto:foo") == null);
}

test "path / host ignore query + fragment" {
    try testing.expectEqualStrings("/x", path("http://h/x?q=1#f").?);
    try testing.expectEqualStrings("h", host("http://h/x?q=1#f").?);
}
