#!/usr/bin/env bash
# test/e2e/phase14_transducers.sh — transducer surface (gap-map HIGH ROI).
# Cycle 1 (foundation): reduced / reduced? / unreduced / ensure-reduced +
# deref on a Reduced + reduce early-termination via (reduced acc). Later
# cycles add the transducer arities (map/filter/…), transduce, into-xform,
# completing, and the stateful transducers.
#
# Layer 2 (e2e CLI) per ADR-0021.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
# reduced sentinel surface
assert_eq 'reducedQ_t'  "$("$BIN" -e '(reduced? (reduced 5))')"            'true'
assert_eq 'reducedQ_f'  "$("$BIN" -e '(reduced? 5)')"                      'false'
assert_eq 'unreduced'   "$("$BIN" -e '(unreduced (reduced 7))')"          '7'
assert_eq 'unreduced_pl' "$("$BIN" -e '(unreduced 7)')"                   '7'
assert_eq 'ensure_red'  "$("$BIN" -e '(reduced? (ensure-reduced 5))')"    'true'
assert_eq 'ensure_idem' "$("$BIN" -e '(unreduced (ensure-reduced (reduced 9)))')" '9'
assert_eq 'deref_red'   "$("$BIN" -e '@(reduced 42)')"                    '42'
# reduce honors early termination
assert_eq 'reduce_early' "$("$BIN" -e '(reduce (fn [acc x] (if (>= acc 6) (reduced acc) (+ acc x))) 0 [1 2 3 4 5])')" '6'
echo "OK — phase14_transducers (8 cases, cycle 1 foundation) green"
