#!/usr/bin/env bash
# test/e2e/phase14_member_on_native.sh
#
# D-371 — clojure.lang read/op methods invoked via `(.member recv …)` on a NATIVE
# collection. clj's native collections implement clojure.lang directly, so
# perf-tuned libs (flatland.ordered's constructors) call `(.valAt m k)` /
# `(.cons coll x)` / `(.count coll)` etc. as Java-interop on Clojure collections.
# A dispatch-level fallback (clojure_lang_method.zig, both backends) maps the
# method name to its clojure.core equivalent (get/conj/count/…). Validates the
# core method set + that a `.member` miss on a NON-collection still errors.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() {
    echo "FAIL $1" >&2
    exit 1
}

# --- Case 1: the core method set on native map / vector (clj-verbatim) ---
got=$("$BIN" - <<'EOF' 2>/dev/null
(prn [(.valAt {:a 1 :b 2} :a)
      (.count [1 2 3])
      (.cons [1 2] 9)
      (.without {:a 1 :b 2} :a)
      (.nth [10 20 30] 1)
      (.containsKey {:a 1} :a)
      (.seq [1 2])
      (.peek [1 2 3])
      (.empty [1 2 3])])
EOF
) || fail "case1: non-zero exit ($got)"
[ "$got" = '[1 3 [1 2 9] {:b 2} 20 true (1 2) 3 []]' ] || fail "case1: got '$got'"

# --- Case 2: valAt 3-arity (not-found) ---
got=$("$BIN" - <<'EOF' 2>/dev/null
(prn (.valAt {:a 1} :z :missing))
EOF
) || fail "case2: non-zero exit ($got)"
[ "$got" = ":missing" ] || fail "case2: expected :missing, got '$got'"

# --- Case 3: a .member miss on a NON-collection still raises (guard holds) ---
out=$("$BIN" -e '(.valAt 42 :a)' 2>&1 || true)
echo "$out" | grep -q "member" || fail "case3: expected a <.member> error on (.valAt 42 :a), got '$out'"

echo "PASS phase14_member_on_native (3 cases)"
