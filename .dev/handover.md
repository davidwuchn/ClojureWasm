# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: newest pushed ≈ the bench-baseline commit (see `git log`). Working
  tree clean; gate green (293/0, parallel = serial, no divergence).
- **MODE for the next session (user-directed pivot, 2026-06-08): INTERACTIVE
  CFP prep — NOT the autonomous quality-loop.** The user is steering toward
  Clojure/Conj 2026 CFP work: **demo preparation + repo entry-point tidying**,
  driven interactively. Do **not** auto-select a quality-loop debt row and grind;
  instead open the CFP plan and work *with* the user on it. The specifics are
  deliberately NOT pre-decided here — surface options, let the user choose.
- **First action on resume**: read `private/clojure_conj_2026_cfp/TODO.md`
  (the decided plan; **Phase 2** = pre-submission tasks, deadline **2026-06-13
  landing / 06-14 23:59 ET**) + `SUBMISSION.md` + `MY_CFP.md`, then engage the
  user on which Phase-2 item to take next (demo-runs-on-current-build check /
  link validity / Reviewer-info numbers / Recorded-talk assets). Likely
  near-term, interactive: verify the demos (nREPL+Java interop, polyglot
  `add.wasm`, edge-demo, Playground) run on the current build; tidy README
  Demos + links (repo default branch is `main`=old vs `cw-from-scratch`).
- **Forbidden**: auto-running the autonomous quality-loop this session (the user
  redirected to interactive CFP mode). Pre-deciding demo specifics without the
  user. Pushing to `main` / pinning a zwasm v2 tag (F-001). Putting count-based
  numbers (test count / LOC) into the SUBMISSION (MY_CFP.md:218 — stale +
  meaningless to reviewers; size + cold-start are the only headline figures).

## Done this session (error-display tail closed + CFP-prep mop-up)

- **Error-display cluster fully closed** (all pushed): D-336 trace crosses the
  thread boundary (ADR-0120 §1), D-333 `render-error` decodes EDN `:trace`,
  D-328 callables print `#<ns/name>` (ADR-0121 + AD-025 + DA), D-325 self-named
  fn verified already-working (discharged, stale premise). Error UX is now strong
  (caret / trace / cross-thread fidelity / named callables) — a CFP-grade DX story.
- **Gate**: parallel (`bash test/run_all.sh`) confirmed divergence-free vs
  `--serial-e2e` (both 293/0; only execution mode differs, perf steps stay serial
  in both). Parallel adopted as default; under host load it can run slower /
  flakier (memory `gate_parallel_e2e_timeout`) — fall back to `--serial-e2e` then.
- **Proactive measurements** (for the next session's Reviewer-info refresh):
  Zig 70,735 LOC / Clojure 3,277 / ADRs 122 / active debt 198. Release
  binary-size + cold-start re-measured at current HEAD (see
  `private/clojure_conj_2026_cfp/` measurement note) to confirm the
  submission's <4MB / ~4.5ms claims still hold (were measured at c972d81d).

## Tracked tail (deferred, NOT for the CFP pivot)

- **D-327**: builtins print `#<clojure.core/name>` — depth-2 (immediates have no
  name slot → needs a side `ptr→name` map; `printValue` has no `rt`). Low value
  ("pure pr nicety"). Defer; not a CFP blocker.
- **D-337**: `(class fn)` simple-name (type-system concern, split from ADR-0121).

## Process discipline (SSOT = memory + rules)

- Gate (shared-code): `timeout 1800 bash test/run_all.sh` (parallel default;
  `--serial-e2e` fallback under load). Verify Summary `failed: 0` + `.gate_pass`
  == `gate_state_hash.sh`. Perf numbers ONLY via `bash bench/release_metrics.sh`
  / `scripts/perf.sh` (Release) — never `time zig-out/bin/cljw` (Debug).

## Cold-start reading order (next session = CFP interactive)

handover → `private/clojure_conj_2026_cfp/TODO.md` (Phase 2 + deadline) →
`SUBMISSION.md` + `REVIEWER_INFO.md` + `MY_CFP.md` → README.md (Demos/links) →
`examples/wasm/` (polyglot demo) → `bench/RELEASE_METRICS.md` → CLAUDE.md.
