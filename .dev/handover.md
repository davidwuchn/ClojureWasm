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

- **Phase**: Phase 4 task list closed — every §9.6 row is `[x]`.
  Phase 4 → DONE / Phase 5 → IN-PROGRESS narrative flip lives in
  the §9.7 opener commit pending the boundary review chain
  (audit_scaffolding + simplify on the phase diff + security
  review on unpushed commits + Phase 5 task list expansion).
- **Branch**: `cw-from-scratch` (long-lived; push after gate
  green; never push to `main`). HEAD = 1f2406a (4.26.f close).
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green at
  HEAD (gained `e2e_phase4_exit_codes` in 4.26.f).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 4 boundary review chain → §9.7 opener

Per CLAUDE.md "Phase boundary review chain" + continue skill:
(1) run `audit_scaffolding` skill; (2) parallel fan-out:
`simplify` on `git diff phase-4-start..HEAD -- src/` + built-in
`security-review` on unpushed commits + outstanding-chapter
subagent (no-op per F-007 dormancy); (3) bench sweep if doc-only
commits left dangling rows; (4) open §9.7 — flip §9 tracker
(Phase 4 DONE, Phase 5 IN-PROGRESS), expand §9.7 task list by
walking entry materials F-004 / F-005 / F-006 + debts D-011 /
D-014a / D-020 / D-027 / D-029 + ADR-0007 / 0009 / 0012 / 0017;
(5) proceed to §9.7.1 Step 0 (general-purpose survey).

**Retrievable identifiers**: ROADMAP §9.6 (just closed) + §9.7
placeholder; CLAUDE.md § Phase boundary review chain; commits
between Phase 4 start and HEAD = 1f2406a via `git log`.

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
