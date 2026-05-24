#!/usr/bin/env bash
# scripts/post_commit_remind.sh
#
# PostToolUse hook for Bash. When `git commit` just ran, re-inject the
# autonomous-loop continuation reminder from CLAUDE.md § The only stop
# + § Autonomous Workflow "Loop: Step 0 → 7 → next task's Step 0".
#
# Why this exists: CLAUDE.md is loaded once per session; long sessions
# accumulate momentum drift where the loop's "only stop is user
# explicit stop" rule fades from active recall. Re-injecting the rule
# at every commit lands it at the exact moment the drift is most
# likely (just after Step 6, before the next task's Step 0).
#
# Inputs: stdin JSON from Claude Code (PostToolUse hook payload).
# stdout: reminder text fed back to Claude as tool result feedback.

set -u

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    pass
' 2>/dev/null || true)

case "$CMD" in
    *"git commit"*)
        ;;
    *)
        exit 0
        ;;
esac

REMINDER=$(cat <<'EOF'
[post-commit reminder]

A commit landed. Recall the project's fully-autonomous principle:
return to the head of the autonomous loop in CLAUDE.md
§ Autonomous Workflow and continue the next unit of work
immediately. Intermediate artefacts — per-task notes, status
summaries, planning text — are fine to produce on the way, but
must never become a reason to stop. Smell triggers are in-flight
interrupts; build / test failures are Active-task items; neither
halts the loop. Only the user's explicit stop directive halts
the loop (CLAUDE.md § The only stop).
EOF
)

# PostToolUse: stdout must be JSON with hookSpecificOutput.additionalContext
# for the text to be injected into Claude's next-turn context. Bare-text
# stdout is shown only in transcript mode (Ctrl-R), not to Claude.
export REMINDER
python3 -c '
import json, os
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": os.environ.get("REMINDER", ""),
    }
}))
'
