#!/usr/bin/env bash
# test/e2e/phase14_macro_return_hashmap.sh — a macro whose return form contains a
# >8-key map (a .hash_map, not a small .array_map) re-analyses correctly. The
# analyzer's valueToForm handled .array_map but fell through to "cannot be
# re-analysed as a form" for .hash_map; now both route through the generic
# forEachEntry path. Surfaced by clojure.spec.alpha's s/keys, which returns a
# 12-key `(map-spec-impl {…})`. Layer 2.
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

# a macro returning a form with a 10-key (hash_map) literal arg + lookups prove it round-tripped
assert_eq 'macro-return-hashmap-count' \
  "$(run '(defmacro mk [] (quote (count {:a 1 :b 2 :c 3 :d 4 :e 5 :f 6 :g 7 :h 8 :i 9 :j 10}))) (prn (mk))')" \
  '10'
assert_eq 'macro-return-hashmap-get' \
  "$(run '(defmacro mk [] (quote (get {:a 1 :b 2 :c 3 :d 4 :e 5 :f 6 :g 7 :h 8 :i 9 :j 10} :g))) (prn (mk))')" \
  '7'
# syntax-quoted large map with unquotes (the s/keys shape)
assert_eq 'macro-return-sq-hashmap' \
  "$(run '(defmacro mk [x] `(get {:a 1 :b 2 :c 3 :d 4 :e 5 :f 6 :g 7 :h 8 :i 9 :j ~x} :j)) (prn (mk 99))')" \
  '99'
# small map (array_map) still works (regression)
assert_eq 'macro-return-arraymap' \
  "$(run '(defmacro mk [] (quote (get {:a 1 :b 2} :b))) (prn (mk))')" \
  '2'
