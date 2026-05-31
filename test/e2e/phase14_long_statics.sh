#!/usr/bin/env bash
# test/e2e/phase14_long_statics.sh
#
# Phase 14 §9.16 / cluster A26 (clj differential sweep, F-011) —
# java.lang.Long static methods. Surface runtime/java/lang/Long.zig,
# delegating parsing to the shared runtime/numeric/parse.zig leaf
# (F-011 DRY with parse-long / Integer/parseInt) but at i64 width.
# parseLong wraps through promote.wrapManaged so a value beyond i48 is
# exact (BigInt) rather than a lossy Float — see the D-165 note below.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }

check() { # check <expr> <expected> <label>
    local out
    set +e
    out=$("$BIN" -e "$1" 2>&1 | tail -n 1)
    set -e
    [[ "$out" == "$2" ]] || fail "$3: expected '$2', got '$out'"
    echo "PASS $3 -> $2"
}

# --- parseLong (i64 width, optional radix) ---
check '(Long/parseLong "9999999999")' '9999999999' long_parseLong_big_i48safe
check '(Long/parseLong "ff" 16)'      '255'        long_parseLong_radix16
check '(Long/parseLong "-10")'        '-10'        long_parseLong_negative

# --- toBinaryString / toHexString / toOctalString (64-bit width) ---
check '(Long/toBinaryString 10)'      '"1010"'     long_toBinaryString
check '(Long/toHexString 255)'        '"ff"'       long_toHexString
check '(Long/toOctalString 8)'        '"10"'       long_toOctalString

# --- valueOf ---
check '(Long/valueOf "42")'           '42'         long_valueOf_string
check '(Long/valueOf 7)'              '7'          long_valueOf_int

# --- NumberFormatException via ADR-0060 bridge ---
check '(try (Long/parseLong "x") (catch NumberFormatException e :caught))'   ':caught' long_parseLong_nfe
check '(try (Long/parseLong "1_000") (catch NumberFormatException e :caught))' ':caught' long_parseLong_underscore_nfe

# --- RECORDED DIVERGENCE (D-165): a value in (2^47, 2^63] is exact but
#     prints as BigInt (N suffix) where JVM keeps a primitive Long
#     ("999999999999999"). cljw i48 NaN-box → BigInt promotion. Pinned
#     so the known divergence can't silently change. ---
check '(Long/parseLong "999999999999999")' '999999999999999N' long_parseLong_i48_overflow_bigint

echo "ALL PASS phase14_long_statics"
