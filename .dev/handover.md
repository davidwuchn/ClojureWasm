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

- **First commit on resume MUST be: the lazy-seq fused-reduce lever** (sieve/mfr —
  the dispatch arc is DONE, these are alloc/lazy-bound). The cljw-clean plan (IReduce-
  on-lazy-source vs chunk-the-cons-walk vs transduce-backed) is in
  `private/notes/9.2.S-v0-perf-deep-survey.md § DISPATCH ARC COMPLETE`. NOT ROI-gated
  (relentless until cljw beats Python on EVERY bench, then toward v0); fast-mode in
  `.dev/perf_campaign_essence.md`. Autonomous; only an explicit user stop halts.

  **Current standing (cljw vs Python ms, 2026-06-11)**: fib 24=24, tak 13<18 (WIN),
  arith_loop 50<58 (WIN), nested_update 24 vs 20 (1.2×), sieve 33 vs 20 (1.65×),
  map_filter_reduce 27 vs 16 (1.7×). Session arc: fib 56→24, arith_loop 170→50,
  nested_update 58→24.

  **Landed this session (all on `main`, diff-oracle-validated per fast-mode)**:
  ADR-0131 in-VM frame stack (2a arena O-016 / 2b flatten — fixes the deep-recursion
  SIGSEGV; do NOT re-do); **the D-386 DISPATCH ARC, now COMPLETE** — O-017 inline
  stepOnce, O-018 `op_*_local_const`, O-019 `op_*_locals`, O-021 `op_branch_*`
  (compare+branch), O-022 `op_recur_loop` (loop back-edge) → fib/tak/arith_loop now
  beat/match Python; **O-020 update-in 3-arg arity** (nested_update 58→24); + the
  velocity MECHANIZATION (gate `--resume` D-385 slice-2, `perf_campaign_essence.md`
  fast-mode, `scripts/perf_campaign_remind.sh` lookahead hook); + the **v0 deep
  survey** (`private/notes/9.2.S-v0-perf-deep-survey.md`). PIVOT finding: the fib tax
  was per-instruction DISPATCH, not call structure — superinstructions were the fix.

  **Next levers** (v0 catalogue, re-derive cljw-clean F-004): fused-reduce / IReduce-
  on-lazy-source (v0 24C.1, mfr 1293→14) for map_filter_reduce; filter-chain collapse
  (24C.7) for sieve; a small update-in/assoc-in Zig builtin (24C.9) for nested_update
  (1.2×, close); then the JIT (37.4, cross-platform required) for the last mile.

  **OWED (validation debt — fast-mode defers the heavy e2e)**: full e2e ran 311/0 on
  ubuntunote at HEAD dd4a56db (O-019); O-020/021/022 are validating on ubuntunote NOW
  (`scripts/run_remote_ubuntu.sh`, the tree is clean). The local serial gate times out
  (D-385) — prefer ubuntunote or `--serial-e2e --resume`.

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
