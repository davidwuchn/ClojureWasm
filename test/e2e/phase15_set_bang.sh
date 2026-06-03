#!/usr/bin/env bash
# test/e2e/phase15_set_bang.sh — the `set!` special form on dynamic vars.
# `(set! v val)` updates the innermost active thread binding for v, or (when
# none is active) the Var root — covering top-level compiler-flag vars like
# *warn-on-reflection*. Non-dynamic target / wrong arity / field-set form
# raise clean errors. clj-grounded. Validation-campaign: string.clj opens
# with `(set! *warn-on-reflection* true)`. Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# set! within a binding mutates the current thread binding
assert_eq 'bind-set'   "$("$BIN" -e '(def ^:dynamic *x* 1) (binding [*x* 10] (set! *x* 99) *x*)' 2>&1 | tail -1)" '99'
# set! returns the assigned value
assert_eq 'set-ret'    "$("$BIN" -e '(def ^:dynamic *x* 1) (binding [*x* 0] (set! *x* 5))' 2>&1 | tail -1)" '5'
# after the binding pops, the root is restored (set! touched the frame only)
assert_eq 'frame-only' "$("$BIN" -e '(def ^:dynamic *x* 1) (do (binding [*x* 0] (set! *x* 5)) *x*)' 2>&1 | tail -1)" '1'
# top-level set! (no frame) writes the root
assert_eq 'root-set'   "$("$BIN" -e '(def ^:dynamic *x* 1) (set! *x* 8) *x*' 2>&1 | tail -1)" '8'
# *warn-on-reflection* (compiler-flag dynamic var) is set!-able at top level
assert_eq 'warn-refl'  "$("$BIN" -e '(set! *warn-on-reflection* true)' 2>&1 | tail -1)" 'true'
# error: set! on a non-dynamic var
assert_eq 'not-dyn'    "$("$BIN" -e '(def y 1) (set! y 2)' 2>&1 | tail -1)" "Can't set! non-dynamic var: y"
# error: wrong arity
assert_eq 'arity'      "$("$BIN" -e '(set! *warn-on-reflection*)' 2>&1 | tail -1)" 'set! expects 2 args, got 1'

echo "OK — phase15_set_bang (7 cases) green"
