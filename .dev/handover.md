# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `c296967c`, several commits behind by resume).
- **Direction (user, 2026-05-30)**: raise **functional completeness FIRST**,
  before optimization complexity (no premature JIT/superinstruction). Work
  **corpus-driven**, not AI-probed. Keep strong cross-session state. Clone /
  copy liberally. Fully autonomous; flexible replanning encouraged.
- **First commit on resume MUST be**: take the next remaining feature gap from
  [`.dev/core_coverage_gaps.md`](core_coverage_gaps.md). The corpus robustness
  sweep is done for the common surface (6 batches — crash class CLOSED;
  destructuring/nil-punning/threading/coercion all validated). Remaining gaps,
  in rough priority: **`eval`** (needs a Value→Node/Form path — analyzer works
  on Forms, not runtime Values), **`type`/`class`** (needs a cljw
  type-representation design decision — no JVM Class), regex **capture groups**
  (regex cycle 3, currently `not_implemented`), **resolve / ns-introspection**
  (needs first-class var Value), **D-161** (wire defmulti dispatch to the
  global hierarchy via isa? — a focused Layer-0 unit, plan in the debt row).
  Cheap parallel: keep running `cljw -e` sweep batches on unswept surface.
  Always probe before implementing. Do NOT ask (Direction-ask smell).
- **Forbidden this session**: re-opening anything landed this session (sorted
  collections, transducers 1-5, D-159, the range/sort/interleave/zipmap crash
  fixes, dedupe/distinct O(n²) fix, mapv/fnil arities, nested-lazy print,
  ad-hoc hierarchies, re-seq, read-string) or earlier (AOT, ratio-arith, HAMT,
  keyword/data-as-IFn, atoms). Optimization work (JIT / superinstruction) —
  functional completeness first. Flipping `phase_at_least_14` / v0.1.0 (HELD).

## Current state

Mac gate **168/168** green (parallel e2e pool; `SERIAL_STEPS` serial). Gate
cadence mechanically enforced (additive ≤5; shared-code gates every time;
`.dev/.gate_pass` content-hash). AOT-bootstrap LIVE (ADR-0056). Landed this
session (git log is the SSOT): **sorted collections** complete (ADR-0057 LLRB —
build/read/delete/`-by`/rseq/reversible?/subseq/rsubseq + print/IFn/GC);
**transducers core-complete** (reduced surface + all arities + cat + completing/
transduce/3-arg-into + halt-when; `sequence`/`eduction` = D-160); **D-159**
sort/sort-by comparators; **4 crash fixes** (range/sort/interleave/zipmap stack
overflows → loop/recur — class CLOSED via systematic probe); **dedupe/distinct**
O(n²)→O(n) (transducer delegation); **mapv** multi-coll + **fnil** 2/3-default;
**nested-lazy print** (deepRealize); **ad-hoc hierarchies** (isa?/derive/…,
atom-backed, class? branches dropped); **re-seq** (+ re-find-from); **read-string**
(core==edn, no eval-reader).

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
