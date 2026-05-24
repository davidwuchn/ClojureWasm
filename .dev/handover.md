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

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 row 5.0 `[x]`
  (cleanup-wave audit closed at fd66df5 via ADR-0026 Accepted).
  16 rows remain (5.1–5.16). Phase 4 DONE in this session.
  Boundary chain artefacts: D-041 / D-042 queued; ADR-0026 records
  the activation classification + critical-path ordering.
- **Branch**: `cw-from-scratch`. HEAD = fd66df5.
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green at
  HEAD.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.2 / 5.1 ADR cluster (NaN-box 第二世代 + GC)

Draft ADR-0027 (NaN-box 第二世代 = F-004 = 4 group × 16 sub-type =
64 slot, 44-bit shifted pointer) + ADR-0028 (mark-sweep GC +
3-layer allocator = F-006) as a **paired Accepted set**.
Devil's-advocate subagent mandatory (depth 3 per principle.md).

**Step 0 reading**: ADR-0026 (verdict + critical path) +
`private/notes/phase5-skeleton-audit.md` §"5.1 input bullets"
(quote verbatim — paraphrase risk on #2 `std.atomic.Mutex`
Zig-0.16 gap); F-004 / F-006 / F-008; existing ADR-0007 / 0009 /
0012 / 0017; `.dev/structure_plan.md` `runtime/value/` +
`runtime/gc/`; ROADMAP §9.7 row 5.1 text.

**Step 0 survey target** (`general-purpose` subagent): cw v0
NaN-box + mark-sweep in `~/Documents/MyProducts/ClojureWasm/src/runtime/`
solving each of the 8 input bullets; Zig 0.16 std.atomic vs
std.Io.Mutex with LazySeq cache; DIVERGENCE per F-002.

**Open hazards**: (a) `LazySeq.lock` Zig-0.16 gap — 5.7 owns
re-eval; (b) GC root-set enumerates `LazySeq.thunk/ctx/seq_cache`;
(c) 29 spare `gc_mark` bits — record chosen use; (d) D-040
collision deferred to Phase 7, do not rename in 5.1.

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md) (rows D-005 through
D-040). Step 0.5 debt sweep walks them at resume; pay attention
to D-027 / D-028 (Phase 5 structural surgery), D-029
(`value.zig` split), and D-040 (Phase 7 MethodEntry naming).

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
