#!/usr/bin/env bash
# test/e2e/phase14_realworld_program.sh
#
# Whole-program integration regression guard (clj-parity campaign, 2026-06-18).
# Runs test/e2e/fixtures/realworld_mixed.clj — a realistic multi-feature program
# (lazy seqs, loop/recur bignum, atoms, try/catch, case, when-let, sorted-map
# equality, transients, threading, get-in/assoc-in, for-with-:when) — and asserts
# every output line. All lines are byte-identical to JVM Clojure (verified by a
# `diff` of cljw vs `clj` output). A single-expr sweep cannot catch a cross-
# feature integration regression; this does.
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }

out="$("$BIN" test/e2e/fixtures/realworld_mixed.clj 2>&1)" || fail "non-zero exit: $out"

want="fib: (0 1 1 2 3 5 8 13 21 34)
fact: 2432902008176640000
div: 5 :div0
case: (:zero :one :two :zero :one :two)
when-let: 80
sorted: {0 0, 1 1, 2 4, 3 9, 4 16} =hash: true first: [0 0]
transient: [0 1 2 3 4]
threading: 33
get-in: 42 {:a {:b {:c 99}}}
for: ([0 1] [0 2] [1 2])"

if [[ "$out" == "$want" ]]; then
    echo "PASS realworld_mixed -> all 10 lines clj-identical"
else
    echo "--- got ---"; echo "$out"
    echo "--- want ---"; echo "$want"
    fail "realworld_mixed: output mismatch"
fi

echo "OK — phase14_realworld_program green"
