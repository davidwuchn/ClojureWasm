#!/usr/bin/env bash
# scripts/ci_gate.sh — single source of truth for the HOST-LOCAL verification
# gate. Both CI (.github/workflows/ci.yml, once per matrix OS) and the local
# maintainer flow run this exact script, so CI can never verify LESS than the
# per-host gate. It checks the CURRENT host only; multi-host fan-out is the
# caller's job (the CI matrix / scripts/run_remote_ubuntu.sh's SSH leg).
#
# Steps (every OS):
#   1. zig fmt --check src/          — formatting
#   2. test/run_all.sh --serial-e2e  — the full gate: `zig build test` x2 (the
#        F-012 dual-backend diff oracle + every unit), zlinter, a ReleaseSafe
#        build_cljw, zone_check, corpus_regression, and every e2e step.
#
# --serial-e2e (not the -P8 parallel default) is deliberate: the parallel path
# can flake the D-418/D-258 agent send/await load-race under scheduler pressure,
# which is exactly what a shared CI runner provides. Serial is the authoritative
# full-gate mode (see .dev/handover.md).
#
# The gate has no external runtime dependency beyond Zig 0.16.0 and python3
# (one nREPL e2e uses a small python client); every Wasm fixture is a committed
# .wasm, and the diff oracle is Zig-native (no JVM Clojure oracle in the gate).
#
# Usage: bash scripts/ci_gate.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[ci_gate] host: $(uname -s) — zig $(zig version)"

echo "[ci_gate] (1/2) zig fmt --check src/"
zig fmt --check src/

echo "[ci_gate] (2/2) full gate: test/run_all.sh --serial-e2e"
bash test/run_all.sh --serial-e2e

echo "[ci_gate] OK ($(uname -s))"
