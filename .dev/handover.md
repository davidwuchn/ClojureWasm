# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `c3aa601c` (with-context + read-side). Row 14.13 closed
  2026-05-29 — see `git log`.
- **First commit on resume MUST be**: §9.16 **row 14.14** — Phase 14
  exit smoke + v0.1.0 release + final activation. Three parts: **(a)**
  exit-smoke 5+ cases (repl / nrepl / build / render-error /
  component-build / future-promise-delay / host-stdlib); **(b)** flip
  `build_options.phase_at_least_14 = true` — swaps `runtime/io/stub.zig`
  + REPL/nREPL stubs to real impls, rewrites `src/app/main.zig` dispatch
  per ADR-0015 a2 F140-F144 (do Step 0 survey first); **(c)** tag
  v0.1.0. Begin with (a) or (b).
- **Forbidden this session**: tagging v0.1.0 before the Linux
  **ubuntunote** gate (`bash scripts/run_remote_ubuntu.sh`) is green —
  CLAUDE.md requires the Linux gate before the v0.1.0 tag. Re-opening
  row 14.13 (DONE — bench 14A.0 `3f5aa415`; `binding` `15d7e21f`;
  with-context `c3aa601c`; ADR-0055 + ADR-0042 am1; compat slices +
  D-066 earlier).

## Current state

Phase 14 v0.1.0 IN-PROGRESS. Mac gate **105/105** green (on-disk
`/tmp/gate_wc2.log` @c3aa601c). Rows 14.13 + 14.13.5 (lazy-seq Layer-2)
both `[x]`. cw v1 now has its first dynamic var (`cljw.error/*error-context*`,
Zig-registered) + the `binding` special form (real VM arm, no VM-DEFER).
Per-task note for the 14.13 (3) cluster (binding + with-context +
ADR-0042 am1 cascade) in `private/notes/phase14-task14_13_d3_with_context.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-141** bench multi-lock anchor policy. **D-142** Env-scope the
  `*error-context*` slot (multi-Env nREPL). **D-143** apply multi-arity
  spread vs fixed-method selection. **D-144** user `(throw ex-info)` →
  structured EDN event + context. **D-105/D-106** time / net+crypto
  backing impls. **D-119/D-139/D-140** opportunistic (man-page / AOT
  param-names / startup self-exe read).

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010 + F-004) →
`.dev/principle.md` → ROADMAP §9.16 row 14.14 → ADR-0015 a2 (F140-F144
activation table) + `build_options` + `src/runtime/io/stub.zig` →
`.dev/ubuntunote_setup.md` (Linux gate, run before the v0.1.0 tag).
