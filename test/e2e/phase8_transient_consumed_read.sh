#!/usr/bin/env bash
# test/e2e/phase8_transient_consumed_read.sh
#
# A transient is DEAD after `persistent!` — not only for writes (conj!/assoc!/…)
# but for READS too (count/nth/get/contains?). clj throws
# IllegalStateException "Transient used after persistent! call" on any use of a
# consumed transient; cljw had the `consumed` guard on write ops only, so reads
# silently returned stale values. Surfaced by the transient differential sweep
# (a read on a spent transient must error, clj parity). Reads on a LIVE transient
# stay valid (count/nth/get all work pre-persistent!).
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq()  { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_has() { local n="$1" g="$2" w="$3"; [[ "$g" == *"$w"* ]] || fail "$n: '$g' lacks '$w'"; echo "PASS $n =~ $w"; }

# --- LIVE transient reads still work (no over-correction) ---
assert_eq 'live_count' "$("$BIN" -e '(count (transient [1 2 3]))')" '3'
assert_eq 'live_get'   "$("$BIN" -e '(get (transient {:a 1}) :a)')" '1'
assert_eq 'live_nth'   "$("$BIN" -e '(nth (transient [10 20]) 1)')" '20'

# --- CONSUMED transient reads throw "Transient used after persistent! call" ---
for op in '(count t)' '(nth t 0)' '(get t 0)' '(contains? t 0)'; do
  out="$("$BIN" -e "(let [t (transient [1 2])] (persistent! t) $op)" 2>&1 || true)"
  assert_has "consumed_vec_${op}" "$out" 'Transient used after persistent! call'
done
for op in '(count t)' '(get t :a)' '(contains? t :a)'; do
  out="$("$BIN" -e "(let [t (transient {:a 1})] (persistent! t) $op)" 2>&1 || true)"
  assert_has "consumed_map_${op}" "$out" 'Transient used after persistent! call'
done
out="$("$BIN" -e '(let [t (transient #{1 2})] (persistent! t) (count t))' 2>&1 || true)"
assert_has 'consumed_set_count' "$out" 'Transient used after persistent! call'
out="$("$BIN" -e '(let [t (transient #{1 2})] (persistent! t) (contains? t 1))' 2>&1 || true)"
assert_has 'consumed_set_contains' "$out" 'Transient used after persistent! call'

echo ""
echo "=== phase8_transient_consumed_read: all assertions passed ==="
