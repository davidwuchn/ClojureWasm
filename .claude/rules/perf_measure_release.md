---
paths:
  - "bench/**"
  - ".dev/optimizations.md"
  - "scripts/perf.sh"
  - "scripts/run_gate.sh"
  - "test/run_all.sh"
---

# Measure perf in Release, never Debug

Auto-loaded when touching perf surfaces (`bench/`, `.dev/optimizations.md`,
`scripts/perf.sh`, `// PERF:`-marked code). The principled guard against
the 2026-05-31 incident where a whole perf "campaign" chased **Debug-build
ghosts**.

## The rule (mechanical)

**Measure cljw runtime speed ONLY through `scripts/perf.sh`** (or the
ReleaseFast `bench/`). It builds an optimised binary into a separate
prefix and times that. **NEVER `time zig-out/bin/cljw`** — that binary is
**Debug**.

```sh
bash scripts/perf.sh '(count (vec (range 1000000)))'   # ReleaseFast, 3 runs
CLJW_PERF_MODE=ReleaseSafe bash scripts/perf.sh '...'  # match cw-v0's mode
```

## Why (the incident)

`build.zig` uses `standardOptimizeOption(.{})`, so **`zig build` (no
`-Doptimize`) defaults to Debug** — deliberately, for fast dev/TDD
iteration. A Debug build of a tree-walk interpreter runs **~10-100× slower**
than the shipped build, so Debug perf numbers are meaningless. Measured
2026-05-31 (same code, same expr):

| expr                            | Debug (`zig build`) | ReleaseFast (`scripts/perf.sh`) |
|---------------------------------|---------------------|---------------------------------|
| `(count (vec (range 1e6)))`     | ~121s (pre-O-003)   | ~0.02s                          |
| `(count (map inc (range 1e5)))` | ~41s (pre-O-004)    | ~0.01s                          |
| startup `cljw -e 1`             | ~0.48s              | ~ms (cw v0 claims ~4ms)         |

The "あからさまに遅い" pathologies that motivated O-001..O-004 were
**Debug artifacts**; cljw already meets the ms-level cold-start mission
target in Release. The algorithmic wins (O(n) over O(n log n), chunked
iteration) still help in Release, but the urgency/framing was Debug-driven.
Any future perf claim MUST cite a `scripts/perf.sh` (Release) number.

## Build-mode policy (structural unification)

| Path                               | Build mode  | Why                                                    |
|------------------------------------|-------------|--------------------------------------------------------|
| Shipped binary / `cljw build`      | ReleaseSafe | optimised + all safety checks                          |
| Gate e2e (`build_cljw`)            | ReleaseSafe | `run_all.sh` exports `CLJW_OPT=ReleaseSafe`            |
| `phase4_*` backend e2e             | ReleaseSafe | unified 2026-05-31 (was `:-Debug` standalone default)  |
| Gate unit tests (`zig build test`) | Debug       | correctness, max diagnostics, fast compile — NOT perf |
| Dev `zig build`                    | Debug       | fast TDD iteration; NEVER time this binary             |
| Perf measurement                   | ReleaseFast | `scripts/perf.sh` only                                 |

So: everything **perf-relevant** is optimised; only unit-test correctness
runs Debug (it never measures speed). Debug stays the dev default purely
for build-iteration speed.

## Related

- `scripts/perf.sh` — the blessed measurement entrypoint.
- `.claude/rules/perf_marker.md` — `// PERF:` markers (cross-links here).
- `.dev/optimizations.md` — the O-NNN ledger; every row's numbers must be
  Release (`scripts/perf.sh`), not Debug.
