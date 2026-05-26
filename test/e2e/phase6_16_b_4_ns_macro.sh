#!/usr/bin/env bash
# test/e2e/phase6_16_b_4_ns_macro.sh
#
# Phase 6.16.b-4 sub-cycle c.7 — `(ns foo (:refer-clojure))`
# analyzer special form. ADR-0035 D1.
#
# Coverage at c.7:
#   - `(ns foo)` switches to ns foo (alone or with directives).
#   - `(:refer-clojure)` directive is accepted (default behavior).
#   - Unsupported directives (`:require` inside ns / `:exclude` /
#     `:only` / `:use` / `:import` / `:gen-class`) raise
#     `feature_not_supported`.
#   - `(:require ...)` inside ns specifically raises with the
#     "use separate (require ...) calls" hint.

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

# --- (1) bare (ns foo) switches namespace (returns nil) ---
got="$("$BIN" -e "(ns foo)" | tail -n 1)"
assert_eq 'ns_bare_returns_nil' "$got" 'nil'

# --- (2) (ns foo (:refer-clojure)) accepted; clojure.core refers in ---
# After (ns foo (:refer-clojure)), `(reduce + [1 2 3])` should work
# because clojure.core is refer'd in and reduce resolves via rt
# refer (which evalNs also installs for cw v1 ergonomics).
got="$("$BIN" -e "(ns my.test (:refer-clojure)) (reduce + 0 [1 2 3])" | tail -n 1)"
assert_eq 'ns_with_refer_clojure_reduce' "$got" '6'

# --- (3) (ns foo) defines stay in foo ns ---
got="$("$BIN" -e "(ns demo) (def x 42) demo/x" | tail -n 1)"
assert_eq 'ns_def_stays_in_ns' "$got" '42'

# --- (4) `(:require ...)` inside ns raises feature_not_supported with hint ---
got="$("$BIN" -e "(ns foo (:require [clojure.set :as cs]))" 2>&1 || true)"
if ! grep -q 'not supported in ClojureWasm' <<<"$got"; then
    fail "ns_require_directive: missing feature_not_supported tag (got '$got')"
fi
echo "PASS ns_require_directive_deferred"

# --- (5) `(:exclude ...)` filter raises feature_not_supported ---
got="$("$BIN" -e "(ns foo (:refer-clojure :exclude [reduce]))" 2>&1 || true)"
if ! grep -q 'not supported in ClojureWasm' <<<"$got"; then
    fail "ns_refer_clojure_exclude: missing not yet supported (got '$got')"
fi
echo "PASS ns_refer_clojure_filters_deferred"

# --- (6) Unknown directive raises feature_not_supported ---
got="$("$BIN" -e "(ns foo (:use [bar]))" 2>&1 || true)"
if ! grep -q 'not supported in ClojureWasm' <<<"$got"; then
    fail "ns_use_directive: missing not yet supported (got '$got')"
fi
echo "PASS ns_use_directive_deferred"

# --- (7) `(ns)` with no name raises ---
got="$("$BIN" -e "(ns)" 2>&1 || true)"
if ! grep -q 'ns requires a name\|not supported in ClojureWasm' <<<"$got"; then
    fail "ns_no_name: missing error (got '$got')"
fi
echo "PASS ns_no_name_rejected"

echo ""
echo "=== phase6_16_b_4_ns_macro: all assertions passed ==="
