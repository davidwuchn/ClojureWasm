#!/usr/bin/env bash
# scripts/check_md_tables.sh
#
# Pre-commit gate: every staged *.md file must already be aligned by
# `md-table-align`. Behaviour was originally check-only and required
# a separate fix-and-re-stage round-trip whenever the agent (or a
# human) staged before aligning. That two-cycle pattern was wasteful,
# so the hook now **auto-fixes and re-stages** misaligned files
# before letting the commit through. The commit then contains the
# realigned content automatically; no second round-trip needed.
#
# Hook contract: invoked as a Claude Code PreToolUse hook on Bash
# (.claude/settings.json). Reads the JSON payload from stdin, no-ops
# unless the command being run is `git commit`.
#
# Failure modes:
#   - md-table-align not installed → block with install guide (exit 1).
#   - md-table-align cannot fix a file (genuine syntax issue) → block
#     with the filename (exit 2). No-op for that file; commit blocked.
#
# md-table-align is shipped via bbin from
# https://github.com/chaploud/babashka-utilities.

set -euo pipefail

# --- 1. Read the Claude Code hook payload ------------------------------------
INPUT="$(cat)"

COMMAND="$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
print((data.get("tool_input") or {}).get("command", "") or "")
' 2>/dev/null || echo "")"

# --- 2. Only enforce on `git commit` -----------------------------------------
if ! printf '%s' "$COMMAND" | grep -qE '(^|[ ;&|])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- 3. Collect staged *.md files (added or modified, not deleted) -----------
STAGED_MD="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null \
             | grep -E '\.md$' || true)"

[[ -z "$STAGED_MD" ]] && exit 0

# --- 4. Tool availability ----------------------------------------------------
if ! command -v md-table-align >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[md-table-gate] md-table-align is not on PATH.

This repo enforces Markdown table alignment at commit time. Install
the CLI via bbin:

  # one-time: install bbin (Linux / macOS via Homebrew)
  brew install babashka/brew/bbin
  echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc

  # install the tool
  bbin install io.github.chaploud/babashka-utilities

After installation `md-table-align --help` should print a usage screen.
Then re-run your `git commit`.

If you cannot install bbin right now, you can also bypass via:
  git -c core.hooksPath=/dev/null commit ...
…but please don't make a habit of it; chapters that drift here are
painful to clean up later.
EOF
  exit 2
fi

# --- 5. Per-file auto-fix + re-stage -----------------------------------------
#
# For each staged *.md file that md-table-align --check reports as
# misaligned, run md-table-align in-place and re-add it. The commit
# will then pick up the realigned content. If md-table-align itself
# errors out for a file (genuine syntax issue, not just alignment),
# we block the commit and surface the filename.

FIXED=()
FAILED=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ -f "$f" ]] || continue

  if md-table-align --check "$f" >/dev/null 2>&1; then
    continue
  fi

  if md-table-align "$f" >/dev/null 2>&1; then
    git add -- "$f"
    FIXED+=("$f")
  else
    FAILED+=("$f")
  fi
done <<< "$STAGED_MD"

if (( ${#FIXED[@]} > 0 )); then
  echo "[md-table-gate] auto-aligned and re-staged ${#FIXED[@]} file(s):" >&2
  for f in "${FIXED[@]}"; do
    echo "  - $f" >&2
  done
fi

if (( ${#FAILED[@]} > 0 )); then
  {
    echo "[md-table-gate] md-table-align could not process the following file(s):"
    for f in "${FAILED[@]}"; do
      echo "  - $f"
    done
    echo
    echo "Run md-table-align manually on each to see the parser error,"
    echo "fix the table syntax, then retry the commit."
  } >&2
  exit 2
fi

exit 0
