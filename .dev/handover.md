# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 6 files to read (cold-start order)

1. `.dev/handover.md` (this file) — current state + active task.
2. `CLAUDE.md` § Project spirit + § Autonomous Workflow (Step 0 → 7)
   + § The only stop (single condition: user explicit stop) +
   § Smell triggers are interrupts, not stops.
3. `.dev/project_facts.md` — user-declared invariants F-001..F-008
   (treat as project law; never amend without user direction).
4. `.dev/principle.md` — Bad Smell catalogue (16 entries) +
   Structural imagination phase + Devil's-advocate subagent
   mandate at depth ≥ 2 (F-NNN envelope).
5. `.dev/structure_plan.md` — anticipated directory tree
   Phase 5-20 (decree entries vs imagination entries).
6. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9; take the
   first `[ ]` row. At a Phase entry, load each ADR (incl.
   Revision history) / D-NNN row / F-NNN listed in the §9.<N>
   placeholder's Entry ADRs / Entry debts / Entry facts lines.

## Current state

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 rows 5.0–5.7 `[x]`.
  5.7 closed at 633422a (2 micro-commits: extern struct rewrite +
  force, first/rest/next). 9 rows remain (5.8–5.16). Mutex shape =
  no-lock single-thread (D-046 records Phase 15 re-eval). Collection
  family + lazy seq foundation ready for 5.8's ChunkedCons.
- **Branch**: `cw-from-scratch`. HEAD = 633422a.
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.9 / 5.8 Persistent List + Cons + chunked Cons

Refactor existing `runtime/collection/list.zig` per ADR-0027 Group A:
- **Keep** `list.zig` ↔ Cons (A9) — minimal rename / split per
  F-003 (the existing module already does the persistent-list job
  since Cons is immutable + structurally shared).
- **Add** `runtime/collection/chunked_cons.zig` — ChunkedCons (A10)
  with 32-element `slots` chunk + tail link. Needed for
  `(reduce + (range 1e6))` exit-smoke chunked realisation.
- **Add** (optional, defer to 5.8.b) `runtime/collection/chunk_buffer.zig`
  — ChunkBuffer (A11) for mutable-during-construction chunks.

`seq` returns List/LazySeq/Cons uniformly via dispatch (already
mostly wired — `runtime/collection/list.zig::seq` + `lazy_seq.zig::seq`).

**Step 0 reading**: ADR-0027 §2 Group A (A9-A11 slot map); cw v0
chunked cons in collections.zig (grep `ChunkedCons` /
`PersistentChunkedSeq`); clojure JVM `ChunkedCons.java` +
`ArrayChunk.java`. Survey may be brief — 5.4 PersistentVector +
5.5 ArrayMap have established the extern-struct + trace-fn pattern.

**Open hazards**: (a) chunked realisation auto-trigger collect
becomes load-bearing here — `(reduce + (range 1e6))` allocates
~31K ChunkedCons cells minimum; defer-or-trigger decision lives
in 5.8; (b) range function (also Phase 5 territory) constructs
chunked seqs via the new types — 5.8 lands the data shape, range
implementation may need a co-commit or separate row.

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md) (rows D-005 through
D-043). Step 0.5 debt sweep walks them at resume; pay attention
to D-008 / D-014a / D-014b / D-017 / D-030 (other Phase-5-target
rows that 5.2-5.16 will land), D-040 (Phase 7 MethodEntry
naming — do not touch in Phase 5), D-043 (anonymous slot
reserves for Phase 7 entry to revisit).

## Guardrail refresh history (condensed)

User-directed guardrail evolution 2026-05-23 / -24:

- Wave 1-2 (2026-05-23): project spirit (finished-form wins),
  Bad Smell catalogue grew Smallest-diff / Reservation-as-bias /
  Progress-pressure smells, Structural imagination phase, and
  ten D-027..D-036 structural-foresight debts for Phase 5-20.
- Wave 3 (2026-05-23): root-cause hardening after the long-context
  research (`private/notes/llm_long_context_research.md`) —
  `.dev/project_facts.md` (F-NNN, project law),
  `scripts/check_smell_audit.sh` PreToolUse hook.
- Wave 4-5 (2026-05-24): F-004 NaN-box 64-slot / F-005 numeric
  tower / F-006 GC strategy / F-007 chapter cadence dormant /
  F-008 zwasm v2 spec review; `.dev/structure_plan.md` Phase 5-20
  tree.
- Wave 6 (2026-05-24): F-NNN hardening — preamble = project law,
  5-level priority chain, Devil's-advocate F-NNN envelope ban,
  `scripts/check_facts_immutable.sh` PreToolUse hook. Silent
  default-shift smell added to principle.md.
- Wave 7 (2026-05-24): stop-list narrowed to "user explicit stop"
  only; smell triggers are interrupts (in-flight surgery),
  build/test failures are Active-task items, Phase / region /
  task / commit boundaries roll into the next unit of work.
