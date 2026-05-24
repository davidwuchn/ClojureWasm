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

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 expanded inline with
  17 task rows (5.0–5.16). Phase 4 DONE (every §9.6 row `[x]`,
  4.26.d/e/f closed in this session). Boundary chain ran:
  audit_scaffolding 0 block + 2 soon (queued D-042) + 3 watch;
  simplify subagent applied finding #1 at 393466e + queued
  #2/4/5/7 as D-041; security-review 0 high.
- **Branch**: `cw-from-scratch`. HEAD = 393466e (next will be the
  §9.7 opener commit on the same branch).
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green at
  HEAD.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.1 / 5.0 cleanup-wave audit (D-028)

Walk every Phase-4 skeleton row owned by Phase 5 entry (4.13
`io_interface.zig` / 4.17 `type_descriptor.zig` / 4.18
`protocol.zig` / 4.20 `host/_host_api.zig` / 4.22
`binding_stack.zig` / 4.23 `numeric/big_int.zig` / 4.24
`lazy_seq.zig` / 4.25 `dispatch/method_table.zig`). Per row:
status (skeleton / partial / activate-this-phase), entry ADR
pointer, target activation row in §9.7. Output:
`private/notes/phase5-skeleton-audit.md` + new ADR-0026
(Phase 5 entry scope decree) summarising the audit. This becomes
the foundation for 5.1's ADR draft (NaN-box 第二世代 + GC +
TypeDescriptor co-issue).

**Retrievable identifiers**: ROADMAP §9.7 placeholder lines
(Entry ADRs 0007 / 0008 / 0009 / 0017 / 0023; Entry debts
D-027 / D-028 / D-029 / D-030 / D-032 / D-008 / D-011 / D-014a /
D-020); F-004 / F-005 / F-006 in project_facts.md;
`.dev/structure_plan.md` anticipated `runtime/value/` +
`runtime/gc/` layouts.

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
