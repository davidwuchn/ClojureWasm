#!/usr/bin/env bash
# test/e2e/phase14_empty_list.sh
#
# D-188: the unquoted empty-list literal `()` self-evaluates instead of
# raising "Empty list as expression value is not supported". cljw represents
# the empty list as nil today (empty≡nil; the distinct empty-list Value is
# D-164's structural overhaul), so `()` yields the same nil that `(list)` /
# `'()` do — the fix removes the spurious error and makes `()` consistent
# with the other empty-list spellings.
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

assert_eq 'el_eval'     "$("$BIN" -e '()')"                   'nil'
assert_eq 'el_eq_list'  "$("$BIN" -e '(= () (list))')"        'true'
assert_eq 'el_eq_quote' "$("$BIN" -e '(= () (quote ()))')"    'true'
assert_eq 'el_in_fn'    "$("$BIN" -e '((fn* [] ()))')"        'nil'
assert_eq 'el_let'      "$("$BIN" -e '(let [x ()] x)')"       'nil'

echo "ALL phase14_empty_list PASS"
