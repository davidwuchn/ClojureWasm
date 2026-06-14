# ADR-0142 — ROADMAP §9 completion-grade reframe (Track R R3)

- **Status**: Accepted (2026-06-15)
- **Context tier**: structural (ROADMAP §9 amendment per §17)
- **Supersedes / amends**: amends ROADMAP §9 in place; executes ADR-0141 /
  F-015 / debt D-440 item 3. Does NOT supersede the §9.3-9.16 DONE archive
  rows or the §9.2.R/S/P campaign overlays (those are preserved).

## Context

F-015 (project_facts) declares the project near-complete and retires the
early-phase "defer-to-future-Phase / expand-at-entry" posture. The R2
accurate-position survey (`private/notes/p14-r2-accurate-position-survey.md`)
established the ground truth by reading source/tests, not prose:

- Phases 9-13 are **DONE** (Phase 12 mislabeled "DONE-PARTIAL" — the bytecode
  cache is complete); Phase 14 is **done modulo the v0.1.0 tag**.
- Phases 15-20 are **not "future work"** — most is BUILT: concurrency (Phase 15)
  is built + race-hardened; Wasm component build/run/require is built (mislocated
  across "Phase 16/19"); VM superinstruction/fusion (Phase 17) is partial (a real
  slice landed); math + module/deps (Phase 18) are done.
- Genuinely unbuilt: ClojureScript→JS (Phase 16), C FFI (Phase 18), broad JIT
  (Phase 20), `future-cancel`/`seque` (D-442), the java.time trio (D-105).

The §9 tracker still frames the built work as "PENDING, expand at entry" with
stale stub-swap "Final activation step" / `build_options.phase_at_least_N`
sentences for impls that already shipped (STM/locking/agent), and a v0.1.0
version ladder that no longer matches `build.zig.zon` (`1.0.0-alpha.1`).

## Decision

Reframe ROADMAP §9 to the **completion-grade gap-area model** (DA-fork
Alternative 2, executed fully):

1. **Tracker table** — Phases 9-13 → DONE; Phase 12 DONE (not DONE-PARTIAL);
   Phase 14 → "release mechanics" (the single open item is the tag + version
   reconcile). Phases 15-20 rows reframed from "PENDING" to their **gap-area
   role + maturity** (BUILT / hardening / future).
2. **Gap-area grouping** — the Phase 15-20 work is organized into **three
   completion-grade gap areas** + a small **genuinely-future bucket**:
   - **(I) Concurrency hardening** — BUILT + race-hardened; gaps = parity/load
     (Track R R1, done this session) + D-442 (future-cancel/seque/legacy-agent
     surface) + AD-018 (`:volatile-mutable` cross-thread re-eval) + D-105
     (java.time trio).
   - **(II) Wasm / edge-native** — component build/run/require BUILT; gap = WIT
     marshalling (D-404) + zwasm integration shape (D-036/D-350).
   - **(III) VM perf (fusion → JIT)** — a fusion/superinstruction slice landed
     (D-386 / O-018/019/021/023); gap = remaining fusion surface + the narrow
     ARM64 JIT (F-010 milestone M) → broad JIT go/no-go (distal).
   - **Genuinely-future bucket** — ClojureScript→JS, C FFI, broad JIT.
3. **Anchor stability (the hazard mitigation)** — the §9.17-9.22 section IDs are
   **preserved** (retitled to their gap-area role, bodies fully rewritten — NOT
   a banner-on-skeleton, which is the rejected Alt 1 smell). A **phase-number →
   gap-area redirect table** is added at the top of §9. Together these keep every
   "Phase N" / §9.N citation in the ~41 ADRs + ~30 debt rows + the §9.2.R/S/P
   overlays + `phase_at_least_N` flags resolving, so the collapse does not create
   a dead-citation transient window (the DA-fork's #1 hazard).
4. **Drop the stale framing** — the `phase_at_least_N` "Final activation step"
   sentences for shipped impls (STM/locking/agent) are deleted; the §9.2.P
   "ACTIVE — resume here next session" header (stale — D-164/C1-C7 largely
   worked, D-441 discharged this session) is corrected.
5. **Version reconcile** — §9.1/§9.2 note that `1.0.0-alpha.1` is the actual
   version string; the v0.1.0/v0.2.0/v0.3.0 ladder is kept-for-history.
6. The deeper citation rewrites (debt rows' "Phase N target" barriers →
   gap-area barriers; the AI-instruction phase-entry machinery) land in the
   **same D-440 arc** as R4 (debt整理) + R5 (instruction 大整理) — the DA-fork's
   required sequencing so the redirect table is a bridge, not a permanent
   tombstone.

F-015 cl.4 frees the numbering ("an input, not a constraint"); F-002 makes
diff size a non-constraint (so Alt 2 over Alt 1 is not a budget call).

## Alternatives considered

Verbatim from the mandatory Devil's-advocate fork (fresh context, F-NNN-briefed):

> **Leading F-NNN finding (no violation):** None of the three alternatives
> violates an F-NNN. F-015 cl.4 frees the numbering, so even the wildcard is
> in-envelope. F-002 makes diff-size a non-constraint. F-010's milestone-M
> references "Phase 15" by name — ADR-0141 already collapsed M's "Phase 15 完遂"
> into the concurrency pass, so a reframe must keep an M-anchor (a named
> milestone, not a number) or it orphans F-010's gate (a breakage to manage,
> not a block).
>
> **Alt 1 — Smallest-diff (status-flip + stale-sentence strike, numbering kept):**
> flip Phase 12/9-13 to DONE, mark 14 done-modulo-tag, prepend a STATUS banner to
> §9.17-9.22 instead of rewriting bodies, delete stale `phase_at_least_N`
> sentences, reconcile version in one place. BETTER: lowest cross-reference blast
> radius — every "Phase 15/16/19" citation still resolves; no ADR Supersedes
> edits; §9.2.R/S/P overlays untouched; reversible. BREAKS: it is exactly the
> posture F-015 retires — a "PENDING" section with an "actually built" banner is
> the literal Smallest-diff-bias smell; the reader still sees the skeleton; the
> banner-vs-body contradiction is worse than either pure state. This is ADR-0141's
> already-rejected option (C) wearing a roadmap hat. REJECTED.
>
> **Alt 2 — Finished-form-clean (3-gap-area reframe, executed fully) [RECOMMENDED]:**
> collapse §9.17-9.22 into three completion-grade gap-area sections (Concurrency
> hardening / Wasm-edge-native / VM-perf fusion→JIT) + a genuinely-future bucket
> (CLJS, C FFI, broad JIT, future-cancel/seque, java.time trio); Phases 9-13 DONE,
> 14 release-mechanics; drop every `phase_at_least_N` activation sentence for
> shipped impls; reconcile version; add a phase-number→gap-area redirect table.
> BETTER than Alt 1: it IS the finished form (F-015 cl.1 completion-grade, F-002
> cl.2 cleaner-form-wins); the reader sees a near-complete project; it absorbs the
> survey's mislocations (wasm under "Phase 16/19") into capability areas where the
> feature lives, killing "can't trust the number to locate a feature". BREAKS
> (concrete, and the mitigation that makes it the recommendation): (1) ~41 ADRs
> cite "Phase 15/16/17/19/20" by number; (2) ~30 debt rows carry "Phase N
> target/entry"; (3) §9.2.R/S/P overlays say "drawing on §9.19 Phase 17 + §9.22
> Phase 20"; (4) `build_options.phase_at_least_15/17` + ADR-0023 reference phase
> numbers. MITIGATION (must ship same arc, per F-002 "rework that yields a cleaner
> form is a feature"): the redirect table is necessary but not sufficient — D-440
> item 4 (debt re-barrier) + item 5 (instruction 大整理) must run in the same arc
> so dangling citations are rewritten at source. If R3 ships the collapse but
> R4/R5 lag, 40+ docs cite dead phase numbers — that transient is the one genuine
> hazard, a sequencing discipline, NOT a reason to downgrade to Alt 1
> (downgrading on that ground would be the Cycle-budget-defer smell). Also: F-010's
> milestone-M "Phase 15" anchor must be renamed to a milestone token in the same
> edit or F-010's gate orphans.
>
> **Alt 3 — Wildcard (abolish phase-numbering; capability-matrix + milestone-ledger):**
> drop the phase-number axis entirely; replace with (1) a capability matrix
> (capability area × maturity `shipped`/`hardening`/`future` + evidence +
> draining-debt) and (2) a milestone ledger (named dated milestones referencing
> capability rows). BETTER: the TRUE finished form for a near-complete runtime —
> O(1) "is X done?", never rots into PENDING-vs-built contradiction (maturity is a
> first-class column), cleanly separates what (capability) from when (milestone) —
> exactly the F-010 Phase-15-is-both-capability-and-milestone confusion. A
> capability matrix is not the flat-backlog ADR-0141 rejected (it preserves
> structure, drops only the number axis). BREAKS: largest blast radius — every
> phase-number citation becomes meaningless with no 1:1 redirect (one-to-many:
> Phase 16 = wasm + CLJS); the whole `phase_at_least_N` / ADR-0023 mechanism loses
> its referent; CLAUDE.md's phase-entry reading-list machinery assumes a phase
> axis. It is a depth-4 rewrite of the project's organizing metaphor — correct as
> a finished form, but it converts D-440 from "reorganization arc" into
> "re-architect the planning system", exceeding what R3 can land safely before
> R4/R5.
>
> **Recommendation: Alt 2, executed fully, redirect table in R3 + citation
> rewrites in the same D-440 arc (R4 + R5).** Cleanest form reachable within the
> D-440 arc as scoped. Alt 3 is cleaner still (and per F-002 I am obligated to say
> so, not reflexively pick the smaller change) — but it is a *successor epic*, not
> R3: it redefines the planning axis, best opened as its own ADR once Alt 2 has
> drained the phase-number citations to a small set. Record Alt 3 as a forward
> debt row so the finished-form pull is captured, not lost. Alt 1 rejected outright.

The main loop adopts the recommendation. Alt 3 is recorded as forward debt
**D-443** (capability-matrix + milestone-ledger successor model).

## Consequences

- §9 reads as a near-complete project: Phases 9-14 done, three live hardening
  gap areas + an honest future bucket, no skeleton residue.
- The phase-number→gap-area redirect table + preserved §9.N anchors mean
  existing "Phase N" citations keep resolving through the R4/R5 cleanup.
- **Sequencing obligation**: R4 (debt re-barrier) + R5 (instruction 大整理) run
  in the same arc to rewrite "Phase N target" barriers + the phase-entry
  machinery to gap-area terms. Until they land, the redirect table is the bridge.
- F-010's milestone-M anchor is named ("M / concurrency-complete + narrow JIT"),
  not phase-numbered.
- `build_options.phase_at_least_N` flags are now vestigial (every flag guards
  shipped code); their retirement is folded into R5 (not this ADR).
- D-443 captures the Alt-3 capability-matrix model as the natural successor.
