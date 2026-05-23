# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 3 files to read (cold-start order)

1. `.dev/handover.md` (this file)
2. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9, take the
   first `[ ]` row in §9.<N>.
3. The most recent `docs/ja/learn_clojurewasm/NNNN_*.md` chapter —
   to recover the conceptual baseline for the active phase.

## Current state

- **Phase**: Phase 4 IN-PROGRESS. §9.6 cluster A done
  (tasks 4.1 / 4.2 / 4.3); critical-path: 4.0 / 4.0a / 4.4 / 4.5
  / 4.6 / 4.7 / 4.8 / 4.9 / 4.10 done.
- **Branch**: `cw-from-scratch` (long-lived; v0.5.0-derived;
  push free after gate green; never push to `main`).
- **Last commit**: see `git log -1` (compute on resume — the
  resume procedure reads it directly).
- **Gate**: Mac (9/9) + OrbStack Ubuntu x86_64 (8/8) green at
  HEAD. 🔒 fresh OrbStack run due at Phase 4 close.
- **Last paired chapter commit**: `cc46a48` (chapter 0020 —
  Phase 3 closure, covers §9.5 / 3.8–3.14).
- **Unpaired source SHAs**: `git log cc46a48..HEAD --oneline -- src/`
  (compute on resume; chapter pairing decision is per the
  `code_learning_doc` skill's two-cadence rule).

## Active task — §9.6 / 4.11

`test/e2e/phase4_cli.sh` — re-run the §9.5 `phase3_cli.sh` cases
under both backends via `cljw -Dbackend=vm -e ...` (or env-var
fallback if `-D` doesn't reach the binary). Wire into
`test/run_all.sh`.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.11 + dependency-graph at §9.6.x.
- ADR-0005 / 0022. The unit-level diff suite is now landed
  (`src/eval/evaluator.zig::compare` + `src/lang/diff_test.zig`,
  6 cases). 4.11 takes the same intent to the e2e layer.
- `test/e2e/phase3_cli.sh` — the source template to mirror; copy
  the cases or factor them into a shared helper that
  `phase4_cli.sh` iterates over both backends.
- `cljw` already honours `-Dbackend=vm` at the **build** step;
  4.11 needs the CLI itself to either accept a runtime flag or
  the test script needs to build two binaries (default and
  vm-flagged) and run each through the same case list.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
