#!/usr/bin/env bash
# test/e2e/phase6_16_c_walk_pattern_a.sh
#
# Phase 6.16.c Group A — clojure.walk Pattern A migration of
# `prewalk` + `postwalk`. v5 §9.1. Other vars (`keywordize-keys`,
# `stringify-keys`, `prewalk-replace`, `postwalk-replace`,
# `prewalk-demo`, `postwalk-demo`, `macroexpand-all`) land in
# subsequent groups within Phase 6.16.c.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
zig build >/dev/null

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

# --- (1) prewalk identity on a vector → unchanged ---
got="$("$BIN" -e "(clojure.walk/prewalk (fn* [x] x) [1 2 3])")"
assert_eq 'prewalk_identity_vector' "$got" '[1 2 3]'

# --- (2) postwalk inc on nested vector → all leaves incremented ---
got="$("$BIN" -e "(clojure.walk/postwalk (fn* [x] (if (integer? x) (inc x) x)) [1 [2 3]])")"
assert_eq 'postwalk_inc_nested' "$got" '[2 [3 4]]'

# --- (3) prewalk wraps before recursion: increments are applied before
# children are visited. With a fn that only acts on integers, both pre-
# and post- give the same shape, but the recursion direction differs;
# this asserts the pre-order produces the correct shape, not the order. ---
got="$("$BIN" -e "(clojure.walk/prewalk (fn* [x] (if (integer? x) (inc x) x)) [10 [20 30]])")"
assert_eq 'prewalk_inc_nested' "$got" '[11 [21 31]]'

# --- (4) postwalk on a quoted list ---
got="$("$BIN" -e "(clojure.walk/postwalk (fn* [x] x) '(1 2 3))")"
assert_eq 'postwalk_identity_list' "$got" '(1 2 3)'

echo ""
echo "=== phase6_16_c_walk_pattern_a: all assertions passed ==="
