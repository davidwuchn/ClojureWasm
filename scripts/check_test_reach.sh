#!/usr/bin/env bash
#
# check_test_reach.sh — flag .zig files that ship `test {...}`
# blocks but are not reachable from `src/main.zig` via the
# `@import` graph.
#
# Background: Zig 0.16 analyses top-level decls lazily. A file
# imported only via `pub const X = @import("...")` (with X
# unreferenced) is NOT pulled into the test set, and its
# `test {}` blocks silently never run. Worse, latent compile
# errors inside the file go undetected.
#
# See .claude/rules/zig_tips.md "Test discovery via @import".
#
# Usage:
#   bash scripts/check_test_reach.sh            # informational
#   bash scripts/check_test_reach.sh --gate     # exit 1 if any
#                                               # file is unreachable
#
# Exit codes:
#   0   no unreachable test files
#   1   --gate mode: at least one unreachable test file (gate fail)
#   2   internal script error
set -euo pipefail

cd "$(dirname "$0")/.."

mode="${1:-informational}"

root_file="src/main.zig"
if [[ ! -f "$root_file" ]]; then
    echo "check_test_reach: $root_file not found" >&2
    exit 2
fi

# Collect all .zig files under src/ that contain at least one
# `^test ` block (line starts with "test " — covers both
# `test "name"` and `test {` anonymous forms).
mapfile -t test_files < <(grep -rl '^test ' src/ --include='*.zig' | sort -u)

# BFS over @import strings starting from src/main.zig. The
# `reachable` map records absolute paths so duplicate-path edges
# don't loop.
declare -A reachable
queue=("$root_file")
while [[ ${#queue[@]} -gt 0 ]]; do
    cur="${queue[0]}"
    queue=("${queue[@]:1}")
    abs="$(realpath "$cur" 2>/dev/null || true)"
    [[ -z "$abs" || -n "${reachable[$abs]:-}" ]] && continue
    reachable[$abs]=1
    dir="$(dirname "$cur")"
    while read -r rel; do
        [[ -z "$rel" ]] && continue
        target="$dir/$rel"
        if [[ -f "$target" ]]; then
            queue+=("$target")
        fi
    done < <(grep -oE '@import\("[^"]+\.zig"\)' "$cur" 2>/dev/null \
             | sed -E 's/.*"([^"]+)".*/\1/' || true)
done

unreachable=()
for f in "${test_files[@]}"; do
    abs="$(realpath "$f" 2>/dev/null || true)"
    if [[ -z "${reachable[$abs]:-}" ]]; then
        unreachable+=("$f")
    fi
done

if [[ ${#unreachable[@]} -eq 0 ]]; then
    echo "check_test_reach: all $(printf '%d' "${#test_files[@]}") test-bearing .zig files reachable from $root_file"
    exit 0
fi

cat <<EOF
check_test_reach: ${#unreachable[@]} test-bearing .zig file(s) NOT reachable from $root_file.

These files contain \`test {...}\` blocks that Zig 0.16's lazy
decl analysis silently skips. Add a line to the test{} aggregator
in src/main.zig:

EOF
for f in "${unreachable[@]}"; do
    n=$(grep -c '^test ' "$f")
    rel="${f#./}"
    rel_from_main="${rel#src/}"
    echo "    _ = @import(\"${rel_from_main}\");   // $n test blocks"
done
echo
echo "Background: .claude/rules/zig_tips.md \"Test discovery via @import\""

if [[ "$mode" == "--gate" ]]; then
    exit 1
fi
exit 0
