#!/usr/bin/env bash
# test/e2e/phase7_defmacro_private.sh
#
# `(defmacro ^:private m ...)` must set the Var's private FLAG, not just lift
# `:private` into Var.meta — so the macro is excluded from `ns-publics` and a
# cross-ns qualified call is denied, exactly like `def`/`defn`. Surfaced by the
# clojure.math.combinatorics contrib sweep: its private `reify-bool` macro
# leaked into `ns-publics` (clj: absent), because `analyzeDefmacro` built its
# def_node without the `is_private` field `analyzeDef` carries.
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# (1) private macro is excluded from ns-publics (clj parity = false).
got="$("$BIN" - <<'EOF' 2>&1
(defmacro ^:private privmac [] 1)
(prn (contains? (ns-publics *ns*) 'privmac))
EOF
)"
assert_eq 'private_macro_not_in_publics' "$got" 'false'

# (2) the :private flag IS reflected in metadata too (was already true).
got="$("$BIN" - <<'EOF' 2>&1
(defmacro ^:private privmac [] 1)
(prn (boolean (:private (meta #'privmac))))
EOF
)"
assert_eq 'private_macro_meta' "$got" 'true'

# (3) a NON-private macro stays public (no over-correction).
got="$("$BIN" - <<'EOF' 2>&1
(defmacro pubmac [] 1)
(prn (contains? (ns-publics *ns*) 'pubmac))
EOF
)"
assert_eq 'public_macro_in_publics' "$got" 'true'

# (4) ns-interns still lists the private macro (private affects publics, not interns).
got="$("$BIN" - <<'EOF' 2>&1
(defmacro ^:private privmac [] 1)
(prn (contains? (ns-interns *ns*) 'privmac))
EOF
)"
assert_eq 'private_macro_in_interns' "$got" 'true'

echo ""
echo "=== phase7_defmacro_private: all assertions passed ==="
