#!/usr/bin/env bash
# scripts/check_bench_regression.sh — Row 8.3 1.2x bench regression
# gate. Compares the most recent `bench/quick_baseline.txt` block's
# per-bench median against the matching `bench/history.yaml` `lock:
# true` entry (keyed by machine.id + backend). Exits non-zero on
# >1.2× regression in any bench.
#
# Per ADR-0027 + row 8.3:
#   - Looks up lock by (machine.id, backend) tuple. Falls back to
#     informational pass when no matching lock exists (= the gate
#     is opt-in until `bench/record.sh` has populated locks for the
#     current host/backend).
#   - Compares median per bench. p99 ignored at this gate level
#     (D-005 Phase-17 σ-gate consumes p99 + samples).
#   - Threshold: 1.2× (current_median / locked_median > 1.2).
#
# Modes:
#   --check     informational: report findings, exit 0 always.
#   --gate      enforcing: exit 1 on regression (= CI-blocking).
#   default     same as --check (matches the existing
#               check_*.sh script convention of informational by
#               default; opt-in to enforcement via run_all.sh).

set -euo pipefail
cd "$(dirname "$0")/.."

HISTORY="bench/history.yaml"
BASELINE="bench/quick_baseline.txt"
MODE="check"
BACKEND="${BENCH_BACKEND:-tree_walk}"

for arg in "$@"; do
    case "$arg" in
        --check) MODE="check" ;;
        --gate)  MODE="gate" ;;
        --backend=*) BACKEND="${arg#--backend=}" ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

[[ -f "$HISTORY" ]] || { echo "bench_regression: $HISTORY missing — skipping (informational pass)"; exit 0; }
[[ -f "$BASELINE" ]] || { echo "bench_regression: $BASELINE missing — skipping (informational pass)"; exit 0; }
command -v yq >/dev/null || { echo "bench_regression: yq not on PATH — skipping (informational pass)"; exit 0; }

# --- Machine detection (must match record.sh canonical ids) ---
uname_sm="$(uname -sm)"
case "$uname_sm" in
    "Darwin arm64") MACHINE_ID="mac-arm-m4pro" ;;
    "Linux x86_64") MACHINE_ID="orbstack-ubuntu-x86_64" ;;
    *)              MACHINE_ID="${uname_sm// /-}" ;;
esac

# --- Lock lookup ---
LOCK_QUERY='.entries[] | select(.lock == true and .machine.id == "'"$MACHINE_ID"'" and .backend == "'"$BACKEND"'") | .id'
LOCK_ID="$(yq "$LOCK_QUERY" "$HISTORY" 2>/dev/null | head -1)"
if [[ -z "$LOCK_ID" || "$LOCK_ID" == "null" ]]; then
    echo "bench_regression: no lock entry for (machine=$MACHINE_ID, backend=$BACKEND) — opt-in pending; record.sh seed needed"
    exit 0
fi

# --- Latest block extraction (per-machine) ---
# quick.sh writes a 5-column TSV (ts, phase, bench, value, machine_id);
# pre-row-8.3 rows lack the 5th column and are treated as machine
# "unknown" (filtered out unless MACHINE_ID happens to be "unknown").
# The "latest block" for the current host = rows sharing the most
# recent timestamp that ALSO carry the current host's machine_id.
LATEST_TS="$(awk -F'\t' -v m="$MACHINE_ID" '$5 == m { ts = $1 } END { print ts }' "$BASELINE")"
if [[ -z "$LATEST_TS" ]]; then
    echo "bench_regression: no rows for machine=$MACHINE_ID in $BASELINE — opt-in pending; run bench/quick.sh on this host"
    exit 0
fi

declare -A CURRENT
while IFS=$'\t' read -r ts phase bench value machine; do
    [[ "$ts" == "$LATEST_TS" && "$machine" == "$MACHINE_ID" ]] || continue
    CURRENT["$bench"]="$value"
done < "$BASELINE"

# --- Per-bench comparison ---
FAILED=0
echo "bench_regression: machine=$MACHINE_ID backend=$BACKEND lock=$LOCK_ID threshold=1.2x"
for bench in "${!CURRENT[@]}"; do
    current="${CURRENT[$bench]}"
    locked="$(yq '.entries[] | select(.id == "'"$LOCK_ID"'") | .results.'"$bench"'.median_us' "$HISTORY" 2>/dev/null)"
    if [[ -z "$locked" || "$locked" == "null" ]]; then
        printf '  %-30s current=%s  locked=- (no baseline for this bench)\n' "$bench" "$current"
        continue
    fi
    # 1.2x check via integer arithmetic: ratio_x10 = (current * 10) / locked
    # Fail when current > 1.2 * locked, i.e. ratio_x10 > 12.
    ratio_x10=$(( (current * 10) / locked ))
    status="ok"
    if (( ratio_x10 > 12 )); then
        status="REGRESSION"
        FAILED=$(( FAILED + 1 ))
    fi
    printf '  %-30s current=%s  locked=%s  ratio=%d.%dx  %s\n' \
        "$bench" "$current" "$locked" $(( ratio_x10 / 10 )) $(( ratio_x10 % 10 )) "$status"
done

if (( FAILED > 0 )); then
    echo "bench_regression: $FAILED bench(es) exceeded 1.2× threshold"
    if [[ "$MODE" == "gate" ]]; then
        exit 1
    fi
fi
exit 0
