#!/usr/bin/env bash
# test/e2e/phase7_symbol_of_var.sh — (symbol var) returns the var's qualified
# symbol (clj parity; clojure.spec.alpha's ->sym relies on it). A USER var maps to
# `user/<name>` exactly as clj. (cljw primitives live in the `rt` ns, so
# `(symbol #'inc)` is `rt/inc` not `clojure.core/inc` — the cljw primitive-ns
# structure, not asserted here.) Layer 2.
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

assert_eq 'symbol-of-user-var' \
  "$(run '(def zzz 1) (prn (symbol #'"'"'zzz))')" \
  'user/zzz'

assert_eq 'symbol-of-var-eq' \
  "$(run '(def zzz 1) (prn (= (symbol #'"'"'zzz) (quote user/zzz)))')" \
  'true'

# var in another ns keeps that ns
assert_eq 'symbol-of-var-other-ns' \
  "$(run '(ns aa) (def q 1) (ns bb) (prn (symbol #'"'"'aa/q))')" \
  'aa/q'
