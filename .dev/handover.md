# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ f35784ba). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed).
  Gate cadence ADR-0107: per-commit smoke (background), batch the full gate ALONE
  at the ≤5 ceiling / boundary. **Perf measured ONLY on a Release binary**
  (`bench/run_bench.sh --quick` / `scripts/perf.sh`), never `time zig-out/bin/cljw`
  (Debug) — `.claude/rules/perf_measure_release.md`.

- **First commit on resume MUST be: the next Python-loser perf unit** (sieve 33 vs
  20, map_filter_reduce 26 vs 16, or arith_loop 76 vs 58 — the campaign roadmap +
  v0 levers are in `private/notes/9.2.S-flat-frame-survey.md § CAMPAIGN ROADMAP`).
  NOT ROI-gated (relentless until cljw beats Python on EVERY bench, then toward v0);
  fast-mode in `.dev/perf_campaign_essence.md`. Autonomous; only an explicit user stop halts.

  **Current standing (cljw vs Python ms, this session 2026-06-11)**: fib 26 vs 24
  (parity ✓), tak 13 vs 18 (WIN), nested_update 24 vs 20 (1.2×), arith_loop 76 vs 58,
  sieve 33 vs 20, map_filter_reduce 26 vs ~16. Session arc: fib 56→26, arith_loop
  170→76, nested_update 58→24.

  **Landed this session (all on `main`, diff-oracle-validated per fast-mode)**:
  ADR-0131 in-VM frame stack (2a arena O-016 / 2b flatten — perf-neutral but fixes
  the deep-recursion SIGSEGV; do NOT re-do); **the D-386 dispatch arc** —
  O-017 inline stepOnce (fib 41→33), O-018 `op_*_local_const` superinstr (fib 33→26),
  O-019 `op_*_locals` superinstr (arith_loop 94→76); **O-020 update-in 3-arg arity**
  (nested_update 58→24); + the velocity MECHANIZATION (gate `--resume` ledger D-385
  slice-2, `.dev/perf_campaign_essence.md` fast-mode, `scripts/perf_campaign_remind.sh`
  lookahead hook). The CAMPAIGN-PIVOT finding: the fib tax was per-instruction
  DISPATCH, not call structure (2b confirmed it neutral); superinstructions are the
  v0-proven lever (more in `private/notes/9.2.S-flat-frame-survey.md`).

  **Next levers** (v0 catalogue, re-derive cljw-clean F-004): branch fusion
  (`compare + jump_if_false` → 1; fib/arith_loop `(if (< …))`) + `recur_loop` fusion
  (arith_loop's loop back-edge); fused-reduce (24C.1) for map_filter_reduce;
  filter-chain collapse (24C.7) for sieve; then the JIT (37.4) for the last mile.

  **OWED (validation debt — fast-mode deferred the heavy e2e)**: a full e2e gate has
  NOT run since before 2b (diff oracle covered each commit). Run `bash test/run_all.sh
  --serial-e2e --resume` at the next pause, OR on `ubuntunote` — BUT the ubuntunote
  working tree is DIRTY (`git checkout main` failed on the remote); `ssh ubuntunote
  'cd <repo> && git reset --hard'` first, then `scripts/run_remote_ubuntu.sh`.

  **Measurement cadence (keep iteration fast)**: per iteration a FOCUSED quick bench
  only (`bash bench/run_bench.sh --quick --bench=<name>`); do NOT full-bench or
  compare to Python every round; commit on ONE smoke (ADR-0107, ≤5 ride);
  spot-check the impact area (changed e2e smoke + clj corpus + `CLJW_GC_TORTURE` on
  any dispatch/frame change — the O-005/O-013 reverts), not a full gate; batch the
  full gate + full + cross-lang bench + markdown refresh only when wins solidify.
  Each opt: `// PERF:` marker + O-NNN row (`.dev/optimizations.md`) + clj corpus
  (F-011). Big surgery welcome (F-002); each unit its own revert-friendly commit.

- **Forbidden this session**: cheating the benchmarks (handicapping other languages
  / any manipulation to fake a cljw win — honest equivalence only, already audited
  PASS); editing zwasm; `git push --force*`.

## Just landed — flat-frame lever settled 2026-06-11 (pushed to `main`)

`bindCallFrame` shared single-source binder extracted (`ab1959c2`); Design 2
measured null + reverted; **ADR-0131 (in-VM call-frame stack, Alt A) Accepted**
with a Devil's-advocate fork. Prior batch: O-014 arith intrinsics + O-015 frame
rooting → cljw 12/23 vs Python; D-385 gate timing.
- **Cautionary precedents for any dispatch/frame change**: O-005 (frame nil-init
  left rooting at full 256 → traced undefined tail → UAF) + O-013 (concat
  right-nest → interleave stack overflow). Both reverted; both have regression
  tests. ADR-0131's torture e2e MUST allocate per frame (fib proves no rooting).

## Cold-start reading order (resume)

handover → **`.dev/decisions/0131_in_vm_call_frame_stack.md`** (the lever's full
design + DA alternatives) → `private/notes/9.2.S-flat-frame-survey.md` (§ EMPIRICAL
UPDATE: Design 2 null + the profile) → `.dev/perf_v0_baseline.md` (§ Call-path
lever + Measurement cadence + v0 catalog) → `.dev/optimizations.md` (O-NNN incl
O-005/O-014/O-015) → `.dev/debt.yaml` (D-385 gate, D-133 JIT). v0 ref:
`~/Documents/MyProducts/ClojureWasm/` (re-derive per F-004, never copy).
