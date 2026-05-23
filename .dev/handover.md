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
  (tasks 4.1 / 4.2 / 4.3); critical-path: 4.0 / 4.0a / 4.4 done.
  Task 4.5 partial: 6 of 7 special forms wired (`constant` /
  `quote` / `do` / `local_ref` / `if` / `let*` / `var_ref` /
  `call` / `def` — `fn_node` remains).
- **Branch**: `cw-from-scratch` (long-lived; v0.5.0-derived;
  push free after gate green; never push to `main`).
- **Last commit**: `4cb566e` (compile signature gains *Runtime;
  def_node lands).
- **Gate**: Mac (9/9) + OrbStack Ubuntu x86_64 (8/8) green at
  `4cb566e`. 🔒 fresh OrbStack run due at Phase 4 close.
- **Last paired chapter commit**: `cc46a48` (chapter 0020 —
  Phase 3 closure, covers §9.5 / 3.8–3.14).
- **Unpaired source SHAs**: `git log cc46a48..HEAD --oneline -- src/`
  (compute on resume; chapter pairing decision is per the
  `code_learning_doc` skill's two-cadence rule).

## Stopped — ADR-level decision required for §9.6 / 4.5 fn_node

Autonomous loop stops per CLAUDE.md § Autonomous Workflow
condition 2 (ADR-level decision required that cannot be
self-decided).

**Gating decision**: `fn_node` in the VM compiler needs a
Function-equivalent that carries a compiled bytecode body. Three
candidate designs touch load-bearing ADRs:

1. **Extend `tree_walk.Function`** with an optional
   `bytecode: ?*const BytecodeChunk = null`. Single heap type for
   both backends; `null` ⇒ TreeWalk Node body, non-null ⇒ VM
   bytecode body. Smallest diff; bytecode field unused on
   TreeWalk allocations. Touches `tree_walk.zig` field layout —
   no ADR amend needed, but the dual-body shape is a load-bearing
   choice that wants ADR-0005 visibility.
2. **Move `Function` to a shared zone-1 module**
   (`src/eval/backend/function.zig`), then extend. Same field
   layout as #1 but the type stops belonging to one backend.
   Cleaner zone semantics; bigger refactor (every `tree_walk`
   reference moves).
3. **Add a new `HeapTag.vm_fn_val`** distinct from `fn_val`. VM
   dispatch sees a different tag; complete separation. Touches
   ADR-0012 (ValueTag NaN-box organisation) — `HeapTag` group
   assignment is non-trivial.

The bytecode chunk's **lifetime** also needs pinning: the chunk
slices live in the analyzer arena (per-eval reset); the
`Function` lives on `rt.gpa` (process lifetime until Phase 5 GC).
Decide whether the chunk is heap-allocated alongside the Function
(safer, double allocation) or borrowed from the arena (existing
`body`/`params` pattern, requires the arena to outlive the
Function).

Recommended next action on resume: read ADR-0005 +
`tree_walk.Function` layout + `compiler.zig::compile` signature,
then either issue an ADR amendment naming the chosen design or
proceed with design #1 (smallest deviation) and note the choice
in the commit message.

**Autonomous prep walked this resume** (do not re-walk):

- §9.6 / 4.5 cycles 1-4 landed (`a2e1412` / `d900ec3` / `24d357c`
  / `4cb566e`).
- Cycle 5 prep: an exploratory `Function.bytecode` field
  extension was sketched on `tree_walk.zig` then reverted when
  the lifetime + zone discussion surfaced as ADR-territory.
- Step 0 survey for 4.5 is at
  `private/notes/phase4-4.5-survey.md`; design space sections 5
  and 7 anchor the three options above.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
