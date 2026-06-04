#!/usr/bin/env bash
# test/e2e/phase15_stm_dosync.sh
#
# Phase B #5 (STM) step (i) — the single-ref LockingTransaction slice:
# (dosync ...) + (ref-set r v) + (alter r f & args), single thread.
# Multi-ref lock ordering, retry-on-conflict + concurrent serializability,
# commute, and ensure are later increments (#5-ii .. #5-v). The engine is
# `runtime/concurrency/lock_tx.zig`; the surface is `lang/primitive/stm.zig`.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
last_line() { tail -n 1; }
assert_eq() {
    local name="$1"; local got="$2"; local want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> $want"
}

# ref-set inside a transaction commits the new value.
got=$("$BIN" -e '(let [r (ref 0)] (dosync (ref-set r 42)) @r)' 2>/dev/null | last_line)
assert_eq 'dosync_ref_set' "$got" '42'

# alter applies (f current & args) and commits.
got=$("$BIN" -e '(let [r (ref 0)] (dosync (alter r + 5)) @r)' 2>/dev/null | last_line)
assert_eq 'dosync_alter' "$got" '5'

# A transaction sees its OWN writes across multiple ops on one ref.
got=$("$BIN" -e '(let [r (ref 10)] (dosync (alter r + 1) (alter r * 2)) @r)' 2>/dev/null | last_line)
assert_eq 'dosync_sees_own_writes' "$got" '22'

# ref-set then alter: the alter reads the in-txn ref-set value, not the
# committed one.
got=$("$BIN" -e '(let [r (ref 0)] (dosync (ref-set r 5) (alter r inc)) @r)' 2>/dev/null | last_line)
assert_eq 'dosync_in_txn_read' "$got" '6'

# Nested dosync reuses the outer transaction (one commit).
got=$("$BIN" -e '(let [r (ref 0)] (dosync (alter r inc) (dosync (alter r inc))) @r)' 2>/dev/null | last_line)
assert_eq 'dosync_nested' "$got" '2'

# alter / ref-set outside a transaction is a clean error, not a crash.
diag=$("$BIN" -e '(alter (ref 0) inc)' 2>&1 || true)
case "$diag" in
    *"must be called inside a (dosync"*|*"transaction"*)
        echo "PASS alter_out_of_txn_errors -> diagnostic" ;;
    *)
        fail "alter_out_of_txn_errors: expected a no-transaction diagnostic, got '$diag'" ;;
esac

echo
echo "Phase B #5 STM dosync/ref-set/alter (single-ref) e2e: all green."
