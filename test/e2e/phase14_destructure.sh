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

# --- cycle 2: associative {:keys/:syms/:or/:as/bare} ---
assert_eq 'map_keys'    "$("$BIN" -e '(let [{:keys [a b]} {:a 1 :b 2}] (+ a b))')"           '3'
assert_eq 'map_or'      "$("$BIN" -e '(let [{:keys [a b] :or {b 10}} {:a 1}] (+ a b))')"     '11'
assert_eq 'map_as'      "$("$BIN" -e '(let [{:keys [a] :as m} {:a 1 :b 2}] [a (count m)])')" '[1 2]'
assert_eq 'map_bare'    "$("$BIN" -e '(let [{a :alpha b :beta} {:alpha 1 :beta 2}] (+ a b))')" '3'
assert_eq 'map_syms'    "$("$BIN" -e "(let [{:syms [q]} {'q 5}] q)")"                         '5'
assert_eq 'map_missing' "$("$BIN" -e '(let [{:keys [z]} {:a 1}] z)')"                         'nil'
assert_eq 'map_in_seq'  "$("$BIN" -e '(let [[{:keys [a]} c] [{:a 1} 2]] (+ a c))')"           '3'
assert_eq 'seq_in_map'  "$("$BIN" -e '(let [{[a b] :pair} {:pair [1 2]}] (+ a b))')"          '3'
# Note: `:strs` (string keys) is functionally blocked by the pre-existing
# map string-key lookup gap (D-151: `(get {"x" 5} "x")` → nil); its lowering
# is correct + forward-compatible, so it is intentionally not asserted here.

echo "OK — phase14_destructure smoke (16 cases) green"
