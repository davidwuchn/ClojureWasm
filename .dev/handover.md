# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (D-356 require-closure embedding + D-363 `cljw build
  -m` main mode both landed + pushed; each ADR commit precedes its source
  commit). Gate: the full `--serial-e2e` gate is run on each source state before
  its commit (it stamps `.dev/.gate_pass`).
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
  with the user (genuine external action). The bookshelf demo now builds via
  `cljw build -A:cljw -m bookshelf.server -o bookshelf` (D-363 -m mode — the
  server `-main` runs at RUN, not build).
- **Forbidden**: pushing to `main`; pinning a zwasm tag UNILATERALLY (step 6 is
  an F-001-adjacent transition — confirm + log an F-001 Revision-history entry
  when taken).

## Just landed — D-363 cljw build -m main-entry mode

ADR-0034 amendment 4 (DA fork → Alt-2 entry-manifest). `cljw build -m <ns>
[args] -o out` embeds the require closure for `<ns>` + an entry manifest at the
payload front (artifact metadata, ELF-`e_entry`-style); the binary invokes
`(<ns>/-main args)` at RUN, NOT build — so a server `-main` no longer hangs the
build (resolves the D-356 residual as a real cljw feature). Run-side routes
through the shared `run_mode.synthMainNs` (pub) so the built `-m` binary is
byte-identical to `cljw -M -m` (F-011); the binary's runtime argv reaches
`-main` (`./out 8080`). serialize.zig: envelope manifest (writeManifest/
skipManifest/readEnvelopeEntry; deserialize+iterator skip it → runEnvelope
unchanged). builder: buildMainEnvelope + buildArtifact(BuildSpec). Build stays
Clojure-AOT-faithful (build=load); `-main` is the "don't run at build" escape
hatch (no env-vs-side-effect classifier; cw v0 build_mode rejected, F-013). e2e
cases 7-11 green (incl. A4-D4: deps.edn `:main-opts ["-m" ns]` on a selected
alias drives the build entry — `cljw build -A:run` mirrors `cljw -M:run`; e2e
main_opts_drive). Script mode (D-356) unchanged.

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

handover → `.dev/debt.yaml` (**D-362** = next, CFP runway; D-356 + D-363
DISCHARGED) →
`.dev/decisions/0034_cljw_build_single_mode_tier0_metadata_edn_decode.md`
(amendment 3 = require-closure embedding; amendment 4 = `-m` main mode) →
`private/notes/D363-cljw-build-main-mode.md` + `…D356-require-closure-embedding.md`
(session notes + residuals) → CLAUDE.md.
