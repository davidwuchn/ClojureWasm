#!/usr/bin/env bash
# binary_size_report.sh — binary-size measurement + size-claims gate (ADR-0172).
#
# Report mode (default):
#   bash scripts/binary_size_report.sh [BIN]
#     Prints total bytes + the segment/section breakdown for BIN
#     (default zig-out/bin/cljw). With a symbol-bearing binary
#     (-Dprofile=true build), also prints the top code symbols so a
#     size jump localizes to a component (the ADR-0172 method).
#
# Gate mode:
#   bash scripts/binary_size_report.sh --check [BIN]
#     Compares README.md's headline size claim (the FIRST "<N> MB" match
#     in the file — keep the claim the first MB figure in README) against
#     BIN's measured size. Fails (exit 1) when the drift exceeds 10%.
#     This is the structural fix for the 2026-07 rot incident where
#     README said "about 3.8 MB" while the shipped binary was 9.5 MB.
#     Wired into test/run_all.sh as the `size_claims` step (full gate;
#     runs right after build_cljw so the binary is fresh).
#
# Reference platform for ADR-0172 numbers: macOS arm64, ReleaseSafe,
# -Dwasm, stripped (= the brew artifact config). MB here is decimal
# (10^6 bytes), matching what brew/GitHub display to users.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE=report
if [[ "${1:-}" == "--check" ]]; then
    MODE=check
    shift
fi
BIN="${1:-zig-out/bin/cljw}"

# ADR-0172 §2 derived ceiling (per-component budgets sum). Keep in sync with
# the ADR's budget table — a change here REQUIRES an ADR-0172 Revision
# history entry (the budget moves consciously, never to silence this check).
BUDGET_CEILING_BYTES=8800000

if [[ ! -f "$BIN" ]]; then
    echo "binary_size_report: binary not found: $BIN (build first: zig build -Dwasm -Doptimize=ReleaseSafe)" >&2
    exit 1
fi

if stat -f%z "$BIN" >/dev/null 2>&1; then
    ACTUAL=$(stat -f%z "$BIN")   # macOS
else
    ACTUAL=$(stat -c%s "$BIN")   # Linux
fi
ACTUAL_MB=$(awk "BEGIN{printf \"%.2f\", $ACTUAL/1000000}")

if [[ "$MODE" == "check" ]]; then
    CLAIM=$(grep -m1 -oE '[0-9]+(\.[0-9]+)? MB' README.md | head -1 | grep -oE '[0-9]+(\.[0-9]+)?' || true)
    if [[ -z "$CLAIM" ]]; then
        echo "size_claims: no '<N> MB' size claim found in README.md — add one (ADR-0172)" >&2
        exit 1
    fi
    if [[ "$ACTUAL" -gt "$BUDGET_CEILING_BYTES" ]]; then
        echo "size_claims: built binary ${ACTUAL_MB} MB (${ACTUAL} B) exceeds the ADR-0172 derived ceiling ($BUDGET_CEILING_BYTES B)." >&2
        echo "  Attribute with 'bash scripts/binary_size_report.sh' (-Dprofile build for symbols), then land a lever" >&2
        echo "  or consciously amend the budget table in .dev/decisions/0172_binary_size_budget_and_ledger.md." >&2
        exit 1
    fi
    DRIFT=$(awk "BEGIN{c=$CLAIM*1000000; d=($ACTUAL-c)/c; if(d<0)d=-d; printf \"%.3f\", d}")
    OK=$(awk "BEGIN{print ($DRIFT <= 0.10) ? 1 : 0}")
    if [[ "$OK" == "1" ]]; then
        echo "    size_claims: README claims ${CLAIM} MB, measured ${ACTUAL_MB} MB (${ACTUAL} B) — within 10%"
        exit 0
    fi
    echo "size_claims: README claims ${CLAIM} MB but the built binary is ${ACTUAL_MB} MB (${ACTUAL} B) — drift >10%." >&2
    echo "  Update README's size figure (and CHANGELOG on release) per ADR-0172; do not let the claim rot." >&2
    exit 1
fi

echo "== $BIN: ${ACTUAL} bytes (${ACTUAL_MB} MB decimal)"
if command -v size >/dev/null 2>&1; then
    if size -m "$BIN" >/dev/null 2>&1; then
        size -m "$BIN" | grep -E "Segment|Section|total" | grep -v PAGEZERO
    else
        size -A "$BIN" | head -25
    fi
fi

# Symbol attribution (only meaningful on a -Dprofile=true build; a stripped
# release binary has no symbols and this section prints nothing).
if nm -n "$BIN" 2>/dev/null | grep -qi " t "; then
    echo "== top 20 code symbols (build with -Dprofile=true for full attribution)"
    nm -n "$BIN" 2>/dev/null | grep -i " t " | python3 -c '
import sys
syms = []
for line in sys.stdin:
    p = line.split()
    if len(p) >= 3:
        syms.append((int(p[0], 16), p[2]))
syms.sort()
sized = []
for i, (addr, name) in enumerate(syms[:-1]):
    sz = syms[i+1][0] - addr
    if 0 < sz < 10_000_000:
        sized.append((sz, name))
for sz, name in sorted(sized, reverse=True)[:20]:
    print(f"{sz/1024:9.1f} KB  {name[:100]}")
'
fi
