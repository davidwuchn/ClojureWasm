#!/usr/bin/env bash
# check_compat_tiers_sync.sh — pre-commit gate.
# Verifies compat_tiers.yaml entries match actual implementation in
# src/lang/primitive/ and src/runtime/{java,cljw}/.
#
# On-demand audit (D-547 relabel; the phase model is retired, ADR-0142).
# Directory layout shipped at Phase 5 entry (ADR-0029,
# supersedes ADR-0011); host_classes entries are landing through Phase
# 6+. Sync check remains informational pending a real-cycle promotion;
# refresh when the first cycle actually treats this gate as block-grade
# (= when host_classes mis-sync would damage code-correctness).

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
YAML="$REPO_ROOT/data/compat_tiers.yaml"

if [[ ! -f "$YAML" ]]; then
    echo "[check_compat_tiers_sync] compat_tiers.yaml not found; skipping"
    exit 0
fi

# Informational mode (always exit 0). Promote to hard gate when a real
# host_classes mis-sync surfaces a bug we want the gate to catch
# (D-048 host class wire-up is the natural trigger).
echo "[check_compat_tiers_sync] informational mode; sync gate activates when host_classes drift would harm correctness."
exit 0
