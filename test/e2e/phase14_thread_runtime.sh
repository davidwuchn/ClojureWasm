#!/usr/bin/env bash
# test/e2e/phase14_thread_runtime.sh — D-425 singleton host objects.
# Thread/currentThread + .getName and Runtime/getRuntime + .availableProcessors.
# Both return a process-lifetime host_instance SINGLETON (cached on rt), so
# identity holds across calls (clj-faithful). cljw runs user code on one thread
# (name "main"); availableProcessors reports the host CPU count.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

assert_eq 'thread_name'      "$("$BIN" -e '(.getName (Thread/currentThread))' 2>/dev/null | tail -1)" '"main"'
assert_eq 'thread_name_fqcn' "$("$BIN" -e '(.getName (java.lang.Thread/currentThread))' 2>/dev/null | tail -1)" '"main"'
assert_eq 'thread_singleton' "$("$BIN" -e '(identical? (Thread/currentThread) (Thread/currentThread))' 2>/dev/null | tail -1)" 'true'
assert_eq 'rt_procs_pos'     "$("$BIN" -e '(pos? (.availableProcessors (Runtime/getRuntime)))' 2>/dev/null | tail -1)" 'true'
assert_eq 'rt_procs_int'     "$("$BIN" -e '(integer? (.availableProcessors (Runtime/getRuntime)))' 2>/dev/null | tail -1)" 'true'
assert_eq 'rt_singleton'     "$("$BIN" -e '(identical? (Runtime/getRuntime) (Runtime/getRuntime))' 2>/dev/null | tail -1)" 'true'

echo "OK — phase14_thread_runtime (6 cases) green"
