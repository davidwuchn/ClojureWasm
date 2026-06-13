#!/usr/bin/env bash
# test/e2e/phase14_ratio_interop.sh — D-420.
# clojure.lang.Ratio instance interop: `(.numerator r)` / `(.denominator r)`
# reached via the dot form. clojure.math.numeric-tower's MathFunctions extends
# Ratio and computes floor/ceil/sqrt with `(. n numerator)`/`(. n denominator)`.
# The values mirror cljw's core `(numerator r)`/`(denominator r)` (Long when the
# component fits i48 — cljw's F-005 narrow-when-fits; clj keeps BigInteger, an
# accepted representation divergence, the VALUE is `=`).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

assert_eq 'dot_numerator'   "$("$BIN" -e '(.numerator 5/2)')"   '5'
assert_eq 'dot_denominator' "$("$BIN" -e '(.denominator 5/2)')" '2'
# the `(. r member)` special-form shape (what numeric-tower emits) dispatches too.
assert_eq 'dotform_numer'   "$("$BIN" -e '(. 22/7 numerator)')" '22'
assert_eq 'dotform_denom'   "$("$BIN" -e '(. 22/7 denominator)')" '7'
# matches the core fns (same impl, same narrowing).
assert_eq 'matches_core'    "$("$BIN" -e '[(= (.numerator 9/4) (numerator 9/4)) (= (.denominator 9/4) (denominator 9/4))]')" '[true true]'
# sign normalisation: denom always > 0, numerator absorbs sign.
assert_eq 'neg_numerator'   "$("$BIN" -e '[(.numerator -3/4) (.denominator -3/4)]')" '[-3 4]'

echo "OK — phase14_ratio_interop (6 cases) green"
