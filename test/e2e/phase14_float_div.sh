#!/usr/bin/env bash
# test/e2e/phase14_float_div.sh — float division yields IEEE ±Inf / NaN
# (JVM-faithful), while integer division by zero still raises. Fix in
# runtime/numeric/promote.zig (F-005 numeric tower JVM-surface).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_has() { local n="$1" g="$2" w="$3"; [[ "$g" == *"$w"* ]] || fail "$n: '$g' lacks '$w'"; echo "PASS $n =~ $w"; }

assert_eq 'pos_inf'   "$("$BIN" -e '(/ 1.0 0.0)')"  '##Inf'
assert_eq 'neg_inf'   "$("$BIN" -e '(/ -1.0 0.0)')" '##-Inf'
assert_eq 'nan'       "$("$BIN" -e '(/ 0.0 0.0)')"  '##NaN'
assert_eq 'mix_if'    "$("$BIN" -e '(/ 1 0.0)')"    '##Inf'
assert_eq 'mix_fi'    "$("$BIN" -e '(/ 1.0 0)')"    '##Inf'
assert_eq 'normal'    "$("$BIN" -e '(/ 10.0 2.0)')" '5.0'
# integer division by zero still raises (JVM ArithmeticException parity)
assert_has 'int_zero' "$("$BIN" -e '(/ 1 0)' 2>&1)" 'Divide by zero'
# AD-050: a float-zero DIVISOR yields IEEE ±Inf/NaN on EVERY path (1-arg, apply,
# reduce), consistently. clj's compile-inlined 2-arg literal path also gives Inf,
# but its RUNTIME Numbers.divide (1-arg / apply / reduce) THROWS "Divide by zero"
# — a JVM inline-vs-runtime artifact cljw has no equivalent for. cljw is the more
# consistent surface; these lock cljw's divergent (IEEE, non-throwing) form.
assert_eq 'ad050_recip'   "$("$BIN" -e '(/ 0.0)')"                 '##Inf'
assert_eq 'ad050_recip_n' "$("$BIN" -e '(/ -0.0)')"               '##-Inf'
assert_eq 'ad050_apply'   "$("$BIN" -e '(apply / [1.0 0.0])')"     '##Inf'
assert_eq 'ad050_reduce'  "$("$BIN" -e '(reduce / [1.0 2.0 0.0])')" '##Inf'
echo "OK — phase14_float_div smoke (11 cases) green"
