# cw v1 test layout

> 5 layers per ADR-0021. `test/run_all.sh` is the single entry point.

## Layers

| # | Layer             | Where                                     | Tool                  | Open at               |
|---|-------------------|-------------------------------------------|-----------------------|-----------------------|
| 1 | Unit              | `src/**/*.zig` inside `test "..."` blocks | `zig build test`      | Phase 0               |
| 2 | E2E (CLI)         | `test/e2e/*.sh`                           | bash + `cljw`         | Phase 2               |
| 3 | Differential      | `test/diff/`                              | `Evaluator.compare()` | Phase 4               |
| 4 | Bench (on demand) | `bench/compare_langs.sh` / `run_bench.sh` | bash + `cljw`         | on demand (not gated) |
| 5 | Conformance       | `test/clj/` (Phase 11+)                   | `clojure.test`        | Phase 11              |

## "Where does this test go?"

- **Single function, deterministic, no I/O**: Layer 1 (inline next
  to the function).
- **CLI smoke / `cljw -e '...'` works end-to-end**: Layer 2.
- **Same Clojure source must produce the same Value on both
  backends (TreeWalk + VM)**: Layer 3.
- **Performance measurement**: Layer 4 — run on demand via `bench/`
  (no longer part of the gate as of 2026-06-11).
- **Upstream Clojure JVM test (port)**: Layer 5 (Phase 11+).

## Running

```sh
bash test/run_all.sh                # all layers, every gate
zig build test                       # Layer 1 only
bash test/e2e/phase3_cli.sh          # one specific e2e
bash bench/compare_langs.sh --cold   # Layer 4: cross-language perf (on demand)
```

`test/run_all.sh` accepts `--skip <name>` / `--only <name>` /
`--list` flags (per ADR-0024 run_step pattern).

## Future layers (deferred per ADR-0021)

`test/integration/` (Phase 5+), `test/golden/` (Phase 7+),
`test/prop/` (Phase 8+), `fuzz/` (Phase 6+), `test/clj/` (Phase 11+).
These directories are created when the corresponding phase opens,
not as empty placeholders.

## Conventions

- Inline `test "..."` block name describes the user-visible
  behaviour, not the internal mechanism (`test "+ on two integers"`,
  not `test "primAdd inline call"`).
- Shell e2e exits non-zero on failure, prints a one-line summary
  including the failing case name.
- `test/diff/cases.yaml` (Phase 4 task 4.10) lists every
  differential case with a `skip_reason: null` (enabled) or text
  (skipped with reason).
