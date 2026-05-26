#!/usr/bin/env bash
# bench/record.sh — Append a curated bench lock-point to
# `bench/history.yaml`. Reads the most recent `bench/quick_baseline.txt`
# block (= the rows sharing the latest timestamp) for the per-bench
# median and emits an entry matching ADR-0027's schema.
#
# Usage:
#   bash bench/record.sh --id=8A.1 --reason="Phase 8 row 8.3 close"
#   bash bench/record.sh --id=8A.1 --reason="..." --backend=vm
#   bash bench/record.sh --id=8A.1 --reason="..." --no-lock
#
# Prerequisites: `bench/quick.sh` was run since the last interesting
# code change (samples in `quick_baseline.txt` reflect HEAD's
# behaviour). `yq` available on PATH. Machine `id` detected from
# `uname` — currently recognises `mac-arm-m4pro` (aarch64-darwin)
# + `orbstack-ubuntu-x86_64` (x86_64-linux); unknown hosts pass
# through the raw `uname -sm` shape so reviewers can extend the
# recognition table here as needed.

set -euo pipefail
cd "$(dirname "$0")/.."

HISTORY="bench/history.yaml"
BASELINE="bench/quick_baseline.txt"

ID=""
REASON=""
BACKEND="tree_walk"
LOCK="true"

for arg in "$@"; do
    case "$arg" in
        --id=*)      ID="${arg#--id=}" ;;
        --reason=*)  REASON="${arg#--reason=}" ;;
        --backend=*) BACKEND="${arg#--backend=}" ;;
        --no-lock)   LOCK="false" ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

[[ -n "$ID" ]] || { echo "ERROR: --id=<label> required" >&2; exit 1; }
[[ -n "$REASON" ]] || { echo "ERROR: --reason=<text> required" >&2; exit 1; }
[[ -f "$HISTORY" ]] || { echo "ERROR: $HISTORY missing — run row 8.2 first" >&2; exit 1; }
[[ -f "$BASELINE" ]] || { echo "ERROR: $BASELINE missing — run bench/quick.sh first" >&2; exit 1; }
command -v yq >/dev/null || { echo "ERROR: yq not on PATH" >&2; exit 1; }

# --- Machine detection (canonical short id) ---
uname_sm="$(uname -sm)"
case "$uname_sm" in
    "Darwin arm64")   MACHINE_ID="mac-arm-m4pro"; CPU="Apple M4 Pro"; CPU_ARCH="aarch64"; OS="Darwin $(uname -r)"; CORES="$(sysctl -n hw.ncpu)" ;;
    "Linux x86_64")   MACHINE_ID="orbstack-ubuntu-x86_64"; CPU="x86_64"; CPU_ARCH="x86_64"; OS="Linux $(uname -r)"; CORES="$(nproc)" ;;
    *)
        echo "WARN: unrecognised host '$uname_sm' — using raw value" >&2
        MACHINE_ID="${uname_sm// /-}"; CPU="$uname_sm"; CPU_ARCH="$(uname -m)"; OS="$(uname -s) $(uname -r)"; CORES="?" ;;
esac

# --- Latest block extraction ---
# A "block" = rows with the most recent timestamp. quick.sh writes
# one block per invocation in chronological order at end-of-file.
LATEST_TS="$(awk -F'\t' 'END { print $1 }' "$BASELINE")"
[[ -n "$LATEST_TS" ]] || { echo "ERROR: $BASELINE is empty" >&2; exit 1; }
BLOCK="$(awk -F'\t' -v ts="$LATEST_TS" '$1 == ts { print }' "$BASELINE")"

# --- Build the new entry (YAML) in a tmpfile, then yq-merge ---
DATE_TODAY="$(date -u +%Y-%m-%d)"
COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
    printf '  - id: %s\n' "\"$ID\""
    printf '    date: %s\n' "\"$DATE_TODAY\""
    printf '    reason: %s\n' "\"$REASON\""
    printf '    commit: %s\n' "\"$COMMIT_SHORT\""
    printf '    build: ReleaseFast\n'
    printf '    backend: %s\n' "$BACKEND"
    printf '    machine:\n'
    printf '      id: %s\n' "$MACHINE_ID"
    printf '      cpu: %s\n' "\"$CPU\""
    printf '      cpu_arch: %s\n' "$CPU_ARCH"
    printf '      os: %s\n' "\"$OS\""
    printf '      cores: %s\n' "$CORES"
    printf '    lock: %s\n' "$LOCK"
    printf '    results:\n'
    while IFS=$'\t' read -r ts phase bench value _machine; do
        # 5-column TSV (ts, phase, bench, value, machine_id) since
        # row 8.3. The explicit `_machine` capture stops `read` from
        # folding the 5th column into `value`.
        printf '      %s:\n' "$bench"
        printf '        samples_us: [%s]\n' "$value"
        printf '        median_us: %s\n' "$value"
        printf '        p99_us: %s\n' "$value"
        printf '        n: 1\n'
    done <<< "$BLOCK"
} > "$TMP"

# Append the new entry to history.yaml's `entries:` list.
ENTRY_YAML="$(cat "$TMP")"
yq -i ".entries += [$(cat "$TMP" | yq -o=json '.[0]' --indent=0 2>/dev/null || echo '{}')]" "$HISTORY" 2>/dev/null || {
    # Fallback: append textually. The list-merge yq trick above can
    # fail when single-entry YAML doesn't round-trip cleanly; append
    # under `entries:` directly is robust + readable.
    printf '\n%s\n' "$ENTRY_YAML" >> "$HISTORY"
}

echo "Recorded lock '$ID' ($MACHINE_ID, $BACKEND, $COMMIT_SHORT) into $HISTORY"
