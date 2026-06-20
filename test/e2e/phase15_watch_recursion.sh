#!/usr/bin/env bash
# test/e2e/phase15_watch_recursion.sh
#
# A watch fn that re-triggers its own atom (`(add-watch a :w (fn [k r o n]
# (swap! r inc)))`) recurses notify→swap!→notify in native Zig frames the VM
# frame budget cannot see — without a guard it overflowed the NATIVE stack
# (SIGSEGV / exit 134). The watch-nesting guard (iref.enterWatchNotify, cap 256)
# converts the runaway into a graceful, NON-crashing "Stack overflow" error.
# clj raises a (catchable) StackOverflowError here; cljw's is a clean
# resource-exhausted error (still uncatchable — D-485 RELATED). Legit shallow
# watch chains stay unaffected. Surfaced by the atom differential sweep (D-485).
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq()  { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_has() { local n="$1" g="$2" w="$3"; [[ "$g" == *"$w"* ]] || fail "$n: '$g' lacks '$w'"; echo "PASS $n =~ $w"; }

# (1) a self-triggering watch errors gracefully — NO segfault (exit must be a
# clean non-crash; a SIGSEGV would be 139 and print nothing parseable).
out="$("$BIN" -e '(let [a (atom 0)] (add-watch a :w (fn [k r o n] (swap! r inc))) (swap! a inc))' 2>&1 || true)"
rc=$?
assert_has 'watch_recursion_graceful' "$out" 'Stack overflow'
# exit 139 (128+SIGSEGV) would mean it still crashed.
[[ "$rc" != 139 ]] || fail "watch_recursion_segfault: exited 139 (SIGSEGV)"
echo "PASS watch_recursion_no_segfault (exit=$rc)"

# (2) a legit watch (a updates a DIFFERENT atom b) still fires once, correctly.
assert_eq 'legit_watch_chain' \
  "$("$BIN" -e '(let [a (atom 0) b (atom 0)] (add-watch a :w (fn [k r o n] (reset! b (* 10 n)))) (swap! a inc) [@a @b])')" \
  '[1 10]'

# (3) a watch that updates a 2nd watched atom (2-level chain) works.
assert_eq 'two_level_watch' \
  "$("$BIN" - <<'EOF'
(let [a (atom 0) b (atom 0) log (atom [])]
  (add-watch a :wa (fn [k r o n] (reset! b (inc n))))
  (add-watch b :wb (fn [k r o n] (swap! log conj n)))
  (swap! a inc)
  (prn @log))
EOF
)" '[2]'

# (4) ADR-0157 2b: the watch-overflow stack_overflow is CATCHABLE (own Kind →
# StackOverflowError ⊂ Error ⊂ Throwable), matching clj — was uncatchable
# (resource_exhausted → null). Catchable by StackOverflowError / Error / Throwable.
WREC='(let [a (atom 0)] (add-watch a :w (fn [k r o n] (swap! r inc))) (swap! a inc))'
assert_eq 'catch_as_stackoverflow' "$("$BIN" -e "(try $WREC (catch StackOverflowError e :caught))")" ':caught'
assert_eq 'catch_as_throwable'     "$("$BIN" -e "(try $WREC (catch Throwable e :caught))")" ':caught'
# It is an Error, NOT an Exception — (catch Exception …) must NOT catch it; it
# falls through to the (catch Throwable …) clause (clj parity).
assert_eq 'catch_not_as_exception' \
  "$("$BIN" -e "(try $WREC (catch Exception e :as-exc) (catch Throwable e :as-thr))")" ':as-thr'

echo ""
echo "=== phase15_watch_recursion: all assertions passed ==="
