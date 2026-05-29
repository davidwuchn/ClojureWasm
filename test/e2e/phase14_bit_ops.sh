#!/usr/bin/env bash
# test/e2e/phase14_bit_ops.sh — bit-set / bit-clear / bit-flip / bit-test
# (D-134). .clj compositions over the bit-* Zig primitives. n = bit index.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_eq 'set_0_3'    "$("$BIN" -e '(bit-set 0 3)')"    '8'
assert_eq 'set_5_1'    "$("$BIN" -e '(bit-set 5 1)')"    '7'
assert_eq 'clear_15_1' "$("$BIN" -e '(bit-clear 15 1)')" '13'
assert_eq 'clear_8_3'  "$("$BIN" -e '(bit-clear 8 3)')"  '0'
assert_eq 'flip_0_3'   "$("$BIN" -e '(bit-flip 0 3)')"   '8'
assert_eq 'flip_back'  "$("$BIN" -e '(bit-flip 8 3)')"   '0'
assert_eq 'test_set'   "$("$BIN" -e '(bit-test 4 2)')"   'true'
assert_eq 'test_unset' "$("$BIN" -e '(bit-test 4 1)')"   'false'
assert_eq 'test_zero'  "$("$BIN" -e '(bit-test 0 0)')"   'false'
# round-trip: set then test then clear
assert_eq 'roundtrip'  "$("$BIN" -e '(bit-test (bit-set 0 5) 5)')" 'true'
echo "OK — phase14_bit_ops smoke (10 cases) green"
