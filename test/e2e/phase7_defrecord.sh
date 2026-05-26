#!/usr/bin/env bash
# test/e2e/phase7_defrecord.sh
#
# Phase 7 §9.9 row 7.4 cycle 1 — defrecord macro skeleton smoke.
# Validates the cycle-1 surface:
#   - `(defrecord Foo [x y])` parses cleanly (no STAGED_UNSUPPORTED_FORMS
#     raise; row 7.4 cycle 1 retired the wedge).
#   - Lowering via `expandDefrecord` produces `(do (deftype Foo [x y]))`,
#     so the underlying TypeDescriptor allocates with `.kind = .deftype`
#     today. Cycle 2 will flip `.kind = .defrecord` via the
#     `rt/__defrecord!` primitive.
#   - Constructor + field access still work (inherited from the
#     deftype skeleton landed at Phase 5 task 5.12.a).
#
# OUT OF SCOPE for cycle 1: `(:field rec)` implicit IPersistentMap
# routing (cycle 3), `(assoc rec :k v)` (cycle 4), `->Foo` positional
# factory + protocol-method bodies (cycle 5), `record?` predicate
# (cycle 6).
#
# stderr captured for diagnostic cases only.

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

last_line() {
    awk 'END { print }' <<< "$1"
}

# --- Case 1: defrecord parses cleanly + ctor + field access ---
got=$("$BIN" - <<'EOF' 2>/dev/null
(defrecord Point [x y])
(.x (Point. 3 4))
EOF
) || fail "case1: non-zero exit ($got)"
assert_eq 'defrecord_ctor_field_access' "$(last_line "$got")" '3'

# --- Case 2: defrecord field y access ---
got=$("$BIN" - <<'EOF' 2>/dev/null
(defrecord Point [x y])
(.y (Point. 3 4))
EOF
) || fail "case2: non-zero exit ($got)"
assert_eq 'defrecord_field_y_access' "$(last_line "$got")" '4'

# --- Case 3: defrecord with no field vector raises defrecord_form_incomplete ---
diag=$("$BIN" -e '(defrecord Foo)' 2>&1 || true)
if [[ "$diag" != *"defrecord requires"* ]]; then
    fail "case3: expected defrecord_form_incomplete, got '$diag'"
fi
echo "PASS defrecord_form_incomplete_diagnostic"

# --- Case 4: defrecord with non-symbol name raises defrecord_name_invalid ---
diag=$("$BIN" -e '(defrecord "Foo" [x])' 2>&1 || true)
if [[ "$diag" != *"defrecord name"* ]]; then
    fail "case4: expected defrecord_name_invalid, got '$diag'"
fi
echo "PASS defrecord_name_invalid_diagnostic"

# --- Case 5: defrecord with non-vector fields raises defrecord_fields_not_vector ---
diag=$("$BIN" -e '(defrecord Foo "x")' 2>&1 || true)
if [[ "$diag" != *"defrecord fields"* ]]; then
    fail "case5: expected defrecord_fields_not_vector, got '$diag'"
fi
echo "PASS defrecord_fields_not_vector_diagnostic"

echo "OK — phase7_defrecord smoke (5 cases) green"
