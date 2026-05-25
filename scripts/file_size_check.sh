#!/usr/bin/env bash
# file_size_check.sh — current mode: informational (reports only).
# Reports files exceeding 1000 lines (soft) / 2000 lines (hard) per
# ADR-0016. Exempt marker: `FILE-SIZE-EXEMPT: <reason> (ADR-NNNN)`
# in file header. Promote to hard gate (= exit 1 on over-hard) at the
# next cycle that pairs over-soft growth with a split-or-refactor
# commit. D-030 (analyzer.zig) and D-029 (value.zig) are the active
# candidate splits.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SRC_DIR="$REPO_ROOT/src"

if [[ ! -d "$SRC_DIR" ]]; then
    exit 0
fi

SOFT=1000
HARD=2000

over_soft=()
over_hard=()

while IFS= read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if grep -q "FILE-SIZE-EXEMPT" "$f" 2>/dev/null; then
        continue
    fi
    if (( lines > HARD )); then
        over_hard+=("$f ($lines lines)")
    elif (( lines > SOFT )); then
        over_soft+=("$f ($lines lines)")
    fi
done < <(find "$SRC_DIR" -name "*.zig" -type f)

if (( ${#over_soft[@]} > 0 )); then
    echo "[file_size_check] SOFT cap (>${SOFT}) exceeded:"
    printf "  %s\n" "${over_soft[@]}"
fi
if (( ${#over_hard[@]} > 0 )); then
    echo "[file_size_check] HARD cap (>${HARD}) exceeded:"
    printf "  %s\n" "${over_hard[@]}"
fi

# Informational only (exit 0 regardless). Promote to hard gate when
# a real cycle pairs over-cap growth with a split-or-refactor commit.
exit 0
