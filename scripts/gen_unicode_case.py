#!/usr/bin/env python3
"""Generate src/runtime/unicode_case.zig + unicode_category.zig from the
Unicode Character Database.

D-057 / D-409: cljw's Unicode case mapping, General_Category, bidi class,
contributory properties, and numeric values are GENERATED from the
definition (UCD 16.0.0, pinned), never hand-rolled (F-013
definition-derived coverage).

Inputs (downloaded to /tmp on each run; the OUTPUT .zig is committed):
  - UnicodeData.txt   — simple 1:1 case mappings (cols 12 upper / 13 lower /
                        14 title), General_Category (col 2), bidi class
                        (col 4), decimal digit (col 6), numeric (col 8)
  - SpecialCasing.txt — full 1:n mappings (ß→SS, ﬁ→FI, ŉ→ʼN, İ→i+̇ …);
                        only UNCONDITIONAL rules are emitted (locale rules
                        like tr/az dotted-i and the Final_Sigma CONDITION are
                        excluded — Final_Sigma is implemented in charset.zig
                        as the one conditional rule String.toLowerCase has).
  - PropList.txt      — contributory properties the JVM Character
                        classification formulas reference beyond
                        General_Category: Other_Uppercase / Other_Lowercase /
                        Other_Alphabetic / Other_ID_Start / Other_ID_Continue
                        / Ideographic.

Usage: python3 scripts/gen_unicode_case.py        # rewrites both modules
"""
import urllib.request
import sys
from fractions import Fraction
from pathlib import Path

UCD_VERSION = "16.0.0"
BASE = f"https://www.unicode.org/Public/{UCD_VERSION}/ucd"
OUT = Path(__file__).resolve().parent.parent / "src/runtime/unicode_case.zig"
OUT_CAT = Path(__file__).resolve().parent.parent / "src/runtime/unicode_category.zig"

# UCD two-letter General_Category → JVM Character.getType() byte value.
# 17 is unused by the JVM (PRIVATE_USE=18 Co, SURROGATE=19 Cs).
JVM_CAT = {
    "Cn": 0, "Lu": 1, "Ll": 2, "Lt": 3, "Lm": 4, "Lo": 5,
    "Mn": 6, "Me": 7, "Mc": 8, "Nd": 9, "Nl": 10, "No": 11,
    "Zs": 12, "Zl": 13, "Zp": 14, "Cc": 15, "Cf": 16,
    "Co": 18, "Cs": 19, "Pd": 20, "Ps": 21, "Pe": 22, "Pc": 23,
    "Po": 24, "Sm": 25, "Sc": 26, "Sk": 27, "So": 28, "Pi": 29, "Pf": 30,
}

# UCD Bidi_Class → JVM Character.getDirectionality() byte value.
JVM_BIDI = {
    "L": 0, "R": 1, "AL": 2, "EN": 3, "ES": 4, "ET": 5, "AN": 6, "CS": 7,
    "NSM": 8, "BN": 9, "B": 10, "S": 11, "WS": 12, "ON": 13,
    "LRE": 14, "LRO": 15, "RLE": 16, "RLO": 17, "PDF": 18,
    "LRI": 19, "RLI": 20, "FSI": 21, "PDI": 22,
}

PROPS = [
    "Other_Uppercase", "Other_Lowercase", "Other_Alphabetic",
    "Other_ID_Start", "Other_ID_Continue", "Ideographic",
]


def fetch(name: str) -> str:
    cache = Path(f"/tmp/ucd_{UCD_VERSION}_{name}")
    if cache.exists():
        return cache.read_text()
    print(f"downloading {name} …", file=sys.stderr)
    text = urllib.request.urlopen(f"{BASE}/{name}", timeout=60).read().decode()
    cache.write_text(text)
    return text


def parse_rows(text: str):
    """UnicodeData rows, expanding <First>/<Last> pairs into (lo, hi, fields)
    where `fields` is the First row's field list."""
    rows = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        f = lines[i].split(";")
        if len(f) < 15:
            i += 1
            continue
        cp = int(f[0], 16)
        if f[1].endswith(", First>"):
            f2 = lines[i + 1].split(";")
            rows.append((cp, int(f2[0], 16), f))
            i += 2
            continue
        rows.append((cp, cp, f))
        i += 1
    rows.sort()
    return rows


def case_maps(rows):
    upper, lower, title = [], [], []
    for lo, hi, f in rows:
        if lo != hi:
            continue  # <First>/<Last> ranges never carry case mappings
        cp = lo
        up = int(f[12], 16) if f[12] else cp
        if up != cp:
            upper.append((cp, up))
        if f[13]:
            lower.append((cp, int(f[13], 16)))
        # Simple_Titlecase (col 14) defaults to Simple_Uppercase when empty.
        # Emit a TITLE pair only where the effective title differs from the
        # effective upper (≈ the Lt digraphs: toTitle(ǆ)=ǅ vs toUpper(ǆ)=Ǆ).
        ti = int(f[14], 16) if f[14] else up
        if ti != up:
            title.append((cp, ti))
    return sorted(upper), sorted(lower), sorted(title)


def parse_special_casing(text: str):
    """Unconditional full mappings that DIFFER from a 1:1 result."""
    up_full, lo_full = [], []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        f = [x.strip() for x in line.split(";")]
        # cp; lower; title; upper; (condition)
        if len(f) >= 5 and f[4]:
            continue  # conditional (locale / Final_Sigma) — excluded
        cp = int(f[0], 16)
        lo = [int(x, 16) for x in f[1].split()] if f[1] else []
        up = [int(x, 16) for x in f[3].split()] if f[3] else []
        if len(up) != 1 or up[0] != cp:
            if up and (len(up) > 1 or True):
                up_full.append((cp, up))
        if len(lo) != 1 or lo[0] != cp:
            if lo:
                lo_full.append((cp, lo))
    # Only keep rules that a simple map cannot express (len != 1), or that
    # override the simple map with a different single target.
    return sorted(up_full), sorted(lo_full)


def merge_ranges(ranges):
    out = []
    for lo, hi in sorted(ranges):
        if out and out[-1][1] + 1 >= lo:
            out[-1] = (out[-1][0], max(out[-1][1], hi))
        else:
            out.append((lo, hi))
    return out


def categories(rows):
    """{two_letter_cat: [(lo,hi),...]} (sorted, merged)."""
    cats = {}
    for lo, hi, f in rows:
        cats.setdefault(f[2], []).append((lo, hi))
    return {cat: merge_ranges(lst) for cat, lst in cats.items()}


def tagged_ranges(rows, col, mapping):
    """Merged sorted (lo, hi, mapped_value) list from a UnicodeData column,
    coalescing adjacent ranges that share the mapped value."""
    out = []
    for lo, hi, f in rows:
        v = mapping[f[col]]
        if out and out[-1][2] == v and out[-1][1] + 1 == lo:
            out[-1] = (out[-1][0], hi, v)
        else:
            out.append((lo, hi, v))
    return out


def decimal_digits(rows):
    """(lo, hi, value_of_lo) runs of Nd decimal digits: consecutive
    codepoints carrying consecutive col-6 values collapse into one range,
    so value(cp) = value_of_lo + (cp - lo)."""
    entries = [
        (lo, int(f[6]))
        for lo, hi, f in rows
        if f[2] == "Nd" and lo == hi and f[6] != ""
    ]
    runs = []  # (lo, hi, first_v, last_v)
    for cp, v in entries:
        if runs and runs[-1][1] + 1 == cp and runs[-1][3] + 1 == v:
            runs[-1] = (runs[-1][0], cp, runs[-1][2], v)
        else:
            runs.append((cp, cp, v, v))
    return [(lo, hi, v0) for lo, hi, v0, _ in runs]


def numeric_others(rows):
    """(cp, value) for codepoints with a Numeric value (col 8) that are NOT
    Nd decimal digits: Roman numerals (Nl), superscripts (No), CJK numerics …
    Non-integer values (½) emit the JVM -2 sentinel; integers that overflow
    i32 also emit -2 (JVM stores int)."""
    out = []
    for lo, hi, f in rows:
        if f[8] == "" or f[2] == "Nd" or lo != hi:
            continue
        try:
            v = Fraction(f[8])
        except (ValueError, ZeroDivisionError):
            continue
        if v.denominator != 1 or not (-(2**31) <= v.numerator < 2**31) or v.numerator < 0:
            out.append((lo, -2))
        else:
            out.append((lo, v.numerator))
    return sorted(out)


def parse_prop_list(text: str):
    """{prop_name: [(lo,hi),...]} for the PROPS subset of PropList.txt."""
    props = {p: [] for p in PROPS}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        rng, _, prop = [x.strip() for x in line.partition(";")]
        if prop not in props:
            continue
        if ".." in rng:
            lo, hi = (int(x, 16) for x in rng.split(".."))
        else:
            lo = hi = int(rng, 16)
        props[prop].append((lo, hi))
    return {p: merge_ranges(r) for p, r in props.items()}


def mirrored_ranges(rows):
    """Bidi_Mirrored (UnicodeData col 9 == 'Y') as merged ranges."""
    return merge_ranges([(lo, hi) for lo, hi, f in rows if f[9] == "Y"])


def emit_categories(cats, cat_tagged, bidi_tagged, props, dec_digits, num_others, mirrored) -> str:
    majors = {}
    for cat, ranges in cats.items():
        majors.setdefault(cat[0], []).extend(ranges)
    for m in majors:
        majors[m] = merge_ranges(majors[m])

    def table(name, ranges):
        body = "\n".join(f"    .{{ .lo = 0x{lo:X}, .hi = 0x{hi:X} }}," for lo, hi in ranges)
        return f"const {name} = [_]CpRange{{\n{body}\n}};"

    tables = []
    names = []
    for cat in sorted(cats):
        zname = f"CAT_{cat.upper()}"
        tables.append(table(zname, cats[cat]))
        names.append((cat, zname))
    for m in sorted(majors):
        zname = f"MAJ_{m.upper()}"
        tables.append(table(zname, majors[m]))
        names.append((m, zname))

    arms = "\n".join(
        f'    if (std.mem.eql(u8, name, "{nm}")) return &{z};' for nm, z in names
    )

    cat_rows = "\n".join(
        f"    .{{ .lo = 0x{lo:X}, .hi = 0x{hi:X}, .v = {v} }}," for lo, hi, v in cat_tagged
    )
    bidi_rows = "\n".join(
        f"    .{{ .lo = 0x{lo:X}, .hi = 0x{hi:X}, .v = {v} }}," for lo, hi, v in bidi_tagged
    )
    prop_tables = "\n\n".join(
        table(f"PROP_{p.upper()}", props[p]) for p in PROPS
    )
    mirrored_table = table("BIDI_MIRRORED", mirrored)
    dec_rows = "\n".join(
        f"    .{{ .lo = 0x{lo:X}, .hi = 0x{hi:X}, .v = {v} }}," for lo, hi, v in dec_digits
    )
    num_rows = "\n".join(
        f"    .{{ .cp = 0x{cp:X}, .v = {v} }}," for cp, v in num_others
    )
    nl = "\n\n"
    return f"""// SPDX-License-Identifier: EPL-2.0
//! Unicode General_Category / Bidi_Class / contributory-property /
//! numeric-value tables — GENERATED by scripts/gen_unicode_case.py from
//! UCD {UCD_VERSION} (UnicodeData.txt + PropList.txt). DO NOT EDIT. D-409.
//!
//! Two consumers:
//!   - the regex compiler's `\\p{{...}}` / `\\P{{...}}` property classes via
//!     `rangesOf` (the Java one/two-letter General_Category alphabet;
//!     one-letter names are the precomputed major-class unions);
//!   - the `java.lang.Character` classification surface via `categoryOf` /
//!     `directionalityOf` / `hasProp` / `decimalDigitValue` /
//!     `numericValue` (JVM getType / getDirectionality / is* formulas).
//! Ranges are sorted + merged; lookups are binary searches.

const std = @import("std");

pub const CpRange = struct {{ lo: u21, hi: u21 }};

/// (lo, hi) range carrying a small tagged value (JVM category / bidi byte).
pub const TaggedRange = struct {{ lo: u21, hi: u21, v: i32 }};

{nl.join(tables)}

{prop_tables}

{mirrored_table}

/// Every assigned codepoint's JVM getType() value (Cn=0 gaps omitted —
/// a lookup miss IS Cn/UNASSIGNED).
const CAT_TABLE = [_]TaggedRange{{
{cat_rows}
}};

/// Every assigned codepoint's JVM getDirectionality() value (a lookup miss
/// is DIRECTIONALITY_UNDEFINED = -1).
const BIDI_TABLE = [_]TaggedRange{{
{bidi_rows}
}};

/// Nd decimal-digit runs: value(cp) = v + (cp - lo).
const DECIMAL_TABLE = [_]TaggedRange{{
{dec_rows}
}};

const NumEntry = struct {{ cp: u21, v: i32 }};

/// Non-Nd numeric codepoints (Roman numerals, superscripts, CJK numerics …);
/// v = -2 for fractional / out-of-int values (the JVM sentinel).
const NUMERIC_TABLE = [_]NumEntry{{
{num_rows}
}};

fn taggedLookup(table: []const TaggedRange, cp: u21) ?i32 {{
    var lo: usize = 0;
    var hi: usize = table.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        const r = table[mid];
        if (cp < r.lo) {{
            hi = mid;
        }} else if (cp > r.hi) {{
            lo = mid + 1;
        }} else {{
            return r.v;
        }}
    }}
    return null;
}}

/// True iff `cp` falls in one of the (sorted, merged) ranges.
pub fn inRanges(ranges: []const CpRange, cp: u21) bool {{
    var lo: usize = 0;
    var hi: usize = ranges.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        const r = ranges[mid];
        if (cp < r.lo) {{
            hi = mid;
        }} else if (cp > r.hi) {{
            lo = mid + 1;
        }} else {{
            return true;
        }}
    }}
    return false;
}}

/// JVM Character.getType() byte value for `cp` (0 = UNASSIGNED/Cn).
pub fn categoryOf(cp: u21) u5 {{
    return @intCast(taggedLookup(&CAT_TABLE, cp) orelse 0);
}}

/// JVM Character.getDirectionality() byte value (-1 = UNDEFINED).
pub fn directionalityOf(cp: u21) i8 {{
    return @intCast(taggedLookup(&BIDI_TABLE, cp) orelse -1);
}}

/// JVM Character.isMirrored(): the Bidi_Mirrored property (UnicodeData
/// col 9) — `(`/`)`/`<` mirror in right-to-left text, `a` does not.
pub fn isMirrored(cp: u21) bool {{
    return inRanges(&BIDI_MIRRORED, cp);
}}

/// The contributory properties the JVM classification formulas reference.
pub const Prop = enum {{
    other_uppercase,
    other_lowercase,
    other_alphabetic,
    other_id_start,
    other_id_continue,
    ideographic,
}};

/// True iff `cp` carries the PropList.txt contributory property.
pub fn hasProp(prop: Prop, cp: u21) bool {{
    const ranges: []const CpRange = switch (prop) {{
        .other_uppercase => &PROP_OTHER_UPPERCASE,
        .other_lowercase => &PROP_OTHER_LOWERCASE,
        .other_alphabetic => &PROP_OTHER_ALPHABETIC,
        .other_id_start => &PROP_OTHER_ID_START,
        .other_id_continue => &PROP_OTHER_ID_CONTINUE,
        .ideographic => &PROP_IDEOGRAPHIC,
    }};
    return inRanges(ranges, cp);
}}

/// Decimal-digit value of an Nd codepoint (0-9), or null.
pub fn decimalDigitValue(cp: u21) ?u4 {{
    var lo: usize = 0;
    var hi: usize = DECIMAL_TABLE.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        const r = DECIMAL_TABLE[mid];
        if (cp < r.lo) {{
            hi = mid;
        }} else if (cp > r.hi) {{
            lo = mid + 1;
        }} else {{
            return @intCast(@as(u21, @intCast(r.v)) + (cp - r.lo));
        }}
    }}
    return null;
}}

/// Numeric value of a non-Nd numeric codepoint (Ⅶ→7, ²→2), -2 for
/// fractional (½), or null when the codepoint has no numeric value.
pub fn numericValue(cp: u21) ?i32 {{
    var lo: usize = 0;
    var hi: usize = NUMERIC_TABLE.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        if (NUMERIC_TABLE[mid].cp == cp) return NUMERIC_TABLE[mid].v;
        if (NUMERIC_TABLE[mid].cp < cp) lo = mid + 1 else hi = mid;
    }}
    return null;
}}

/// The range list for a Java General_Category name ("L", "Lu", "Zs", …),
/// or null for an unknown name (the compiler raises NotImplemented).
pub fn rangesOf(name: []const u8) ?[]const CpRange {{
{arms}
    return null;
}}

test "category sanity" {{
    const lu = rangesOf("Lu").?;
    try std.testing.expect(lu.len > 100);
    const l = rangesOf("L").?;
    try std.testing.expect(l.len > 100);
    try std.testing.expect(rangesOf("Zz") == null);
}}

test "categoryOf JVM getType values" {{
    try std.testing.expectEqual(@as(u5, 2), categoryOf('a')); // Ll
    try std.testing.expectEqual(@as(u5, 1), categoryOf('A')); // Lu
    try std.testing.expectEqual(@as(u5, 9), categoryOf('5')); // Nd
    try std.testing.expectEqual(@as(u5, 12), categoryOf(' ')); // Zs
    try std.testing.expectEqual(@as(u5, 23), categoryOf('_')); // Pc
    try std.testing.expectEqual(@as(u5, 0), categoryOf(0x378)); // Cn
    try std.testing.expectEqual(@as(u5, 5), categoryOf(0x3042)); // あ Lo
}}

test "directionality / props / numerics" {{
    try std.testing.expectEqual(@as(i8, 0), directionalityOf('a')); // L
    try std.testing.expectEqual(@as(i8, 1), directionalityOf(0x5D0)); // א R
    try std.testing.expectEqual(@as(i8, -1), directionalityOf(0x378));
    try std.testing.expect(hasProp(.other_uppercase, 0x2160)); // Ⅰ
    try std.testing.expect(hasProp(.ideographic, 0x4E00)); // 一
    try std.testing.expect(!hasProp(.ideographic, 'a'));
    try std.testing.expectEqual(@as(?u4, 5), decimalDigitValue(0x665)); // ٥
    try std.testing.expectEqual(@as(?i32, 7), numericValue(0x2166)); // Ⅶ
    try std.testing.expectEqual(@as(?i32, -2), numericValue(0xBD)); // ½
    try std.testing.expect(isMirrored('(') and isMirrored('<'));
    try std.testing.expect(!isMirrored('a'));
}}
"""


def fold_classes(upper, lower):
    """Equivalence classes of the Java UNICODE_CASE fold predicate
    (a~b iff simple-upper or simple-lower coincide), via union-find over
    the cp—upper(cp) and cp—lower(cp) edges. Returns rows (cp, members)
    for every cp in a class of size ≥ 2 — the regex (?iu) compile-time
    orbit expansion."""
    parent = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for cp, to in upper:
        union(cp, to)
    for cp, to in lower:
        union(cp, to)
    groups = {}
    for cp in list(parent):
        groups.setdefault(find(cp), set()).add(cp)
    rows = []
    for members in groups.values():
        if len(members) < 2:
            continue
        ms = sorted(members)
        if len(ms) > 4:
            ms = ms[:4]  # no real class exceeds 3-4 (σ/Σ/ς; K/k/K)
        for cp in sorted(members):
            rows.append((cp, ms))
    return sorted(rows)


def emit(upper, lower, title, up_full, lo_full, fold_rows) -> str:
    def pairs(rows):
        return "\n".join(
            f"    .{{ .cp = 0x{cp:X}, .to = 0x{to:X} }}," for cp, to in rows
        )

    def orbits(rows):
        out = []
        for cp, ms in rows:
            padded = (ms + [0, 0, 0, 0])[:4]
            out.append(
                f"    .{{ .cp = 0x{cp:X}, .members = .{{ "
                + ", ".join(f"0x{c:X}" for c in padded)
                + f" }}, .len = {len(ms)} }},"
            )
        return "\n".join(out)

    def fulls(rows):
        out = []
        for cp, seq in rows:
            padded = (seq + [0, 0, 0])[:3]
            out.append(
                f"    .{{ .cp = 0x{cp:X}, .to = .{{ "
                + ", ".join(f"0x{c:X}" for c in padded)
                + f" }}, .len = {len(seq)} }},"
            )
        return "\n".join(out)

    return f"""// SPDX-License-Identifier: EPL-2.0
//! Unicode case-mapping tables — GENERATED by scripts/gen_unicode_case.py
//! from UCD {UCD_VERSION} (UnicodeData.txt + SpecialCasing.txt). DO NOT EDIT;
//! re-run the generator to regenerate. D-057.
//!
//! Three consumers, three semantics (the JVM split):
//!   - `toUpperSimple`/`toLowerSimple`/`toTitleSimple` — 1:1
//!     (Character/toUpperCase: ß stays).
//!   - `toUpperFull`/`toLowerFull` — 1:n via SpecialCasing then simple
//!     (String.toUpperCase: ß→SS). Final_Sigma (the one CONDITIONAL rule)
//!     lives in charset.zig, not here.
//!   - regex `(?iu)` folds via the SIMPLE maps (Java UNICODE_CASE: two
//!     codepoints match iff their simple uppers or simple lowers are equal —
//!     gives the σ/Σ/ς orbit while ß≁"ss").

const std = @import("std");

const Pair = packed struct {{ cp: u21, to: u21 }};
const Full = struct {{ cp: u21, to: [3]u21, len: u8 }};
const Orbit = struct {{ cp: u21, members: [4]u21, len: u8 }};

const UPPER = [_]Pair{{
{pairs(upper)}
}};

const LOWER = [_]Pair{{
{pairs(lower)}
}};

// Simple titlecase where it DIFFERS from simple uppercase (the Lt digraphs:
// toTitle(ǆ)=ǅ while toUpper(ǆ)=Ǆ). Fallback is toUpperSimple.
const TITLE = [_]Pair{{
{pairs(title)}
}};

const UPPER_FULL = [_]Full{{
{fulls(up_full)}
}};

const LOWER_FULL = [_]Full{{
{fulls(lo_full)}
}};

const FOLD = [_]Orbit{{
{orbits(fold_rows)}
}};

fn lookupPair(table: []const Pair, cp: u21) ?u21 {{
    var lo: usize = 0;
    var hi: usize = table.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        if (table[mid].cp == cp) return table[mid].to;
        if (table[mid].cp < cp) lo = mid + 1 else hi = mid;
    }}
    return null;
}}

fn lookupFull(table: []const Full, cp: u21) ?[]const u21 {{
    var lo: usize = 0;
    var hi: usize = table.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        if (table[mid].cp == cp) return table[mid].to[0..table[mid].len];
        if (table[mid].cp < cp) lo = mid + 1 else hi = mid;
    }}
    return null;
}}

/// SIMPLE 1:1 uppercase (Character/toUpperCase semantics).
pub fn toUpperSimple(cp: u21) u21 {{
    return lookupPair(&UPPER, cp) orelse cp;
}}

/// SIMPLE 1:1 lowercase (Character/toLowerCase semantics).
pub fn toLowerSimple(cp: u21) u21 {{
    return lookupPair(&LOWER, cp) orelse cp;
}}

/// SIMPLE 1:1 titlecase (Character/toTitleCase semantics): the explicit
/// title mapping where one exists, else the simple uppercase.
pub fn toTitleSimple(cp: u21) u21 {{
    return lookupPair(&TITLE, cp) orelse toUpperSimple(cp);
}}

/// FULL uppercase (String.toUpperCase): SpecialCasing 1:n first, else the
/// simple map. `buf` receives the expansion; the returned slice aliases it.
pub fn toUpperFull(cp: u21, buf: *[3]u21) []const u21 {{
    if (lookupFull(&UPPER_FULL, cp)) |seq| {{
        @memcpy(buf[0..seq.len], seq);
        return buf[0..seq.len];
    }}
    buf[0] = toUpperSimple(cp);
    return buf[0..1];
}}

/// FULL lowercase (String.toLowerCase, minus the charset.zig-owned
/// Final_Sigma condition).
pub fn toLowerFull(cp: u21, buf: *[3]u21) []const u21 {{
    if (lookupFull(&LOWER_FULL, cp)) |seq| {{
        @memcpy(buf[0..seq.len], seq);
        return buf[0..seq.len];
    }}
    buf[0] = toLowerSimple(cp);
    return buf[0..1];
}}

/// The full fold-equivalence class of `cp` under the Java UNICODE_CASE
/// predicate (union-find closure over the simple maps), or null when the
/// class is the singleton {{cp}}. The regex `(?iu)` compiler expands a
/// literal into an alternation of these members (σ → σ|Σ|ς).
pub fn foldOrbit(cp: u21) ?[]const u21 {{
    var lo: usize = 0;
    var hi: usize = FOLD.len;
    while (lo < hi) {{
        const mid = lo + (hi - lo) / 2;
        if (FOLD[mid].cp == cp) return FOLD[mid].members[0..FOLD[mid].len];
        if (FOLD[mid].cp < cp) lo = mid + 1 else hi = mid;
    }}
    return null;
}}

/// Java UNICODE_CASE fold: codepoints match iff simple-upper OR simple-lower
/// coincide (σ/Σ/ς orbit; ß does NOT fold to "ss").
pub fn foldEq(a: u21, b: u21) bool {{
    if (a == b) return true;
    if (toUpperSimple(a) == toUpperSimple(b)) return true;
    return toLowerSimple(a) == toLowerSimple(b);
}}

/// True iff `cp` participates in casing at all (has a simple mapping in
/// either direction) — the cheap "cased letter" approximation charset.zig's
/// Final_Sigma condition uses (full General_Category data is not carried).
pub fn isCased(cp: u21) bool {{
    if (cp < 0x80) return (cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z');
    return lookupPair(&UPPER, cp) != null or lookupPair(&LOWER, cp) != null;
}}

test "simple vs full split (the JVM 3-way)" {{
    try std.testing.expectEqual(@as(u21, 0xC4), toUpperSimple(0xE4)); // ä→Ä
    try std.testing.expectEqual(@as(u21, 0xDF), toUpperSimple(0xDF)); // ß stays (simple)
    var buf: [3]u21 = undefined;
    const ss = toUpperFull(0xDF, &buf); // ß→SS (full)
    try std.testing.expectEqual(@as(usize, 2), ss.len);
    try std.testing.expectEqual(@as(u21, 'S'), ss[0]);
    try std.testing.expectEqual(@as(u21, 'S'), ss[1]);
    // σ(03C3)/Σ(03A3)/ς(03C2) fold orbit; ß does not fold to s.
    try std.testing.expect(foldEq(0x3C3, 0x3A3));
    try std.testing.expect(foldEq(0x3C2, 0x3C3));
    try std.testing.expect(!foldEq(0xDF, 's'));
}}

test "titlecase digraphs" {{
    try std.testing.expectEqual(@as(u21, 0x1C5), toTitleSimple(0x1C6)); // ǆ→ǅ
    try std.testing.expectEqual(@as(u21, 0x1C5), toTitleSimple(0x1C5)); // ǅ→ǅ
    try std.testing.expectEqual(@as(u21, 'A'), toTitleSimple('a')); // fallback = upper
}}
"""


def main():
    rows = parse_rows(fetch("UnicodeData.txt"))
    upper, lower, title = case_maps(rows)
    up_full, lo_full = parse_special_casing(fetch("SpecialCasing.txt"))
    fold_rows = fold_classes(upper, lower)
    OUT.write_text(emit(upper, lower, title, up_full, lo_full, fold_rows))
    cats = categories(rows)
    cat_tagged = tagged_ranges(rows, 2, JVM_CAT)
    bidi_tagged = tagged_ranges(rows, 4, JVM_BIDI)
    props = parse_prop_list(fetch("PropList.txt"))
    dec = decimal_digits(rows)
    nums = numeric_others(rows)
    mirrored = mirrored_ranges(rows)
    OUT_CAT.write_text(emit_categories(cats, cat_tagged, bidi_tagged, props, dec, nums, mirrored))
    print(
        f"wrote {OUT} — simple upper {len(upper)} / lower {len(lower)} / title {len(title)}; "
        f"full upper {len(up_full)} / lower {len(lo_full)}; fold rows {len(fold_rows)}; "
        f"categories {len(cats)}, cat ranges {len(cat_tagged)}, bidi ranges {len(bidi_tagged)}, "
        f"decimal runs {len(dec)}, numeric others {len(nums)}"
    )


if __name__ == "__main__":
    main()
