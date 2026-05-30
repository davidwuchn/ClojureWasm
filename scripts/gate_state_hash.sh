#!/usr/bin/env bash
# scripts/gate_state_hash.sh
#
# Prints a stable fingerprint of the *source* state — src/ + test/ +
# build.zig* — relative to HEAD. Two consumers share it so they agree on
# "what state did the full gate verify":
#
#   - test/run_all.sh writes this hash to .dev/.gate_pass on a full-gate
#     PASS (the state the gate just proved green).
#   - scripts/check_gate_cadence.sh recomputes it at `git commit` time and
#     compares: equal ⇒ the gate verified exactly this commit's content.
#
# The HEAD sha is folded in so a clean tree at two different commits does
# not collide to the same (empty-diff) hash. bench/ is excluded — the gate
# appends to bench/quick_baseline.txt, which is an artefact, not source.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
{
  echo "HEAD:$(git rev-parse HEAD 2>/dev/null || echo none)"
  git diff HEAD -- src test build.zig build.zig.zon 2>/dev/null || true
} | shasum | awk '{print $1}'
