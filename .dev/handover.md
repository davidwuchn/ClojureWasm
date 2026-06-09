# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (D-356 require-closure embedding just landed +
  pushed; the ADR commit precedes the source commit). Gate: the full
  `--serial-e2e` gate was run on the D-356 source state before the source
  commit (it stamps `.dev/.gate_pass`).
- **First commit on resume MUST be**: open **D-362** (Clojure Conj 2026 CFP
  runway) — an ORDERED, user-collaborative sequence: (1) register
  `$MY/playground-v2` as `cw-playground` under the clojurewasm org; (2)
  register `$MY/serverless-v2` (bookshelf) as `cw-serverless-demo`; (3) delete
  the org's old `playground` + `edge-demo` repos; (4) deploy both to fly.io
  (user drives the dashboard, AI assists with the fly CLI + DEPLOY.md); (5) cut
  a zwasm `v2.0.0-alpha.2` tag; (6) switch `build.zig.zon` from the F-001
  relative path to that tag (url+hash — re-read F-001's amendment note first,
  this is the planned relative→tag transition); (7) polish README/CFP. Full
  row in `.dev/debt.yaml` D-362. Start with step 1 + confirm org-repo specifics
  with the user (genuine external action).
- **Forbidden**: pushing to `main`; pinning a zwasm tag UNILATERALLY (step 6 is
  an F-001-adjacent transition — confirm + log an F-001 Revision-history entry
  when taken). For the bookshelf demo build, a top-level `(-main 8080)` in
  `build_main.clj` runs at BUILD time (Clojure-AOT, ADR-0034 A1-D2) — the demo
  entry shape must avoid a build-time server-start (run-time-only entry), this
  is a demo-side concern, not a cljw gap.

## Just landed — D-356 cljw build require-closure embedding

ADR-0034 amendment 3 (DA fork → Alt-2 chunk-capture-during-load). `cljw build`
now produces a self-contained binary for a multi-file `(require '[lib])`-over-
classpath app. Part 1 = classpath prereq (`buildFile` load_paths +
`installChained` after `setupCore`; cli.zig build branch parses `-cp/-A` +
`loadDepsEdn`, mirroring the run path). Part 2 = a Layer-0 type-erased
`build_chunk_sink`; `loader.loadNamespace` compiles each filesystem lib form
AFTER eval (post-order replay) → `buildEnvelope` prepends the closure chunks
before the entry chunks. Run-time enabler = op_require idempotency. Bootstrap-ns
exclusion via `ResolvedSource.from_filesystem` (F-013-clean). Also fixed a
pre-existing serialize gap (ns_filters side-table dropped → `(ns x (:require …))`
closure chunk crashed at run); added serialize/deserialize/free + 2 round-trip
tests + format header + cljw-formats archive. e2e cases 5/6 green; transitive
a→b verified self-contained.

## Process discipline (SSOT)

- **Gate cadence**: per-commit run the fast **`--smoke <changed-e2e-step>`**
  (ADR-0107 two-tier) and **don't block** — launch it `run_in_background`, yield,
  commit+push when the stamp lands. The smoke tier authorizes shared-code commits
  too, up to 5 before a forced full gate. Batch the **full gate**
  (`bash test/run_all.sh --serial-e2e`) at the ceiling / Phase boundary /
  pre-release — backgroundable as a look-ahead. See memory
  `smoke_first_batch_full_gate`. The parallel e2e pool intermittently exceeds
  even a long timeout under host load (non-deterministic, not a hang) — use
  `--serial-e2e` for a deterministic green.
- **Linux gate is independent** (ubuntunote): `timeout 1800 bash
  scripts/run_remote_ubuntu.sh` against a pushed HEAD.
- Demo binary is `cljw-wasm` (separate from the gate's `cljw`); rebuild before
  any playground run.

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-362** = next, CFP runway; D-356 DISCHARGED) →
`.dev/decisions/0034_cljw_build_single_mode_tier0_metadata_edn_decode.md`
(amendment 3 = the require-closure embedding model) →
`private/notes/D356-require-closure-embedding.md` (the session note + residual)
→ CLAUDE.md.
