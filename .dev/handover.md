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
  / 4.6 / 4.7 done.
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

## Active task — §9.6 / 4.8

`build.zig` — add `-Dbackend=tree-walk|vm` comptime gate.
`tree_walk.installVTable` vs `vm.installVTable` (new) flips at
startup. Default stays `tree-walk` until 4.12 confirms parity.
The VM dispatch loop, compiler, and Phase-3 special-form lowering
all landed at 4.6 / 4.7; 4.8 is the wiring step that makes
`cljw -Dbackend=vm -e ...` reachable from the CLI.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.8 + dependency-graph section at §9.6.x.
- ADR-0023 (comptime conditional imports — the `phase_at_least_N`
  bools landed at 4.0a are the precedent for the
  `-Dbackend=...` switch).
- `src/main.zig` L21 / 118 imports `tree_walk` and calls
  `tree_walk.installVTable(&rt)` unconditionally at startup; 4.8
  routes through a comptime branch.
- VM entry point: `src/eval/backend/vm.zig::eval` — wired by a
  yet-to-write `vm.installVTable(&rt)` that registers a `callFn`
  bridging `Function.bytecode != null` to `vm.eval` and falls
  back to TreeWalk for builtins. Task 4.9 then runs the unit
  test suite under both backends.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
