#!/usr/bin/env bash
# scripts/check_e2e_reach.sh — e2e ORPHAN guard (coverage-lie prevention).
#
# An e2e script under test/e2e/ that is NOT referenced in test/run_all.sh
# never runs in the gate — so it gives FALSE confidence (the file exists, looks
# like coverage, but gates nothing). This is the e2e sibling of
# check_test_reach.sh (which guards Zig `test {}` orphans). It surfaced
# 2026-06-02 when 5 newly-authored phase14 e2e + the pending phase14_eval were
# all unreferenced (D-196 / D-197 investigation).
#
# Fails if any test/e2e/*.sh is not referenced by name in run_all.sh, except
# the explicit ALLOWLIST (e2e for not-yet-implemented features, intentionally
# parked until the feature lands — each MUST cite a debt row here).
#
# Usage: bash scripts/check_e2e_reach.sh [--gate]   # --gate => exit 1 on orphan

set -uo pipefail
cd "$(dirname "$0")/.."

# Intentionally-not-gated e2e (feature pending). Format: "<basename> # D-NNN why".
ALLOWLIST=(
    "phase14_eval.sh"   # D-197 — clojure.core/eval unimplemented on BOTH backends
)

allowed() {
    local b="$1"
    for a in "${ALLOWLIST[@]}"; do
        [ "${a%% *}" = "$b" ] && return 0
    done
    return 1
}

runner="test/run_all.sh"
orphans=0
for f in test/e2e/*.sh; do
    b="$(basename "$f")"
    if grep -q -- "$b" "$runner"; then continue; fi
    if allowed "$b"; then
        echo "  allowed (pending): $b"
        continue
    fi
    echo "  ORPHAN (not in $runner): $b"
    orphans=$((orphans + 1))
done

if [ "$orphans" -gt 0 ]; then
    echo "check_e2e_reach: $orphans orphaned e2e — add to $runner or ALLOWLIST with a debt ref"
    [ "${1:-}" = "--gate" ] && exit 1
    exit 0
fi
echo "check_e2e_reach: all e2e referenced in $runner (or allowlisted)"
exit 0
