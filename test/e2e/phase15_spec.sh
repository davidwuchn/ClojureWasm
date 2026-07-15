#!/usr/bin/env bash
# test/e2e/phase15_spec.sh
#
# clojure.spec.alpha — bundled official stdlib (ADR-0156, D-475). spec is
# eager-bundled, so fully-qualified `clojure.spec.alpha/...` resolves with no
# require. Covers the conform/valid?/explain surface across every regex op +
# the collection/keys/multi-spec specs. `s/form` now matches clj exactly —
# the captured pred qualifies to `clojure.core/int?` since builtins intern
# into clojure.core (ADR-0171; the former AD-049 rt/-naming divergence is
# retired as parity).
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

S=clojure.spec.alpha
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# --- load: fully-qualified resolves with NO require (eager bundle) ---
assert_eq 'load_valid' "$("$BIN" -e "($S/valid? ($S/and int? pos?) 5)")" 'true'

# --- regex ops: conform ---
assert_eq 'cat'   "$("$BIN" -e "($S/conform ($S/cat :a int? :b string?) [1 \"x\"])")" '{:a 1, :b "x"}'
assert_eq 'star'  "$("$BIN" -e "($S/conform ($S/* int?) [1 2 3])")"  '[1 2 3]'
assert_eq 'plus'  "$("$BIN" -e "($S/conform ($S/+ int?) [1 2])")"    '[1 2]'
assert_eq 'opt'   "$("$BIN" -e "($S/conform ($S/? int?) [])")"       'nil'
assert_eq 'alt'   "$("$BIN" -e "($S/conform ($S/alt :i int? :s string?) [\"x\"])")" '[:s "x"]'
assert_eq 'amp'   "$("$BIN" -e "($S/conform ($S/& ($S/* int?) (fn [v] (even? (count v)))) [1 2])")" '[1 2]'
assert_eq 'nestreg' "$("$BIN" -e "($S/conform ($S/cat :a ($S/alt :x int? :y ($S/cat :p int? :q int?))) [1])")" '{:a [:x 1]}'

# --- collection / scalar specs ---
assert_eq 'coll'    "$("$BIN" -e "($S/conform ($S/coll-of int?) [1 2 3])")" '[1 2 3]'
assert_eq 'mapof'   "$("$BIN" -e "($S/conform ($S/map-of keyword? int?) {:a 1})")" '{:a 1}'
assert_eq 'tuple'   "$("$BIN" -e "($S/conform ($S/tuple int? string?) [1 \"x\"])")" '[1 "x"]'
assert_eq 'nilable' "$("$BIN" -e "($S/conform ($S/nilable int?) nil)")" 'nil'

# --- s/keys (registered specs) ---
assert_eq 'keys' "$("$BIN" -e "(do ($S/def ::age ($S/and int? pos?)) ($S/valid? ($S/keys :req [::age]) {::age 3}))")" 'true'

# --- multi-spec (needs .dispatchFn/.getMethod on MultiFn) ---
assert_eq 'multi' "$("$BIN" -e "(do (defmulti shp :t) (defmethod shp :c [_] ($S/keys :req-un [::r])) ($S/def ::shp ($S/multi-spec shp :t)) ($S/def ::r int?) ($S/valid? ::shp {:t :c :r 2}))")" 'true'

# --- explain-str / describe go through abbrev → clj-IDENTICAL (fn-sym recovers
#     the predicate name from its #<ns/name> print form) ---
assert_eq 'explain_named' "$("$BIN" -e "($S/explain-str int? \"x\")")" '"\"x\" - failed: int?\n"'
assert_eq 'explain_and'   "$("$BIN" -e "($S/explain-str ($S/and int? pos?) -1)")" '"-1 - failed: pos?\n"'
assert_eq 'describe'      "$("$BIN" -e "($S/describe ($S/and int? pos?))")" '(and int? pos?)'
# anonymous fn predicate → ::unknown, matching clj (its name part is "fn").
assert_eq 'explain_anon'  "$("$BIN" -e "($S/explain-str (fn [n] (pos? n)) -1)")" '"-1 - failed: :clojure.spec.alpha/unknown\n"'

# --- s/form parity (was AD-049): the captured pred is clojure.core-qualified,
# byte-matching clj (ADR-0171).
assert_eq 'form_parity' "$("$BIN" -e "($S/form ($S/cat :a int?))")" '(clojure.spec.alpha/cat :a clojure.core/int?)'

echo "ALL phase15_spec PASS"
