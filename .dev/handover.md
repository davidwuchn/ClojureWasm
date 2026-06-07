# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. Newest = **bench: import cw v0 suite** + the overnight
  Conj edge demo (edge-demo repo, pushed) + cljw http `:headers` / catchable file
  I/O (cw-from-scratch, pushed).
- **First commit on resume MUST be: STREAM 1 — CLI alignment to clj 本家**, then
  STREAM 2 (finish the benchmark suite). The full plan + the EMPIRICAL CLI
  comparison table (already measured — do NOT re-probe) + the bench state live in
  **`private/notes/cli-and-bench-handoff.md`** (read it FIRST). In order:
  1. file/stdin runs must NOT echo top-level values (clj + v0 both echo for `-e`
     only). `src/app/cli.zig:310` passes `print_results=true` for both — thread a
     `from_eval` flag so file/stdin → false. Audit the bare-file e2e (chiefly
     `phase14_with_context.sh`). This also unblocks the bench oracle + cleans demos.
  2. add `--version` (auto-derive from `build.zig.zon .version` via a build_option —
     v0 pattern: v0 `build.zig:18` + `cli.zig:105`). Do NOT invent a version string.
  3. `--help` version banner; 4. no-args → REPL (clj-compat). Items 1-4 = one
     `feat(cli): align to clj 本家` direction (TDD + gate + Smell-audited + push).
  5. error-format (clj `Execution error (<Class>)` vs v1 `<loc>: <kind> [phase]`) is
     the one interactive product call (AD-007 no-JVM Kind) — the user is driving it;
     land 1-4 + bench, surface item 5's options to the user.
- **Then STREAM 2 — benchmarks**: cw v0's suite is COPIED + committed into `bench/`
  (benchmarks/ 31 + simd/ + wasm/ + run_bench.sh / compare_langs.sh / build_bench.sh
  / wasm_bench.sh). After fix #1 the oracle passes (run_bench.sh head-1 = result).
  Remaining: run it; add the nix flake bench toolchain (ref v0 `flake.nix:49-91`:
  wasmtime/clojure/jdk/babashka/python/ruby/nodejs/tinygo/jq); run `compare_langs.sh
  --yaml`; GENERATE a readable Markdown table (not hand-maintained) into
  `bench/README.md` + link from the main README. Detail: `cli-and-bench-handoff.md`
  + `private/notes/v0-bench-survey.md`. v1's gate bench infra (quick.sh/record.sh/
  history.yaml/perf.sh) is UNTOUCHED.
- **Forbidden**: inventing a `--version` string (the user owns the tag, v0.6.0 per
  DEFERRED_USER_ACTIONS); fly.io CLI / Sessionize / token / edge-demo-prod actions
  beyond what the user asks; editing `.claude/rules/*` (permission-blocked → surface
  as carry-over); the naive D-308 `satisfies?`-rewrite; pinning a zwasm v2 tag
  (F-001); trusting `~/Documents/OSS/zig`.

## Just landed (2026-06-08, git log = SSOT)

- **Conj edge demo** (edge-demo repo, pushed to clojurewasm/edge-demo): "Shelf"
  bookshelf CRUD (sessions/htmx/EDN store/Fly volume) + Playground + Zig→Wasm cover
  showcase + smoke.sh; deploy artifact stripped musl 2.76MB. cljw side (pushed):
  response `:headers`, catchable slurp/spit (io_error→IOException), instance? SSOT
  (ADR-0116/D-308), D-316, 3 clj-diff corpus sweeps. zwasm musl gap + component-model
  fed back (`private/notes/zwasm_v2_handoff_2026-06-08.md`).
- **bench: import cw v0 suite** (this commit) — raw copy, adaptation pending per
  STREAM 2.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `bash scripts/run_gate.sh` or `timeout 1800 bash test/run_all.sh
  --serial-e2e`. Doc-only / bench-data-only / corpus-only = no gate (additive). Never
  poll a bg gate. New e2e MUST register in run_all.sh.
- cljw -e of `(prn X)` echoes X then nil — e2e use BARE exprs, not `(prn …)|tail -1`.
  Edit/Write TRANSCODES non-ASCII (splice via python). handover.md edits: framing
  hook blocks a forbidden phrase — fix via Bash sed/python. Backend default = vm
  (F-012, build.zig:37). Measure speed ONLY via the bench harness / scripts/perf.sh
  (ReleaseSafe/Fast), never the Debug zig-out binary.

## Cold-start reading order (tracked-only)

handover → **`private/notes/cli-and-bench-handoff.md`** (the active plan + measured
CLI table) → `private/notes/v0-bench-survey.md` (bench) → `src/app/cli.zig` +
`src/app/runner.zig` + v0 `build.zig`/`cli.zig` (version-derive ref) →
`.dev/accepted_divergences.yaml` (AD-007, before error-format) → CLAUDE.md
(§ Project spirit + The only stop) → `.dev/principle.md`.
