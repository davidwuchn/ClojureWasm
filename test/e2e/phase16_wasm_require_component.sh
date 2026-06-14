#!/usr/bin/env bash
# test/e2e/phase16_wasm_require_component.sh — W1 require-a-component (D-404 / ADR-0135).
# A Wasm component's exports become callable Vars in a namespace via
# cljw.wasm/require-component (a thin Clojure layer over the wasm/ primitives +
# clojure.core/intern). Exercises: :as ns creation, export-name cleanup
# (#[constructor]/#[method] markers stripped), cached-handle reuse, resource chain.
#
# OPT-IN, like phase16_wasm_component.sh: builds `-Dwasm` and is NOT in the default
# per-commit gate. During the local-accumulation phase the zwasm dep resolves via
# the RELATIVE-path zon (sibling ../zwasm_from_scratch with REQ-7), so Mac-local.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
fail() { echo "FAIL $1" >&2; exit 1; }

if [ -z "${CLJW_SKIP_BUILD:-}" ] && ! zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null 2>&1; then
  fail "zig build -Dwasm failed (zwasm dep unresolved? need ../zwasm_from_scratch with REQ-7)"
fi
"$BIN" --version | grep -q wasm || fail "cljw is not wasm-enabled ($("$BIN" --version)) — zwasm did not resolve"

out="$("$BIN" test/e2e/fixtures/wasm_require_component_probe.clj 2>&1)" || fail "cljw exited non-zero:
$out"

for marker in \
  "PASS require-component-greet" \
  "PASS require-component-reuse" \
  "PASS require-component-resource"; do
  echo "$out" | grep -q "$marker" || fail "missing: $marker
$out"
done
echo "$out" | grep -q "^DONE$" || fail "fixture did not run to completion:
$out"

# A non-wasm build must NOT resolve cljw.wasm (the wasm/ ns is absent) — the
# gating is verified implicitly by the default gate (this step is -Dwasm-only).

echo
echo "Phase 16 / wasm require-a-component (W1): all green."
