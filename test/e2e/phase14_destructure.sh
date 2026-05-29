#!/usr/bin/env bash
# test/e2e/phase14_destructure.sh
#
# §A26 coverage-floor — D-076 destructuring cycle 1: SEQUENTIAL vector
# patterns in `let`, lowered to plain-symbol let* + nth/nthnext at the
# macro layer (expandLet, JVM clojure.core/destructure shape).
#
# Validates: [a b] / [a b & rest] / [a b :as all] / nested / missing→nil
# / sequential-dependency / the all-symbols fast path (zero regression).
# Associative {:keys}, fn-param, and loop* destructuring are deferred
# (D-076 follow-up) and raise a clear error — checked here too.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() {
    local name="$1"; local got="$2"; local want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> $want"
}

assert_eq 'seq_basic'   "$("$BIN" -e '(let [[a b] [1 2]] (+ a b))')"            '3'
assert_eq 'seq_rest'    "$("$BIN" -e '(let [[a b & r] [1 2 3 4]] r)')"          '(3 4)'
assert_eq 'seq_as'      "$("$BIN" -e '(let [[a b :as all] [1 2]] all)')"        '[1 2]'
assert_eq 'seq_nested'  "$("$BIN" -e '(let [[[a b] c] [[1 2] 3]] (+ a b c))')"  '6'
assert_eq 'seq_missing' "$("$BIN" -e '(let [[a b] [1]] b)')"                    'nil'
assert_eq 'seq_depends' "$("$BIN" -e '(let [[a b] [1 2] c (+ a b)] c)')"        '3'
assert_eq 'seq_rest_only' "$("$BIN" -e '(let [[& r] [1 2 3]] r)')"             '(1 2 3)'
# Fast path (all plain symbols) — must be byte-for-byte unchanged.
assert_eq 'fastpath'    "$("$BIN" -e '(let [x 1 y 2] (+ x y))')"                '3'

# --- deferred scope raises a clear error (not a silent wrong answer) ---
diag=$("$BIN" -e '(let [{:keys [a]} {:a 1}] a)' 2>&1 || true)
[[ "$diag" == *"associative"* ]] || fail "assoc_deferred: expected 'associative ... destructuring' error, got '$diag'"
echo "PASS assoc_deferred_raises"

echo "OK — phase14_destructure smoke (9 cases) green"
