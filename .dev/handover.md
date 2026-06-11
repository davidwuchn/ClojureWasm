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

- **First commit on resume MUST be: D-386 — per-instruction DISPATCH efficiency**
  (the §9.2.S campaign's real fib/tak lever, found 2026-06-11). The campaign is NOT
  ROI-gated (optimize relentlessly until cljw beats Python across `bench/`);
  user-directed 2026-06-11. Autonomous; only an explicit user stop halts.

  **State**: cljw beats Python ≥12/23. Landed THIS campaign: O-014 arith + O-015
  frame rooting; `bindCallFrame` (`ab1959c2`); ADR-0131 (Alt A, +DA); the
  `frame_local_alloc` torture gate (`13cefee8`); **2a operand arena (`a12fdb09`,
  O-016) — fib 56→41 ms, tak 18→15** (real win, cache locality); **2b the flatten**
  (op_call pushes in-VM frames, no host eval re-entry) — **perf-NEUTRAL but a
  validated robustness fix** (deep non-tail recursion SIGSEGV'd ~1300 → now runs to
  2048 then a bounded `stack_overflow`; deep1500 ✓). Do NOT re-do 2a/2b.

  **CAMPAIGN PIVOT (the key finding)**: a `sample` re-profile after 2b showed the
  5-host-frame cycle COLLAPSED yet fib stayed 39-41 ms → **the tax is NOT the call
  structure, it's per-instruction DISPATCH** (`stepOnce` is a fn CALLED PER OP +
  sp/ip read+write-back every op + 3 per-op polls; ~0.3 ns/op vs v0 ~0.1). Both
  Design 2 (kept recursion) and 2b (removed it) measured neutral — confirmed.
  **D-386 plan** (cheapest first, measure each): (a) INLINE `stepOnce` into the eval
  loop (kill the per-op call boundary + write-back); (b) BATCH the safepoint/budget/
  torture polls v0-style (every ~256 ops, not every op); (c) computed-goto /
  superinstructions (D-133 JIT territory). Full finding: survey `§ 2b LANDED +
  CAMPAIGN PIVOT`. Orthogonal to the frame model. Diff oracle + torture each round.

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
