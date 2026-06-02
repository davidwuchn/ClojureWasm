#!/usr/bin/env bash
# test/e2e/phase14_atom_watch.sh — atom add-watch / remove-watch (D-157, ADR-0081).
# Watches fire SYNCHRONOUSLY on swap!/reset!/compare-and-set! with (key ref old
# new), on EVERY change incl. old==new; add-watch replaces by key; remove-watch
# is a no-op if absent; both return the ref. Single-watch cases are order-
# deterministic (multi-watch notification order is clj-undefined). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# fires on swap! and reset! with [key old new]
assert_eq 'fire' "$("$BIN" -e '(let [log (atom []) a (atom 0)] (add-watch a :k (fn [k r o n] (swap! log conj [k o n]))) (swap! a inc) (reset! a 10) @log)')" '[[:k 0 1] [:k 1 10]]'
# the watched fn receives the ref itself (identical)
assert_eq 'ref_arg' "$("$BIN" -e '(let [seen (atom nil) a (atom 0)] (add-watch a :k (fn [k r o n] (reset! seen (identical? r a)))) (swap! a inc) @seen)')" 'true'
# add-watch / remove-watch return the ref
assert_eq 'add_ret' "$("$BIN" -e '(let [a (atom 0)] (identical? a (add-watch a :k (fn [k r o n] nil))))')" 'true'
assert_eq 'rm_ret'  "$("$BIN" -e '(let [a (atom 0)] (identical? a (remove-watch a :k)))')" 'true'
# remove-watch stops notifications
assert_eq 'remove' "$("$BIN" -e '(let [log (atom []) a (atom 0)] (add-watch a :k (fn [k r o n] (swap! log conj :a))) (remove-watch a :k) (swap! a inc) @log)')" '[]'
# add-watch with an existing key REPLACES
assert_eq 'replace' "$("$BIN" -e '(let [log (atom []) a (atom 0)] (add-watch a :k (fn [k r o n] (swap! log conj :v1))) (add-watch a :k (fn [k r o n] (swap! log conj :v2))) (swap! a inc) @log)')" '[:v2]'
# fires even when old == new (reset! to the same value)
assert_eq 'fire_eq' "$("$BIN" -e '(let [log (atom []) a (atom 1)] (add-watch a :k (fn [k r o n] (swap! log conj n))) (reset! a 1) @log)')" '[1]'
# compare-and-set! fires on success, not on failure
assert_eq 'cas' "$("$BIN" -e '(let [log (atom []) a (atom 5)] (add-watch a :k (fn [k r o n] (swap! log conj [o n]))) (compare-and-set! a 5 9) (compare-and-set! a 5 99) @log)')" '[[5 9]]'
# a watch on a zero-watch atom path: no watch → no error, swap! works
assert_eq 'nowatch' "$("$BIN" -e '(let [a (atom 0)] (swap! a inc) @a)')" '1'

echo "OK — phase14_atom_watch (9 cases) green"
