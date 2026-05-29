#!/usr/bin/env bash
# test/e2e/phase14_bounded_count.sh — D-134 bounded-count (count up to n;
# terminates on infinite seqs). Pattern A .clj loop, AOT blob.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_eq 'bc_cap'   "$("$BIN" -e '(bounded-count 3 [1 2 3 4 5])')" '3'
assert_eq 'bc_full'  "$("$BIN" -e '(bounded-count 10 [1 2 3])')"    '3'
assert_eq 'bc_zero'  "$("$BIN" -e '(bounded-count 0 [1 2 3])')"     '0'
assert_eq 'bc_empty' "$("$BIN" -e '(bounded-count 5 [])')"         '0'
assert_eq 'bc_inf'   "$("$BIN" -e '(bounded-count 4 (range))')"    '4'
echo "OK — phase14_bounded_count smoke (5 cases) green"
