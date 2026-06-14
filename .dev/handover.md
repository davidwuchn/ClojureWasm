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

- **First task on resume**: **Track R R1 cont. — concurrency HARDENING (do-now per
  D-440 item 1, NOT Phase-deferred).** Re-evaluate the un-deferred rows as do-now:
  **D-242** (Phase B hardening), **D-244** (worker-collect GC-safety rooting),
  **D-245** (locking parking vs spinlock) — flip dissolved barriers, implement the
  live ones. Add concurrency load/stress coverage + continue clj-parity edge cases
  where the corpus is still thin (ref/STM/future). The loop self-selects within R1
  highest-value-first. D-441 (agent ctor options `:meta`/`:validator`/`:error-handler`/
  `:error-mode` + IRef validator/handler surface) DISCHARGED this session — see git
  log + the discharged D-441 row.
  - **Then the rest of Track R** (USER-DIRECTED completion-grade reorg, F-015 /
    ADR-0141 / D-440): R2 accurate-position survey → R3 ROADMAP §9 rewrite (Phases
    15-20: future → gap-areas-to-completion-grade) → R4 debt整理 (~19 Phase-gated
    rows) → R5 AI-instruction 大整理. Blind Phase-deferral is RETIRED; concurrency
    is BUILT, so harden/parity/load NOW.
  - **Reads: `.dev/project_facts.md` F-015 + ADR-0141 + D-440 + `.dev/sweep_plan.md
    § Track R`** + the D-242/D-244/D-245 rows in debt.yaml. (Earlier-queued
    W1-remaining / Track S micro-units are fill-in BELOW Track R, not the lead.)

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
  - **W1 `:as` + `:refer`**: `cljw.wasm/require-component` (export = a Clojure Var);
    full WIT↔EDN marshalling table fixture-blocked → D-404.
  - **BigDecimal interop**: `.setScale` 2-arg + `.scale/.signum/.unscaledValue/
    .precision/.negate/.abs/.toBigInteger/.stripTrailingZeros` (D-223 atom kwargs too);
    movePointLeft/Right remain → D-439.
  - **yaml/yq hygiene** (user-directed): yaml_ssot_yq.md Golden-rule #4 (yq `+=` writes
    UNQUOTED ids → next-id undercount), audit recipes; fixed a stray `D-396` dup + the
    unquoted D-437/438/439 ids.
  - **F-015 / ADR-0141 / D-440 (USER-DIRECTED completion-grade reframe)** + Track R
    R1: slice 1 (concurrency parity corpus) + **D-441 DISCHARGED** (agent ctor
    options + IRef validator/handler surface; corpus +8) → next = R1 hardening above.

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0) ~95% BUT see F-015 — the phase model itself is being
  reorganized (D-440); "near-complete, strengthen gaps". Conformance: 21 corpora golden.

- **Forbidden this session**: pushing (LOCAL accumulation mode) — incl. the
  relative-path `build.zig.zon` + wasm experiment artifacts; `git push --force*`;
  bare `zig build` for any scripted/probe path (ADR-0133).

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** (the completion-grade posture — read
FIRST, it reframes everything) → **`.dev/decisions/0141_*.md`** (the reframe) →
**`.dev/debt.yaml` D-440** (reorganization epic) + **D-441** (the first sub-unit,
agent ctor options) → **`.dev/sweep_plan.md` § Track R** → `private/notes/
p14-r1-concurrency-parity.md` (D-441 plan + bridge). clj oracle =
`~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`). SAFETY: bounded seqs
+ `-J-Xmx2g`; register new e2e in run_all.sh same-commit; new debt rows via Edit
(quoted id), NOT `yq +=` (yaml_ssot_yq.md Golden-rule #4).

