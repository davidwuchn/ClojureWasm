#!/usr/bin/env bash
# test/e2e/phase14_reify_destructure_param.sh — destructured method params in
# reify / deftype / extend-type. clj lowers a non-symbol method param (`[_ [k x]]`)
# the same way fn does: gensym the pattern param + wrap the body in a `let`. cljw
# previously emitted fn* with the raw pattern and raised "fn* parameter must be a
# symbol" (surfaced by the clojure.spec.alpha port, unform* [_ [k x]]). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

run() { "$BIN" - <<EOF 2>&1 | tail -1
$1
EOF
}

# reify: second param destructured as a vector
assert_eq 'reify-vec-destructure' \
  "$(run '(defprotocol P (m [s x])) (prn (m (reify P (m [_ [a b]] (+ a b))) [3 4]))')" \
  '7'

# deftype (extend-type lowering path): destructured param
assert_eq 'deftype-vec-destructure' \
  "$(run '(defprotocol P (m [s x])) (deftype T [] P (m [_ [a b]] (* a b))) (prn (m (->T) [3 4]))')" \
  '12'

# map destructuring in a method param
assert_eq 'reify-map-destructure' \
  "$(run '(defprotocol P (m [s x])) (prn (m (reify P (m [_ {k :k}] k)) {:k 9}))')" \
  '9'

# regression: all-symbol params unchanged (the no-op fast path)
assert_eq 'reify-plain-symbol' \
  "$(run '(defprotocol P (m [s x])) (prn (m (reify P (m [_ x] (inc x))) 5))')" \
  '6'
