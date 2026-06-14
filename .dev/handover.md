# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT). **PHASE MODE = LOCAL ACCUMULATION
  (NO push), wasm = RELATIVE-path zon** — user override 2026-06-14. Commit each
  unit locally; do NOT `git push` (ignore the push reminders this phase); keep
  `build.zig.zon` `.zwasm = .{ .path = "../zwasm_from_scratch" }` (push-forbidden;
  the local zwasm HEAD has REQ-7). SSOT: memory `local-accumulation-sweep-phase`
  + `.dev/sweep_plan.md` § Phase mode. Per-commit = smoke (default build is
  zwasm-lazy-safe); wasm work also runs `-Dwasm`.

- **First task on resume**: **Track R R1 — concurrency completion-grade pass
  (USER-DIRECTED 2026-06-15; F-015 / ADR-0141 / D-440).** The project is
  near-complete; the blind Phase-deferral model is RETIRED. Concurrency is in fact
  BUILT (atom CAS / future / promise / ref+dosync / agent / pmap / delay / locking
  all verified 2026-06-15) but officially "Phase 15 / Phase B deferred" → its tests,
  clj parity, and load/stress are thin. R1 = add a concurrency test layer (Layer
  1/2) + clj-parity verification of the concurrency vars + load/stress cases;
  un-defer D-242 (hardening) / D-244 (worker-collect GC-safety rooting) / D-245
  (locking parking). Then the rest of the reorganization arc (R2 survey → R3 ROADMAP
  §9 rewrite → R4 debt整理 of ~19 Phase-gated rows → R5 AI-instruction 大整理).
  **Reads: `.dev/project_facts.md` F-015 + ADR-0141 + D-440 + `.dev/sweep_plan.md
  § Track R`.** (Earlier-queued W1-remaining / Track S micro-units are now fill-in
  BELOW Track R, not the lead.)

- **This session landed (git log = SSOT)** — Track D (the user-directed
  divergence-burden queue) DRAINED + 2 more units + W1 first slice:
  - **D1 / ADR-0139**: seq/lazy/range/Sequential-instance as a map/set KEY now
    content-hashes (rt-aware `hashDispatch`/`eqConsult` via ADR-0129 `current_env`
    + `runEnvelope` arming). D-432/D-408 discharged; nested+memoized residual → D-437.
  - **D2 / ADR-0140**: `(stack-trace e)` → cljw-shaped `{:ns :fn :file :line :column}`
    frame maps; `clojure.stacktrace` prints frames; `Throwable->map` `:trace`/`:at`
    filled. AD-029 amended, AD-033 added, D-389 discharged, D-438 (fixed the dangling
    D-232 cross-ref). **Track D D3 = Phase-15-gated (do not start).**
  - **D-223**: `(atom x & {:keys [meta validator]})` ctor kwargs (+ catalog code
    `ref_options_odd`).
  - **`clojure.core/intern`** (programmatic Var creation) — was the W1 blocker.
  - **W1 first slice**: `cljw.wasm/require-component` (export = a Clojure Var).

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0 milestone) ~95%. Conformance: 19 corpora golden.

- **Forbidden this session**: pushing (LOCAL accumulation mode) — incl. the
  relative-path `build.zig.zon` + wasm experiment artifacts; `git push --force*`;
  bare `zig build` for any scripted/probe path (ADR-0133).

## Cold-start reading order (resume)

handover → **`.dev/sweep_plan.md` § Track W** (W1 remaining) + **§ Track S**
(the self-select fallback) → `src/lang/clj/cljw/wasm.clj` (W1 impl) →
`.dev/debt.yaml` (D-404 [W1], D-437 [seq-key residual], D-232 [validation
campaign]) → `.dev/project_facts.md` F-014 + ADR-0135 (wasm component as ns).
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`).
SAFETY: bounded seqs + register new e2e in run_all.sh same-commit.
