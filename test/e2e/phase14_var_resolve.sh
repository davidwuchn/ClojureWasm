#!/usr/bin/env bash
# test/e2e/phase14_var_resolve.sh
#
# Var surface: (def x ..) / (defn ..) return a runtime var_ref Value that
# prints as the var-quote form #'ns/name (not the generic #<var_ref>).
# resolve cases land alongside in a later cycle.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() {
    echo "FAIL $1" >&2
    exit 1
}

assert_eq() {
    local name="$1"
    local got="$2"
    local want="$3"
    if [[ "$got" != "$want" ]]; then
        fail "$name: got '$got', want '$want'"
    fi
    echo "PASS $name -> $want"
}

# --- Case 1: (def x 1) prints the var-quote form #'user/x ---
assert_eq 'def_returns_var_quote' "$("$BIN" -e '(def x 1)' 2>/dev/null | tail -1)" "#'user/x"

# --- Case 2: (defn f [] 1) prints #'user/f ---
assert_eq 'defn_returns_var_quote' "$("$BIN" -e '(defn f [] 1)' 2>/dev/null | tail -1)" "#'user/f"

echo "OK — phase14_var_resolve (2 cases) green"
