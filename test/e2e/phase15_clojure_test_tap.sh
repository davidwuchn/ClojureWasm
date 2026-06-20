#!/usr/bin/env bash
# clojure.test.tap backfill (D-273) — TAP (Test Anything Protocol) output for
# clojure.test. `with-tap-output` rebinds clojure.test/report (now ^:dynamic) to a
# TAP reporter emitting `ok` / `not ok` lines + `#` diagnostics + a `1..n` plan. Built
# on clj-compat clojure.test surface added here: with-test-out / inc-report-counter /
# testing-vars-str / testing-contexts-str / *testing-vars* / *stack-trace-depth*
# (also useful for running real clojure.test suites, D-232). Uses clojure.stacktrace
# (D-273) for the actual-trace diagnostic. Java `.split` → clojure.string/split-lines.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() {
    local name="$1"; local got="$2"; local want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> ok"
}

# with-tap-output emits valid TAP: ok / not ok lines (named by the test var) +
# `#` diagnostics + the trailing `1..n` plan.
got=$("$BIN" - <<'EOF' 2>/dev/null
(require '[clojure.test :as t] '[clojure.test.tap :as tap])
(t/deftest pass-t (t/is (= 1 1)))
(t/deftest fail-t (t/is (= 1 2)))
(print (with-out-str (tap/with-tap-output (t/run-tests 'user))))
EOF
)
# run-tests emits the full lifecycle event set — :begin-test-ns, :begin/:end-test-var
# (per test), :end-test-ns — which tap's `:default` renders as `# {…}` comment
# lines, EXACTLY as clj's tap does (clj-verified 2026-06-21). cljw omits only the
# ` (file:line)` source suffix on ok/not-ok and the ns identity-hash in the
# begin/end-test-ns map (no source location / JVM identity — AD-041 / AD-002);
# every other byte matches clj. Names render via testing-vars-str `(test-name)`;
# `=` actual is the bare (not (= …)) form (D-463).
want='# {:type :begin-test-ns, :ns user}
# {:type :begin-test-var, :var #'\''user/pass-t}
ok (pass-t)
# expected:(= 1 1)
#   actual:(= 1 1)
# {:type :end-test-var, :var #'\''user/pass-t}
# {:type :begin-test-var, :var #'\''user/fail-t}
not ok (fail-t)
# expected:(= 1 2)
#   actual:(not (= 1 2))
# {:type :end-test-var, :var #'\''user/fail-t}
# {:type :end-test-ns, :ns user}
1..2'
assert_eq 'tap_output' "$got" "$want"

echo
echo "clojure.test.tap backfill (D-273) e2e: all green."
