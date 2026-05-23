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
  (tasks 4.1 / 4.2 / 4.3); **critical-path closed**: 4.0 / 4.0a /
  4.4 / 4.5 / 4.6 / 4.7 / 4.8 / 4.9 / 4.10 / 4.11 / 4.12 done.
  Cleanup wave in progress: 4.13–4.22 done. Remaining §9.6 rows
  (4.23–4.26.f) — big_int / lazy_seq / method_table skeletons,
  error-system migration.
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

## Active task — §9.6 / 4.23

`src/runtime/numeric/big_int.zig` — `BigInt` struct wrapping
`std.math.big.int.Managed`; ValueTag `big_int` slot reservation
(per ADR-0012). No arithmetic promotion functions in Phase 4;
Phase 5 wires the long → BigInt path.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.23, ADR-0012 (NaN-box ValueTag day 1).
- `src/runtime/value.zig` Value.Tag already lists `big_int` (slot
  reserved at Day 1 per ADR-0004). 4.23 adds the heap struct it
  points at.
- `src/runtime/numeric/` does not exist yet; create the directory
  and the file.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
