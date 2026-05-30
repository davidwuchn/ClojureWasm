#!/usr/bin/env bash
# test/e2e/phase14_counted_reversible.sh — counted? / reversible? predicates
# (D-134). counted? = vector/map/set/list (O(1) count); lazy-seq/string/nil
# false. reversible? = vector only (cw v1 has no sorted coll).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_eq 'c_vec'  "$("$BIN" -e '(counted? [1])')"      'true'
assert_eq 'c_map'  "$("$BIN" -e '(counted? {})')"       'true'
assert_eq 'c_set'  "$("$BIN" -e '(counted? #{1})')"     'true'
assert_eq 'c_list' "$("$BIN" -e '(counted? (list 1))')" 'true'
assert_eq 'c_lazy' "$("$BIN" -e '(counted? (lazy-seq (cons 1 nil)))')" 'false'
assert_eq 'c_str'  "$("$BIN" -e '(counted? "abc")')"    'false'
assert_eq 'c_nil'  "$("$BIN" -e '(counted? nil)')"      'false'
assert_eq 'r_vec'  "$("$BIN" -e '(reversible? [1])')"     'true'
assert_eq 'r_list' "$("$BIN" -e '(reversible? (list 1))')" 'false'
assert_eq 'r_map'  "$("$BIN" -e '(reversible? {})')"     'false'
echo "OK — phase14_counted_reversible smoke (10 cases) green"
