#!/usr/bin/env bash
# test/e2e/phase16_wasm_engine_select.sh — ADR-0200 JIT-engine adoption smoke.
# Exercises per-instance engine selection at the cljw surface:
# `(wasm/load path {:engine :jit/:interp})` + `wasm/call`. Asserts the GPR export
# is byte-identical jit==interp (the F-012 differential discipline applied to engine
# choice), the SIMD body runs on the JIT (end-to-end through exportFuncSig, the JIT
# arm zwasm shipped @5b6449779 / from_cljw_02), the SIMD body traps catchably on
# interp (SIMD is JIT-only — to_cljw_03), and the no-opts default rides interp.
#
# Like phase16_wasm_ffi.sh this is OPT-IN: it builds/uses the `-Dwasm` binary (which
# resolves zwasm via the relative-path build.zig.zon experiment), so it is NOT in the
# default per-commit gate's step list while F-001 keeps the default gate zwasm-free.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
fail() { echo "FAIL $1" >&2; exit 1; }

# Honor the gate's shared-binary contract (CLJW_SKIP_BUILD); standalone build
# -Dwasm ReleaseSafe (NOT bare -Dwasm = Debug, ADR-0132).
if [ -z "${CLJW_SKIP_BUILD:-}" ] && ! zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null 2>&1; then
  fail "zig build -Dwasm failed (zwasm dep unresolved?)"
fi
"$BIN" --version | grep -q wasm || fail "cljw is not wasm-enabled ($("$BIN" --version)) — zwasm did not resolve"

out="$("$BIN" test/e2e/fixtures/wasm/jit_engine_select.clj 2>&1)" || fail "fixture exited non-zero:
$out"

# (1) GPR export byte-identical across engines (dual-engine diff oracle).
echo "$out" | grep -q "add-jit: 5"    || fail "add on :jit != 5:
$out"
echo "$out" | grep -q "add-interp: 5" || fail "add on :interp != 5:
$out"

# (2) SIMD body executes JIT-compiled → 42 (end-to-end via wasm/call/exportFuncSig).
echo "$out" | grep -q "lane0-jit: 42" || fail "SIMD lane0 on :jit != 42 (exportFuncSig JIT arm missing?):
$out"

# (3) SIMD body traps a CATCHABLE error on :interp (SIMD is JIT-only in zwasm).
echo "$out" | grep -q "lane0-interp: TRAPPED" || fail "SIMD lane0 on :interp did not trap catchably:
$out"

# (4) no-opts default rides :interp and works (regression guard — .auto-flip reverted).
echo "$out" | grep -q "default: 5" || fail "no-opts default wasm/call broke:
$out"

echo "$out" | grep -q "^DONE$" || fail "fixture did not run to completion:
$out"

echo
echo "Phase 16 / wasm engine selection (ADR-0200 JIT adoption): all green."
