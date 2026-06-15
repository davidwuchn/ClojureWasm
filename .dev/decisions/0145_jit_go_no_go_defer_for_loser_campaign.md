# ADR-0145 — Narrow ARM64 JIT (D-133): go/no-go = NO-GO now; re-sequence last; run the 3-loser runtime campaign first

- **Status**: Proposed → Accepted (2026-06-15)
- **Relates to**: F-010 (interim milestone M = Phase 15 完遂 + cw-v0-程度 JIT;
  its prerequisite chain has an explicit **"JIT go/no-go"** step), F-015
  (completion-grade posture), D-133 (the JIT-ordering debt row), D-386 (dispatch
  perf — superinstructions + ip-hoist + alloc-free arith now landed). Does NOT
  amend F-010 (the JIT remains a nominal M component; this exercises F-010's
  go/no-go step + re-sequences).
- **Devil's-advocate**: `private/notes/jit-go-no-go-da.md` (full fresh-context
  output; the three alternatives + verdict reflected below).
- **Survey**: `private/notes/9.2.S-jit-d133-survey.md` (v0 jit.zig map + cljw
  integration points + the Step 0.6 re-measurement).

## Context

F-010 sets the interim milestone **M = Phase 15 完遂 + a cw-v0-程度 JIT landed**,
with the prerequisite chain **"superinstruction/fusion pass → JIT go/no-go →
narrow JIT."** The superinstruction/fusion pass has landed (O-018…O-022) plus the
dispatch-inline / ip-register-hoist (O-017/O-028) and the alloc-free fixnum arith
fast path (O-029). This ADR is the **JIT go/no-go** the chain calls for.

**The go/no-go data (Step 0.6 re-measurement, ReleaseSafe, hyperfine -N -r12):**

| metric                       | cljw    | Python  | note                          |
|------------------------------|---------|---------|-------------------------------|
| `04_arith_loop` (N=1e6) cold | 30.8 ms | 57.6 ms | **cljw 1.87× faster**         |
| startup (`-e 1`)             | 6.0 ms  | 18.2 ms | → arith_loop *compute* also wins (~25 vs ~40 ms) |

The JIT was the §9.2.S campaign's planned last lever because v0 measured
`arith_loop` 31→3 ms with it. But the superinstruction pass already pushed v1's
`arith_loop` to **beat Python by 1.87× on both cold AND compute**. So the JIT's
**beat-Python value (goal (a), primary) is zero** — already won. Its residual
value is **v0-parity (goal (b), secondary)** on an already-winning bench, at the
**highest cost/risk unit in the project** (executable memory + W^X +
codesign/AMFI entitlement + cross-platform codegen + the register-clobber bug
class v0 shipped three of — per the survey §5).

Meanwhile the "beat Python on EVERY bench" primary goal (F-002/F-015 completion
grade) has exactly **three open failures the narrow arith JIT does not touch**:
sieve 1.5×, regex_count 1.99×, nested_update 1.44× — lazy-seq / regex-engine /
persistent-update bound, which v0 itself won with **runtime levers, not the JIT**
(filter-chain collapsing 24C.7 → sieve 103×; update-in Zig builtins 24C.9).

## Decision

1. **JIT go/no-go = NO-GO now.** Re-sequence the narrow ARM64 JIT (D-133) to
   **last** in the perf campaign. It is NOT cancelled (F-010's M still nominally
   includes it — only the user amends F-010); it is gated behind a concrete
   **ROI predicate**: re-open D-133 when **(i)** a real hot loop surfaces where the
   JIT moves a *Python-losing* or *v0-losing* bench the runtime levers cannot
   reach, OR **(ii)** the 3 losers are closed and v0-parity-on-arith becomes the
   active goal, OR **(iii)** the user re-affirms the JIT as a standalone priority.
2. **Run the 3-loser runtime campaign first** (DA Alt 2 — the only option that can
   *close* the primary goal): **sieve first** (proven cross-platform filter-chain
   collapsing / fused-reduce lever, no equivalence-audit gate), then
   **nested_update** (update-in/assoc-in Zig builtins + vector COW), then
   **regex_count** (after its cross-lang equivalence audit per
   `perf_v0_baseline.md:108`). All cross-platform, no machine code, F-011 §4
   shared-mechanism.
3. **Optional cheap probe before sieve**: the computed-goto / tail-threaded
   dispatch (D-386 lever (c), DA Alt 3) — but v0 measured tail-call dispatch
   **0% on Apple M4**, so budget it as a single **measure-first probe, expect ~0**,
   revert on a flat result. Not a committed unit.
4. **If/when the JIT is built** (ROI predicate fires): module shape =
   **`src/eval/optimize/jit/` dedicated subtree** (portable `CodeBuffer` +
   per-arch `arm64/`/`x86_64/` encoders + the lifted `zwasm` `jit_mem.zig`
   MAP_JIT/W^X), build-flag-gated, cross-platform from day 1, ReleaseSafe-correct
   with a callee-saved trampoline. NOT v0's single-file port (finished-form-dirty:
   unscoped, unflagged, ARM64-only); NOT an SSA mini-IR (over-engineering for a
   narrow fixnum loop, F-002 "excessive skeletons" smell).

## F-010 / F-015 reconciliation (the mode question the DA flagged)

F-010's M = Phase 15 + JIT; deferring the JIT means M is not *literally* reached,
so a strict reading puts the loop **pre-M**, contradicting the "post-M operating
mode" framing in the scaffolding (memory `tech_debt_consolidation` etc.). Resolved:

- The deferral is **F-010 process-compliant** — F-010's own prerequisite chain
  contains the "JIT go/no-go" step; a data-driven NO-GO exercises that step. The
  JIT stays a nominal M component (owed, re-openable), so F-010 is **not amended**
  (only the user amends F-NNN).
- F-015 (newer, 2026-06-15) reframes the project to **completion-grade posture**:
  the quality-elevation loop runs on the built surface NOW, "not bound by the old
  roadmap/guardrails." So the operative mode is **F-015 completion-grade**, with
  the JIT as a **deferred-per-go/no-go** M component — not a literal "post-M". The
  loop should describe its mode as "F-015 completion-grade; M's JIT half deferred
  pending its ROI predicate," not "post-M". (Scaffolding that says "post-M" is
  imprecise but not load-bearingly wrong — the quality loop is the active mode
  either way; corrected opportunistically, not as a churn.)

## Alternatives considered (DA fork, `private/notes/jit-go-no-go-da.md`)

- **Alt 1 — port v0's `jit.zig` minimally**: only "wins" on the forbidden
  diff-size axis; finished-form-dirty (violates A3 dedicated-subtree +
  cross-platform-day-1). Goal (a) +0, goal (b) +1 bench at max cost. Rejected.
- **Alt 2 — 3-loser runtime campaign, defer JIT [RECOMMENDED, ADOPTED]**: advances
  the PRIMARY goal directly (each loser closed is a beat-Python win the JIT cannot
  deliver), fraction of the cost/risk, cross-platform, no machine code. Goal (a)
  +3 → potentially COMPLETE; goal (b) +2-3 side effect. The only option that can
  close goal (a).
- **Alt 3 — computed-goto dispatch**: v0 measured 0% on M4; expected ~0; a
  measure-first probe, not a unit.
- **Verdict**: committing to the full JIT now is NOT right; the ROI questioning is
  sound finished-form judgment (data-grounded, not effort-grounded → does NOT trip
  the Cycle-budget-defer smell — Alt 2 is larger-or-comparable scope AND
  finished-form-cleaner). Adopt Alt 2.

## Consequences

- The perf campaign's next unit is **sieve** (filter-chain collapsing / fused
  reduce), validated by the diff oracle + `clj` corpus (F-011) + a bench
  re-measurement; GC-rooting-sensitive lazy-seq changes are torture-gated
  (`CLJW_GC_TORTURE` + the new `CLJW_GC_TORTURE_ALLOC`).
- D-133 moves to a **go/no-go = no-go-now; re-sequenced last; ROI predicate**
  status (not discharged — the JIT is still owed per F-010).
- No executable-memory / codegen / codesign surface is added now (the project's
  highest-risk surface stays unopened until the ROI predicate fires).
- `handover.md` first-task points at sieve.

## Affected files

- `.dev/debt.yaml` — D-133 status update (go/no-go = no-go-now, re-sequenced).
- `.dev/handover.md` — first-task = sieve (Alt 2).
- `private/notes/9.2.S-jit-d133-survey.md` (Step 0.6 section) +
  `private/notes/jit-go-no-go-da.md` (DA output) — the grounding, preserved for
  the day the ROI predicate fires.
