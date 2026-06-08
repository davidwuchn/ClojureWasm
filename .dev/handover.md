# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: newest pushed = **3673427a** feat(error): arg-precise carets
  (ADR-0118 cycle 2.5). Cycles 1 + 2 + 2.5 of the error-display overhaul
  (D-323) are DONE + pushed. Working tree clean of source.
- **First commit on resume MUST be: ADR-0118 cycle 3 — frame `Trace:`
  (Decision B).** Turn-key plan lives in
  **`private/notes/phase14-error-cycle3-trace-plan.md`** — read it FIRST.
  Steps: revive the dead `info.zig` error call-stack (`StackFrame` /
  `call_stack` / `pushFrame`…, currently never called); push an error-frame
  at the shared `treeWalkCall` choke point (tree_walk.zig:1040 — both backends
  route here); snapshot the live stack into a new `Info.trace` at
  `setErrorFmt` time (NOT pop-on-success-only — pop-on-both + snapshot, per
  Decision B); render `Trace:` (text, print.zig) + `:trace` (EDN,
  error_render.zig:161 `formatErrorEdn`) + the post-mortem decoder
  (render_error.zig) in lockstep; add a diff_test.zig parity case. **Fork a DA
  on the frame-NAME source** — `Function` (tree_walk.zig:129) has NO name
  field and builtins carry none: candidates are the callee's Var name, the
  call-form symbol, or adding a `Function.name` field (note §"the hard design
  question").
- **Forbidden**: trusting a bg-gate notification's exit code (verify ONLY via
  `SENTINEL-EXIT` / Summary `failed: 0` + `.gate_pass` ==
  `bash scripts/gate_state_hash.sh`). Pre-deciding work past the D-324 track
  below. Editing `.claude/rules/*` (permission-blocked → carry-over). Pinning a
  zwasm v2 tag (F-001).

## After cycle 3 — user-led CFP brush-up track (D-324, user-directed 2026-06-08)

The next track after D-323 cycle 3 is **user-led, not autonomous**: the CFP
brush-up items — **Playground, Edge Demo, documentation, user usability** —
are worked interactively WITH the user. Cycle 3 (frame Trace:) is therefore
the last autonomous unit on the error-display track; when it lands (gate green
+ pushed), the next track is D-324 (the user drives the four items
interactively). Do NOT auto-open a fresh sweep at that boundary. The durable
wiring is `.dev/debt.yaml` D-324 (recall trigger); this section mirrors it.
(span/underline O-NNN under D-323 stays a deferred follow-on, not a blocker.)

## Cycle status (ADR-0118 error display, D-323)

- Cycle 1 (loc back-fill): DONE, pushed.
- Cycle 2 (v0-form renderer): DONE, pushed (6d36acc4).
- Cycle 2.5 (arg-precise carets, Alt 1 — slice side channel + VM loc_stack;
  arithmetic divide/type family uniform): DONE, pushed (3673427a).
- Cycle 3 (frame `Trace:`, Decision B): NEXT.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (NOT
  the -P8 default — it 300s-timeouts mid-e2e under host load). Verify via
  Summary `failed: 0` + `.gate_pass` == `gate_state_hash.sh`, never the
  notification.
- `zig build` (NOT `zig build test`) rebuilds `zig-out/bin/cljw`; `zig build
  test` only builds the unit-test binary (Debug). The gate's e2e cljw is
  ReleaseSafe (`run_all.sh:306-307`). Bench `REGRESSION` rows are informational.
- Docs (`.dev/`, ADRs, this file) do NOT change the gate fingerprint. e2e use
  BARE exprs (cljw -e of `(prn X)` echoes X then nil). Backend default = vm
  (F-012). Measure speed ONLY via bench / scripts/perf.sh (Release). The tool
  channel can corrupt stdout under host load — verify cljw output via per-cmd
  files + Read, not chained echoes.

## Cold-start reading order (tracked-only)

handover → **`private/notes/phase14-error-cycle3-trace-plan.md`** (turn-key
cycle 3 plan + the frame-name design question + beyond-cycle-3 notes) →
`.dev/decisions/0118_error_display_v0_level.md` (Decision B + Rev 2
"Implementation landed") → `.dev/debt.yaml` D-323 + D-324 →
`src/runtime/error/info.zig` (dead error call-stack to revive) +
`src/eval/backend/tree_walk.zig:1040` (treeWalkCall choke point) +
`src/runtime/error/print.zig` (renderer) → CLAUDE.md → `.dev/principle.md`.
