# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `c296967c`, several commits behind by resume).
- **Direction (user, 2026-05-30)**: raise **functional completeness FIRST**,
  before optimization complexity (no premature JIT/superinstruction). Work
  **corpus-driven**, not AI-probed. Keep strong cross-session state. Clone /
  copy liberally. Fully autonomous; flexible replanning encouraged.
- **First commit on resume MUST be**: continue the **corpus-style robustness
  sweep** driven by [`.dev/core_coverage_gaps.md`](core_coverage_gaps.md) —
  probe common `clojure.core` ops on large / edge inputs (`cljw -e`) to surface
  crashes + wrong answers (the sweep already found 3 segfaults + several gaps;
  see the gap-map's CRASH FIXES + GAPS sections). When the sweep quiets, take
  the remaining gap-map structural items in order: **isa?/hierarchy** →
  **resolve / ns-introspection** (needs first-class var Value) → **trampoline**
  → bigint/bigdec (deprioritized) → **letfn** (surveyed:
  `private/notes/phaseA26-letfn-survey.md`). Always `cljw -e`-probe a gap before
  implementing. Do NOT ask (Direction-ask smell).
- **Forbidden this session**: re-opening anything landed this session (sorted
  collections, transducers cycles 1-5, D-159 sort-comparator, the range/sort/
  interleave crash fixes, mapv multi-coll, nested-lazy print) or earlier (AOT,
  ratio-arith, HAMT, keyword/data-as-IFn, atoms). Optimization work (JIT /
  superinstruction) — functional completeness first. Flipping
  `phase_at_least_14` / tagging v0.1.0 (release HELD).

## Current state

Mac gate **166/166** green, **~55s** (parallel e2e pool; `SERIAL_STEPS`
serial). Gate cadence mechanically enforced (additive ≤5; shared-code gates
every time; `.dev/.gate_pass` content-hash). AOT-bootstrap LIVE (ADR-0056).
Landed this session (git log is the SSOT): **sorted collections** fully
complete (ADR-0057 persistent LLRB — build/get/contains/count/keys/vals/seq/
assoc/conj/LLRB-delete/`-by` comparators/rseq/reversible?/subseq/rsubseq +
print + IFn + GC); **transducers core-complete** (`reduced` surface + every
stateless/stateful arity + cat + completing/transduce/3-arg-into + halt-when;
`sequence`/`eduction` deferred = D-160); **D-159** sort/sort-by comparators;
**3 crash fixes** (range / sort / interleave stack overflows → loop/recur);
**mapv** multi-coll; **nested-lazy print** (deepRealize — partition-by/split-at
render `(…)` not `#<lazy_seq>`).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

Coverage floor heavily advanced. Remaining toward M: finish the corpus-style
coverage/robustness sweep → **Phase 15** concurrency (ADRs 0009/0010) →
superinstruction/fusion → narrow ARM64 JIT (D-133) → **M** → quality loop.
cw-v0 gaps in `.dev/cw_v0_parity_and_gap_plan.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-160** sequence/eduction (need push→pull transducer bridge). **D-158**
  corpus-driven validation (clojuredocs walkthrough → lib test suites). **D-139**
  AOT param-name fidelity. **D-134** letfn + re-seq + mapcat-multi-coll residuals.
  **D-155/156** HAMT collision-bucket / dissoc inline-collapse. **D-150** VM ctor
  parity. **D-153** `(cons x lazy)` count. **D-152** diff oracle `.clj` closures.
  **D-131** built-app non-core. **D-117/118** nREPL (Phase-15). **D-133** JIT floor.
- **Sweep gaps (not yet fixed)**: `mapv`/`interleave` N-coll variadic; `reductions`
  & `distinct` are O(n²) (perf, not crash); lazy-as-map-value still `#<lazy_seq>`.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The only
stop) → `.dev/project_facts.md` (F-010 + edge mission) → `.dev/principle.md`
→ `.dev/core_coverage_gaps.md` (the active sweep work-queue) →
`private/notes/phaseA26-*.md` (sorted / transducers survey + task notes).
