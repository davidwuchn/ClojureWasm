#!/usr/bin/env bash
# G3 gate (ADR-0029 D4): feature keyword must appear in every file
# path listed under each compat_tiers.yaml host_classes entry.
#
# For each host_classes entry that has both a `keyword:` field
# and a `files:` map (= migrated to the extended ADR-0029 D5
# schema), verify:
#
#   1. Every file path under `files:` (except `wrap:`) contains the
#      keyword as a path component or filename stem.
#   2. Every listed file exists on disk.
#
# Entries that lack `keyword:` (= legacy schema, awaiting Phase 6+
# migration) are silently skipped — incremental migration is
# expected per ROADMAP §6.0 + ADR-0029 D5.
#
# The `wrap:` slot is exempt from keyword matching because value-
# wrap helpers (e.g., runtime/collection/string.zig) are
# legitimately reused across features.
#
# See .claude/rules/feature_name_consistency.md R1 for the contract.
#
# Modes:
#   bash scripts/check_feature_keyword.sh           informational
#   bash scripts/check_feature_keyword.sh --strict  exit 1 on violation
#   bash scripts/check_feature_keyword.sh --gate    exit 1 on violation

set -euo pipefail

MODE="${1:-info}"

cd "$(dirname "$0")/.."

YAML=compat_tiers.yaml

if [ ! -f "$YAML" ]; then
    echo "compat_tiers.yaml not found; nothing to check." >&2
    exit 0
fi

violations_file=$(mktemp)
entries_file=$(mktemp)
trap "rm -f $violations_file $entries_file" EXIT

# Parse YAML with Python — small, deterministic, no extra deps.
# Output one line per (fqn, keyword, slot, path) tuple, separator |.
python3 - "$YAML" "$entries_file" <<'PY'
import sys, re

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    text = f.read()

lines = text.splitlines()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    m = re.match(r'^(\s*)-\s*fqn:\s*(\S+)', line)
    if not m:
        i += 1
        continue
    indent = len(m.group(1))
    fqn = m.group(2).strip().strip('"\'')
    block = [line]
    j = i + 1
    while j < len(lines):
        nxt = lines[j]
        if not nxt.strip():
            block.append(nxt); j += 1; continue
        nxt_indent = len(nxt) - len(nxt.lstrip())
        if nxt_indent <= indent and not nxt.lstrip().startswith('#'):
            break
        block.append(nxt)
        j += 1
    i = j

    body = "\n".join(block)
    km = re.search(r'^\s+keyword:\s*(\S+)', body, re.M)
    if not km:
        continue
    keyword = km.group(1).strip().strip('"\'')

    fm = re.search(r'^\s+files:\s*$\n((?:\s+\S.*\n?)+)', body, re.M)
    if not fm:
        continue
    files_block = fm.group(1)
    for fl in files_block.splitlines():
        fm2 = re.match(r'^\s+(\w+):\s*(.+?)\s*(?:#.*)?$', fl)
        if not fm2:
            continue
        slot = fm2.group(1)
        raw = fm2.group(2).strip()
        paths = []
        if raw.startswith('['):
            inner = raw.strip('[]').strip()
            if inner:
                for p in inner.split(','):
                    paths.append(p.strip().strip('"\''))
        elif raw in ('null', '~', ''):
            continue
        else:
            paths.append(raw.strip('"\''))
        for p in paths:
            out.append(f"{fqn}|{keyword}|{slot}|{p}")

with open(dst, "w") as f:
    f.write("\n".join(out))
    if out:
        f.write("\n")
PY

while IFS='|' read -r fqn keyword slot path; do
    [ -z "$fqn" ] && continue

    if [ ! -f "$path" ]; then
        echo "$fqn: G3/ADR-0029 D4: $slot file does not exist: $path" >> "$violations_file"
        continue
    fi

    if [ "$slot" = "wrap" ]; then
        continue
    fi
    if ! printf '%s' "$path" | grep -q "$keyword"; then
        echo "$fqn: G3/ADR-0029 D4: keyword '$keyword' not in $slot path: $path" >> "$violations_file"
    fi
done < "$entries_file"

count=$(wc -l < "$violations_file" | tr -d ' ')

if [ "$count" -gt 0 ]; then
    cat "$violations_file"
    echo
    echo "$count feature-keyword violation(s) found."
fi

case "$MODE" in
    --strict|--gate)
        if [ "$count" -gt 0 ]; then exit 1; fi
        ;;
    *)
        echo "(informational mode: exit 0 regardless of violations)"
        ;;
esac

exit 0
