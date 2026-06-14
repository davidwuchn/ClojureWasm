# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT). **NORMAL PUSH MODE** (user 2026-06-15:
  local-accumulation LIFTED). After each unit's smoke-green commit, `git push origin
  main` immediately (Step 6). `build.zig.zon` `.zwasm` is **SHA-PINNED** to a pushed
  clojurewasm/zwasm commit (`#412966f7…` + content `.hash`, `lazy`) so others build
  reproducibly — NOT the local `../zwasm_from_scratch` path. Advance the pin via
  `zig fetch "git+https://github.com/clojurewasm/zwasm.git#<pushed-SHA>"` (prints the
  hash) then hand-edit `.url`+`.hash`+`.lazy` (the `--save` form mangles a prior
  `.path` entry). Procedure/rationale: zwasm `docs/consuming_prerelease_zwasm.md`.
  Per-commit = smoke; `-Dwasm` now fetches zwasm from git (default build is
  zwasm-lazy, untouched). NOTE: reproducibility-for-others also needs read access to
  the (currently pre-tag) clojurewasm/zwasm repo — user's external action.

- **First task on resume**: **Track R R3 — ROADMAP §9 rewrite** (D-440 item 3), using
  the R2 survey `private/notes/p14-r2-accurate-position-survey.md`. Reframe §9: mark
  the BUILT-but-future phases done (concurrency / Wasm-component build+run+require /
  bytecode-cache / partial VM-superinstr — survey list A), collapse Phases 15-20 into
  ~3 completion-grade GAP AREAS (Concurrency-hardening / Wasm+edge-native / VM-perf→JIT)
  + a small genuinely-future bucket (CLJS, C-FFI, broad-JIT, WIT — survey list B). Fix
  the version drift (`1.0.0-alpha.1` vs v0.1.0) + stale "Final activation step" framing
  (survey list C). Old phase NUMBERING is an input, not a constraint (F-015 cl.4).
  - **Then**: R4 debt整理 (~19 Phase-gated rows, many already read DONE/now:
    D-037/046/224/242/244/245 — survey C) → R5 AI-instruction 大整理. R1 concurrency
    parity DONE this session (agent ctor options/D-441, await-for, swap-vals!/reset-vals!,
    io! — corpus-locked) + remaining gaps filed D-442; R1 hardening (D-244 #4a' auto-collect
    / D-245 Option C) evaluated as GATED-defer (engine correct without them).
  - **Reads: `.dev/project_facts.md` F-015 + ADR-0141 + D-440 + the R2 survey note** +
    ROADMAP §9. (Earlier-queued W1-remaining / Track S micro-units are fill-in below.)

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

