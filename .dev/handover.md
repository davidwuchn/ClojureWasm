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
  done.
- **Branch**: `cw-from-scratch` (long-lived; v0.5.0-derived;
  push free after gate green; never push to `main`).
- **Last commit**: see `git log -1` (4.5 fn_node landing).
- **Gate**: Mac (9/9) + OrbStack Ubuntu x86_64 (8/8) green at
  4.5 landing. 🔒 fresh OrbStack run due at Phase 4 close.
- **Last paired chapter commit**: `cc46a48` (chapter 0020 —
  Phase 3 closure, covers §9.5 / 3.8–3.14).
- **Unpaired source SHAs**: `git log cc46a48..HEAD --oneline -- src/`
  (compute on resume; chapter pairing decision is per the
  `code_learning_doc` skill's two-cadence rule).

## Active task — §9.6 / 4.6

`src/eval/backend/vm.zig` (new file) —
`pub fn eval(rt, env, locals, chunk) Value` dispatch loop. Single
`switch (Opcode)` over the 15 ops landed in 4.4. Computed-goto is
deferred; only `@branchHint(.likely)` on the hot arm. Per-frame
`[256]Value` slot stack mirrors TreeWalk so the same MAX_LOCALS
invariant holds. Critical path: 4.6 → 4.7 (Phase-3 special
forms) → … → 4.12 (exit smoke).

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.6 + dependency-graph section at §9.6.x.
- ADR-0005 (dual backend strategy), ADR-0022 (differential
  wiring), ADR-0024 (scan framework + run_step).
- `src/eval/backend/vm/opcode.zig` — Opcode operand semantics
  table sits in the module docstring; the dispatch loop's
  per-arm behaviour mirrors what TreeWalk does at the same
  point. For `op_make_fn`, note that 4.5's emitter pre-allocates
  the Function at compile time (closure-less); the dispatcher
  just reads the constant and pushes it. Closure capture
  (`slot_base > 0`) is task 4.7 and currently returns
  `error.NotImplemented` from `compiler.zig`.
- TreeWalk reference shape: `src/eval/backend/tree_walk.zig`.
  Function struct now carries a `bytecode: ?*const
  BytecodeChunk = null` (4.5 cycle 5); `null` ⇒ TreeWalk Node
  body, non-null ⇒ VM bytecode body. The dispatcher routes on
  this discriminator.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
