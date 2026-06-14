# ADR-0141 — Completion-grade reframe: retire blind Phase-deferral; reorganize the roadmap + debt + AI-instruction system to the accurate current position

- Status: Proposed → Accepted (2026-06-15)
- Deciders: user directive (chat 2026-06-15) + autonomous loop (recording + plan)
- Operationalises: **F-015** (completion-grade posture — user-declared law)
- Re-sequences: F-010 (milestone M; the post-M quality loop = this posture)
- Opens: **D-440** (the reorganization epic — the work items)
- Relates: F-003 (structural-deferral, now narrowed), F-011 (clj parity → concurrency),
  ROADMAP §9 (phase tracker to be rewritten), `.dev/principle.md` (defer discipline)

## Context

The project has reached near-completion, but the roadmap + guardrails still encode
an **early-phase, defer-to-future-Phase posture** that no longer matches reality:

- **Concurrency is BUILT** (2026-06-15 assessment): `atom` CAS (4×100 concurrent
  swaps → 400), `future`/`promise`/`deliver`, `ref`+`dosync`+`alter`, `agent`+`send`
  +`await`, `pmap`, `delay`, `locking` all run correctly. Yet it is officially
  "Phase 15 (PENDING)" + "Phase B hardening deferred" — so its tests, official clj
  parity, and load/stress cases are thin (the user's concern: "公式にそのPhaseに
  先送り…されると手薄になりがち").
- **19+ active debt rows** carry a future-Phase gate ("Phase 15-19" / "Phase B" /
  "blocked-by" / "GATED on Phase"). Many barriers have dissolved (the thing is
  built); the gate is now framing, not a real blocker.
- ROADMAP §9 lists Phases 15-20 as `PENDING, expand at Phase N entry` — a
  from-scratch framing for areas that are largely already present.

The reflexive "defer to a future Phase" move (which this session itself kept
hitting — `seque`, `:volatile-mutable` visibility, concurrency hardening — all
waved off as "Phase 15 territory") is the symptom. Per F-015 it is retired.

## Decision

Adopt the **completion-grade posture** (F-015) and execute a **reorganization arc**
(D-440):

1. **Phases 15-20 reframed** from "future work" to **gap areas to bring to
   completion grade**. The default is to assess "is this already built?" and, if
   so, strengthen it (tests / clj parity / load) NOW — not to defer. F-003
   (structural-decision deferral) is **narrowed** to genuinely-unbuilt
   layout/representation decisions; it is not a licence to park built-but-unhardened
   behaviour behind a Phase number.
2. **Concurrency completion-grade pass FIRST** (highest-value, the user's lead
   example): a concurrency test layer, clj-parity verification of the concurrency
   vars (atom/ref/STM/agent/future/promise/delay/locking/pmap), and load/stress
   cases. D-242/D-244/D-245 ("Phase B" hardening / GC-safety / locking-parking) are
   un-deferred; their barriers re-evaluated as "do now".
3. **Roadmap rewrite**: ROADMAP §9 phase tracker + the PENDING-Phase sections
   rewritten to the accurate current position; the old numbering is an input, not a
   constraint (F-015 cl.4).
4. **Debt整理**: re-evaluate every Phase-gated debt row (Step 0.5 sweep, but
   exhaustive) — flip the ones whose barrier dissolved; reclassify the rest with an
   honest, non-Phase-number barrier.
5. **AI-instruction 大整理**: principle.md (the structural-imagination / defer
   discipline), CLAUDE.md (phase-entry rules, the loop's Phase-boundary chain), and
   the gate/guardrails — audited + reorganized so they describe a near-complete
   project, not an early-phase one.

The work items + sequencing live in **D-440** (the epic). This ADR records the
reframe decision; D-440 is the execution ledger.

## Alternatives considered

This is a **user-directed F-015-level posture change** (chat 2026-06-15), not a
loop-autonomous design choice, so the mandatory Devil's-advocate fork (for
loop-self-decided ADRs) does not gate it. The decision space the user left open is
*how* to reorganize, not *whether*; the options weighed:

- **(A, chosen) Reframe in place + a scheduled reorganization arc (D-440).** Keep
  the F-NNN/ADR/debt machinery; rewrite the phase model + drain the Phase-gated
  debt + audit the AI instructions as a tracked epic. Honest, incremental,
  reversible per-step. Matches the user's "queue it into your near future".
- **(B, rejected) Abolish the phase model entirely now (flat backlog).** Cleaner
  end-state but a big-bang rewrite that throws away the still-useful §9 structure
  and the audit trail in one step; higher risk, and the user said "queue it", not
  "do it all this instant".
- **(C, rejected) Do nothing structural; just un-defer concurrency.** Fixes the
  lead symptom but leaves the stale phase model + 19 Phase-gated rows + the
  early-phase guardrails — the user explicitly asked for the roadmap/debt/
  instruction reorganization, not only the concurrency fix.

## Consequences

- The loop stops reflexively deferring built behaviour to a future Phase; "is it
  already built? then harden it now" becomes the default (F-015).
- Concurrency gets first-class tests + parity + load coverage (un-deferred).
- The roadmap, debt ledger, and AI-instruction system get reorganized to a
  completion-grade project (D-440), freeing future work from stale early-phase
  framing.
- F-010's milestone M "Phase 15 完遂" collapses into the concurrency completion
  pass; the post-M quality loop and this posture are one standing mode.

## Affected files

- `.dev/project_facts.md` — F-015 (the user-declared posture).
- `.dev/decisions/0141_*.md` — this ADR.
- `.dev/debt.yaml` — D-440 (the reorganization epic).
- `.dev/sweep_plan.md` + `.dev/handover.md` — D-440 wired as the imminent arc.
- (D-440 execution) ROADMAP §9, principle.md, CLAUDE.md, the Phase-gated debt rows.
