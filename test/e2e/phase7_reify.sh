#!/usr/bin/env bash
# test/e2e/phase7_reify.sh
#
# Phase 7 §9.9 row 7.5 cycle 1 — reify macro skeleton smoke.
# Validates the cycle-1 surface:
#   - `(reify P (m [this] body))` parses cleanly (no
#     STAGED_UNSUPPORTED_FORMS raise; row 7.5 cycle 1 retired the
#     wedge).
#   - The macro lowers to `(rt/__reify! ...)` which is the
#     stubbed primitive — raising `feature_not_supported` with the
#     "impl pending row 7.5 cycle 3" hint.
#   - Syntactic-error diagnostics (missing impl list / bad method form).
#
# Cycle 3 lands the happy path; cycle 4 wires the dispatch arm.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
zig build >/dev/null

fail() {
    echo "FAIL $1" >&2
    exit 1
}

# --- Case 1: reify lowers to __reify! (stub raises pending-impl diagnostic) ---
diag=$("$BIN" - <<'EOF' 2>&1 || true
(defprotocol P (m [this]))
(reify P (m [this] 42))
EOF
)
if [[ "$diag" != *"row 7.5 cycle 3"* ]]; then
    fail "case1: expected cycle-3-pending stub diagnostic, got '$diag'"
fi
echo "PASS reify_macro_lowers_to_stub_primitive"

# --- Case 2: reify with empty form raises reify_form_incomplete ---
diag=$("$BIN" -e '(reify)' 2>&1 || true)
if [[ "$diag" != *"reify requires"* ]]; then
    fail "case2: expected reify_form_incomplete diagnostic, got '$diag'"
fi
echo "PASS reify_form_incomplete_diagnostic"

# --- Case 3: reify with no method-impl section raises section_invalid ---
diag=$("$BIN" - <<'EOF' 2>&1 || true
(defprotocol P (m [this]))
(reify P)
EOF
)
if [[ "$diag" != *"reify section"* ]]; then
    fail "case3: expected reify_section_invalid diagnostic, got '$diag'"
fi
echo "PASS reify_section_invalid_diagnostic"

# --- Case 4: reify with malformed method-impl raises method_invalid ---
diag=$("$BIN" - <<'EOF' 2>&1 || true
(defprotocol P (m [this]))
(reify P (m))
EOF
)
if [[ "$diag" != *"reify method"* ]]; then
    fail "case4: expected reify_method_invalid diagnostic, got '$diag'"
fi
echo "PASS reify_method_invalid_diagnostic"

echo "OK — phase7_reify smoke (4 cases) green"
