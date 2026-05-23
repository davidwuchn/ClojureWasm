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
  / 4.6 / 4.7 / 4.8 / 4.9 done.
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

## Active task — §9.6 / 4.10

`src/eval/evaluator.zig` (new) — `pub fn compare(rt, env, src)
struct { tree_walk: Value, vm: Value, equal: bool }`. Wires this
into the CI-mandatory differential gate per ADR-0005, with
`test/diff/runner.zig` + `cases.yaml` per ADR-0022 landing in
this task. Phase 17 extends to a third backend (JIT).

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.10 + dependency-graph at §9.6.x.
- ADR-0005 (dual backend strategy), ADR-0022 (differential
  wiring + scan framework), ADR-0024 (scan framework + run_step
  pattern), debt row `D-018` (Zig YAML parser strategy — choose
  hand-rolled scanner or JSON-like subset).
- `src/eval/driver.zig::evalForm` already runs both backends as
  separate top-level entry paths. `evaluator.compare` calls each
  in sequence on the same input, captures the Value, and reports
  divergence.
- `test/diff/` — new directory hosting `cases.yaml` + the runner.
  Wire `bash test/run_all.sh` to invoke it (Layer 3 per
  `test_taxonomy.md`).

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
