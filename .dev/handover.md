# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `b8de8224`).
- **First commit on resume MUST be**: continue **D — AOT-bootstrap ADR**
  (user-directed 2026-05-30, the headline edge-startup feature). Read
  `private/notes/phaseA26-d-aot-bootstrap-survey.md` (the Step-0 survey),
  then draft `.dev/decisions/00NN_aot_bootstrap.md` with a Devil's-advocate
  subagent over the four shapes (D1 env-snapshot / D2 AOT-bytecode-bundle /
  D3 lazy-bootstrap / D4 heap-image), pick the v1-fitted shape, then
  implement incrementally. Mission anchor: ROADMAP §1 "cold start ≤ 10ms,
  edge execution". Crux: core.clj is hundreds of `(def f (fn …))` = `fn_val`,
  which `src/eval/bytecode/serialize.zig` excludes; the default backend is
  tree_walk (ADR-0036) so bootstrap fns are AST closures, not bytecode — AOT
  needs a VM-recompile-of-bootstrap (the v0 `vmRecompileAll` equivalent).
- **Forbidden this session**: re-opening D-096 (println stdout — DISCHARGED),
  the test-speed work (build-skip / zone_check / ReleaseSafe — all landed),
  or the macro batches (threading / conditional / iteration / case / condp —
  all landed). Dispatching a CPU-heavy subagent CONCURRENTLY with a gate
  (contends with cold_start → false fail; `gate_continue_remind.sh` warns).
  Flipping `phase_at_least_14` / tagging v0.1.0 (release HELD).

## Current state

Mac gate **125/125** green, **~80s** (was 390s). Test-speed work landed:
build-once-per-gate (`CLJW_SKIP_BUILD`), `zone_check.sh` pure-bash
(15s→0.6s), and the e2e cljw binary in **ReleaseSafe** (`CLJW_OPT`,
compute-heavy e2e 8s→0.6s; unit tests stay Debug). **D-096 discharged** —
shared `Runtime.stdout` writer; `(println …)` now reaches stdout in
`-e`/`-`/file modes (`emitToStdout`, `phase14_println_stdout`). clojure.core
macro coverage extended this session: `as->`/`cond->`/`cond->>`/`some->`/
`some->>` + `if-some`/`when-some`/`doto` + `dotimes`/`while`/`when-first` +
`case` + `condp` (all in `macro_transforms.zig`, e2e-covered).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

Active user-directed work = **D (AOT-bootstrap)**, serving the edge mission
ahead of the default coverage sequence. After D: coverage floor (D-045 HAMT
>8-key wall) → **Phase 15** concurrency (ADRs 0009/0010; unblocks D-117/118
nREPL) → superinstruction/fusion → narrow ARM64 JIT (D-133) → **M** →
quality loop (`docs/works/`). cw-v0 gap plan in
`.dev/cw_v0_parity_and_gap_plan.md` (§A26).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-045** HAMT `.hash_map` body + `valueHash` (the >8-key map wall;
  survey done `private/notes/phaseA26-d045-hamt-survey.md`). **D-085**
  keyword-as-fn `(:k m)` (also blocks keyword thread-steps). **D-134**
  residual macros **letfn / doseq / for** (involved: letrec / `:when`/`:let`/
  `:while` modifiers / laziness — fresh-context). **D-150** VM `op_ctor_call`
  cljw-prefix parity. **D-147** `fn*` self-name. **D-152** diff oracle can't
  cover `.clj` closures. **D-153** `(cons x lazy-seq)` count/print.
  **D-148** `Math/PI` static-field. **D-117/118** nREPL (Phase-15). **D-133**
  JIT floor. (D-076 / D-096 / D-130 / D-136 / D-137 discharged.)

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The only
stop) → `.dev/project_facts.md` (esp. F-010 + the edge mission) →
`.dev/principle.md` → `private/notes/phaseA26-d-aot-bootstrap-survey.md` (D
survey) → `src/eval/bytecode/serialize.zig` + `src/app/builder.zig` +
`src/lang/bootstrap.zig` (the cljw-build + bootstrap path) → ROADMAP §1
(mission) + §A26.
