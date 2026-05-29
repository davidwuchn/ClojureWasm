#!/usr/bin/env bash
# test/e2e/phase14_assert_distinct.sh
#
# D-134 — assert (macro) + distinct? (fn). assert -> (if expr nil (throw
# (ex-info MSG {:form 'expr}))); distinct? -> true iff no two args equal
# (a set dedups by =, so distinct <=> the set keeps every element).
# distinct? is core.clj (rides the AOT blob); assert is a Zig macro.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() {
    local name="$1"; local got="$2"; local want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> $want"
}

# distinct?
assert_eq 'distinct_all'  "$("$BIN" -e '(distinct? 1 2 3)')"     'true'
assert_eq 'distinct_dup'  "$("$BIN" -e '(distinct? 1 2 2)')"     'false'
assert_eq 'distinct_kw'   "$("$BIN" -e '(distinct? :a :b :a)')"  'false'
assert_eq 'distinct_one'  "$("$BIN" -e '(distinct? 1)')"         'true'
# assert passes -> nil
assert_eq 'assert_pass'   "$("$BIN" -e '(assert (= 1 1))')"      'nil'
assert_eq 'assert_true'   "$("$BIN" -e '(assert true)')"         'nil'
# assert fails -> throws (default + custom message)
out="$("$BIN" -e '(assert false)' 2>&1 || true)"
[[ "$out" == *"Assert failed"* ]] || fail "assert_fail_default: got '$out'"
echo "PASS assert_fail_default -> Assert failed"
out="$("$BIN" -e '(assert (= 1 2) "one is not two")' 2>&1 || true)"
[[ "$out" == *"one is not two"* ]] || fail "assert_fail_msg: got '$out'"
echo "PASS assert_fail_msg -> one is not two"

echo "OK — phase14_assert_distinct smoke (8 cases) green"
