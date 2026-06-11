# ADR-0132: The gate's shared e2e binary MUST be ReleaseSafe (the Debug-binary perf cliff)

- Status: Proposed → Accepted (2026-06-12)
- Supersedes / relates to: ADR-0107 (two-tier gate cadence), D-385 (slow
  gate). Amends `.claude/rules/gate_cadence.md` (the ~5-min / ~30-min
  framing was a symptom, not an inherent cost).

## Context

D-385 framed the full gate (`test/run_all.sh`) as an inherent ~30-min run
whose only relief was `--resume` + `--serial-e2e`. Investigating "why is the
gate so slow" (2026-06-12) found the premise was **false**: the gate was
running its 291-step e2e suite against a **Debug** `cljw` binary.

Measured facts (Apple Silicon, host idle):

| binary      | `cljw -e '(+ 1 2)'` cold-start | `phase14_seq_helpers2.sh` |
|-------------|--------------------------------|---------------------------|
| Debug       | **1.70 s**                     | **391 s**                 |
| ReleaseSafe | **~0.005 s**                   | **0.66 s**                |

The e2e suite spawns ~3200 short-lived `cljw` processes; at the Debug
cold-start that is ~90 min of pure process startup. On ReleaseSafe the whole
e2e suite is ~5 s serial / ~1.5 s parallel. The intended design was already
ReleaseSafe (`run_all.sh` exports `CLJW_OPT=ReleaseSafe`; `build_cljw` builds
it once; e2e scripts skip their own build via `CLJW_SKIP_BUILD`), but **three
compounding bugs silently reverted the shared `zig-out/bin/cljw` to Debug**:

1. **`test/clj/run_tier_a.sh` ran a bare `zig build`** (no `-Doptimize`, no
   `CLJW_SKIP_BUILD` guard) → installed a **Debug** binary right before the
   291-step parallel pool. Every subsequent step then ran Debug. *(primary)*
2. **`build_cljw` was in the `--resume` ledger** → a `--resume` pass skipped
   it, so the ReleaseSafe binary was never (re)built and e2e ran whatever
   stale Debug binary existed.
3. **The ReleaseSafe guard ran only once**, right after `build_cljw`, so a
   *later* reversion (bug 1) was invisible.

Amplifier: on a Debug binary the `-P8` parallel pool is *slower* than serial
(concurrent cold-starts contend on the kernel VM reservation / AMFI signature
check — measured -P8 13.7 s vs -P4 4.1 s for 40 Debug-run scripts). On
ReleaseSafe, parallelism is harmless (-P1 0.72 s … -P8 0.19 s for the same
40). So "parallel is bad" is true *only* on Debug; the real defect is the
Debug binary, and parallelism merely magnified it.

This is a **silent perf cliff**: every test still PASSes (Debug and
ReleaseSafe compute identical Values), only wall-time differs ~100×, so no
failure ever pointed at it.

## Decision

Make "the shared e2e binary is optimised" a **mechanically enforced
invariant**, not an implicit assumption.

1. **Every gate-invoked `zig build` either honours `CLJW_SKIP_BUILD` or
   passes `-Doptimize="${CLJW_OPT:-ReleaseSafe}"`** — never a bare
   `zig build` (= Debug). Fixed: `test/clj/run_tier_a.sh` (the live bug),
   `scripts/clj_diff_sweep.sh`, `scripts/check_corpus_regression.sh` (latent
   `[ -x "$BIN" ] || zig build` fallbacks).
2. **`build_cljw` + `assert_e2e_releasesafe` are `NO_RESUME_STEPS`** — they
   run on every pass (including `--resume`), so the optimised binary is
   always (re)established before e2e. A cache-hit rebuild is ~0.3 s.
3. **Semantic build-mode guard, not a size heuristic.** `cljw --version` now
   bakes in `@import("builtin").mode` →
   `ClojureWasm v<ver> (ReleaseSafe)`. The post-`build_cljw` guard AND a new
   **pre-parallel-pool backstop** both assert the mode is not `Debug`,
   aborting loudly if a step reverted the binary. (Replaces the interim
   `wc -c < binary` < 8 MB size check — semantic, per user direction to use
   a Zig-native build-mode signal.)

## Consequences

- **Full gate: ~113 s** (was multi-hour / timing out across 5 `--resume`
  passes). FAIL 0, skipped 0, `.gate_pass` fingerprint matches. The "~30-min
  gate" was the Debug cliff; D-385's resume/timing slices (already landed)
  remain useful but the throughput crisis is resolved.
- A future bare `zig build` in any gate-path script can no longer silently
  cost 100× — the backstop aborts before the pool with a build-mode message.
- `cljw --version` is now self-describing for users too (no more "guess the
  build from the binary size").
- **Not fixed here (tracked separately):** the `phase16_wasm_*` e2e are not
  wired into `run_all.sh`, so the Wasm-FFI *execution* path is not gate-
  tested (user-flagged 2026-06-12). New debt row — see D-385 sibling.

## Alternatives considered

- **Size-threshold guard (`wc -c` < 8 MB).** Landed first as the interim
  guard; rejected as the final form — a heuristic that drifts as the binary
  grows, and the user explicitly asked for a semantic Zig build-mode signal.
  `@import("builtin").mode` is comptime-known and exact.
- **Dedicated `cljw --build-mode` flag.** Cleaner to parse, but a separate
  flag the user would not see. Folded into `--version` instead so the signal
  is both human-facing (the original "size is inconvenient" complaint) and
  machine-checkable.
- **Remove / cap the parallel e2e pool.** Tempting given "-P8 is slower",
  but the measurement shows parallelism is *fine* on ReleaseSafe; the pool is
  not the defect. Keeping it preserves headroom; the real fix is the binary.
- **Isolate the e2e binary to a dedicated immutable path** so no `zig build`
  can clobber it. The structurally cleanest option, but needs `build.zig` to
  emit a second artifact name; deferred — the invariant guard + the
  bare-build ban achieve the same guarantee with far less surgery.
