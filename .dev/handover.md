# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ 16087139). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed).
  Gate cadence ADR-0107: per-commit smoke (background), batch the full gate ALONE
  at the ≤5 ceiling / boundary. **The full gate is now ~2 min (D-385 root-caused
  + fixed, ADR-0132) and builds `-Dwasm` throughout (ADR-0133)** — the prior
  multi-hour/timeout friction is gone. **Perf measured ONLY on a Release binary**
  (`bench/run_bench.sh --quick` / `scripts/perf.sh`), never `time zig-out/bin/cljw`
  (Debug) — `.claude/rules/perf_measure_release.md`.

- **First commit on resume MUST be: a daily-polish unit** (CFP submitted →
  磨き込み mode). Priority order + full wiring: **`private/notes/polish-priority-audit.md`**.
  **P1** (start here) a `scripts/clj_diff_sweep.sh` drain cycle — sweep an un-swept
  `clojure.core`/stdlib area, classify each DIFF as bug-fix+corpus or a new `AD-NNN`
  (`.dev/accepted_divergences.yaml`), drain highest-value-first (D-210 floor). **P2**
  the cleanest found bug **D-271** (`(with-meta (range 3) m)` type_error — also lands
  IObj/IMeta `instance?`). Then P3 ns-backfill (D-273, `.dev/v0_v1_feature_parity.md`,
  pure-Clojure ns first), P4 validation (D-232 upstream suites + real libs), P5 edges
  (D-321/322/239). Low-risk, incremental, value-first; only a user stop halts.

  **State**: Phase 14 (v0.1.0 milestone) ~95% done — only 14.14 (exit-smoke + tag)
  left; user is NOT cutting the tag yet. Full gate green on Mac + ubuntunote 314/0.

  **Paused (not abandoned)**: the §9.2.S perf campaign — cljw already WINS/parity vs
  Python on most benches; the 2 cold-losers (regex_count 1.8×, sieve 1.4×) + JIT are
  the remaining levers. Resume ONLY on explicit user direction; full state in
  `.dev/perf_v0_baseline.md` + `.dev/perf_campaign_essence.md` + `.dev/optimizations.md`.

- **Forbidden this session**: re-opening the §9.2.S perf campaign as the resume
  DEFAULT (paused — polish is the focus; resume perf only on explicit user
  direction); editing zwasm except via the F-001 finding-handling policy;
  `git push --force*`.

## Just landed — gate root-caused + wasm in default gate (2026-06-12, on `main`)

- **D-385 gate root-cause FIXED (ADR-0132)**: the "multi-hour gate" was the e2e
  running a **Debug** cljw (~1.7s cold-start × ~3200 spawns) — a bare `zig build`
  in `run_tier_a.sh` + a resume-skipped `build_cljw` reverted the shared binary.
  Full gate now **~113-190s**. `cljw --version` bakes in the build mode (semantic
  guard, not a size heuristic).
- **Wasm in the DEFAULT full gate (F-001 amended → ADR-0133)**: every executing
  gate `zig build` carries `-Dwasm`; `phase16_wasm_{ffi,run}` are gate steps;
  zwasm via the build.zig.zon tag-pin (no sibling). Verified GREEN on Mac +
  **ubuntunote 314/0**. The phase4 reversion (non-wasm rebuild) was the bug.
- **D-388 agent nested-send**: clj-faithful deferral (`releasePendingSends`,
  `nested_pending` threadlocal, GC-pinned) + deterministic two-await test.
  Residual single-await timing (eager-drainer vs clj pool) tracked in D-388.

## Cold-start reading order (resume)

handover → **`private/notes/polish-priority-audit.md`** (the prioritized polish
wiring P1-P5) → `.claude/rules/clj_diff_sweep.md` + `.claude/rules/accepted_divergences.md`
(the F-011 sweep + classify discipline) → `.dev/debt.yaml` (D-210 floor / D-271 /
D-273 / D-232 / D-321/322/239) → `.dev/v0_v1_feature_parity.md` (P3 ns-backfill SSOT)
→ `.dev/accepted_divergences.yaml` (AD ledger). clj oracle = `~/Documents/OSS/clojure/`
(spec) + `clj -M -e` (`timeout 20`, bound seqs); v0 ref `~/Documents/MyProducts/ClojureWasm/`.
