# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. This session: Campaign **Stage 0 DONE** (5 SSOTs) +
  **Stage 1.1 DONE** (var-as-IFn, D-231) + **Stage 1.2 DONE** (full deps.edn:
  `:paths`/`:local/root`/`:aliases`/`:git/url`, 5 slices + ADR-0101 + DA fork,
  cw's first subprocess) + **Stage 1.3 engine running** (D-275 found + surveyed).
- **First commit on resume MUST be**: **D-275 slice 1** — `deftype`/`reify`
  host-supertype recognition + `Object/toString`→print. SPEC =
  `private/notes/stage1.3-deftype-object-survey.md`. name_error origin
  `analyzer.zig:559`; fix = **Path A** (quote-wrap the recognised marker head in
  `expandReify`/`expandExtendType` like the `instance?` precedent
  `macro_transforms.zig:2854`, so the analyzer never Var-resolves `Object`), then
  `strValue` consults `dispatchOrNull(v,"Object","-toString")` (the pattern
  `print.zig` uses for `Seqable/-seq`). Recognize-but-don't-wire = a forbidden
  silent no-op, so each recognised method wires to real dispatch. Decomposed:
  slice 1 Object/toString → slice 2 equals/hashCode → slice 3+ `clojure.lang.*`
  (IDeref etc.). Then Stage 1 continues: 1.4 native cider ops → 1.5 v0→v1
  bundled-lib backfill (D-273) → 1.6 clj-parity → **1.7 Phase B HARDENING (D-242 —
  concurrency IMPLEMENTED, torture/perf residuals not construction)** → Final
  Stage wiring audit. The campaign (`.dev/convergence_campaign.md`) is the SSOT.
- **⚠ USER must act (time-sensitive, NOT AI-doable)**: see
  `private/clojure_conj_2026_cfp/DEFERRED_USER_ACTIONS.md` — (1) Sessionize submit
  by 6/13 (`SUBMIT_READY.md` copy-paste ready); (2) v0.1.0 tag/Release + make
  `cw-from-scratch` the default branch; (3) edge-demo CRUD `git push` + `fly deploy`.
- **Forbidden**: the 3 USER actions above (credential / product decisions — the
  safety layer blocks them); editing `.claude/rules/*` (permission-blocked →
  surface); pinning an in-progress zwasm v2 state / tag (F-001: v2 ONLY from
  `zwasm-from-scratch`); trusting `~/Documents/OSS/zig`.

## Just landed (2026-06-06, git log = SSOT)

- **Stage 0** (5 SSOTs rebuilt): parity `v0_v1_feature_parity.md` + D-273;
  `compat_tiers.yaml` +31A/+3C Java reservations; debt de-stale −5; `docs/works/`
  ladder. **DISCOVERY (0.4): Phase B concurrency IMPLEMENTED at HEAD** (landed
  2026-06-05 before the campaign was written) — discharged D-009/010/012/013/211,
  D-242 re-scoped to hardening, handover's "open Phase B" was stale.
- **Stage 1.1** (D-231): var-as-IFn — `((resolve 'f) args)`/`(#'f args)` work
  (a `.var_ref` arm in the shared `treeWalkCall`, both backends). The literal
  premise (resolve→nil) was stale-fixed; Step-0.6 pivot to the real gap.
- **Stage 1.2** (5 slices + ADR-0101): deps.edn fully resolves into the
  classpath. git fetch = cw's first subprocess (`std.process.run` only in
  `git_fetch.zig`), content-addressed `$CLJW_HOME/gitlibs/<repo>/<full-sha>`,
  rev-parse verified, hermetic `file://` e2e. Maven rejected (source-only).
- **Stage 1.3 engine**: loaded `clojure.data.priority-map` via a deps.edn git
  coordinate (git fetch + transitive classpath worked end-to-end) → first real
  blocker **D-275** (deftype/reify `Object` impl-spec unresolved) + surveyed.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min;
  -P8 over-runs under load). Doc-only = no gate. Never poll a bg gate.
- A clj-diff probe runs many `cljw` processes — **never sweep concurrently with a
  running gate** (contends with the perf-threshold steps → false failures).
- clj-diff harness = `scripts/clj_diff_sweep.sh exprs --corpus <area>`; for
  classification, probe **per-expr** (cljw vs clj individually) — a batch desyncs
  when one expr is a clj READ error (e.g. `08`, `nan?`, a non-required
  `clojure.set/…`). `clj -M -e` → `timeout 20` + bound infinite seqs.
- Speed ONLY via `scripts/perf.sh` (never time Debug). Edit/Write TRANSCODES
  literal non-ASCII (keep source ASCII; splice non-ASCII via python). Default
  backend = VM (F-012).

## Cold-start reading order (tracked-only)

handover → **`.dev/convergence_campaign.md`** (the driving SSOT/procedure) →
`.dev/v0_v1_feature_parity.md` (D-273 backfill list) + `.dev/debt.yaml` (133
active) + `compat_tiers.yaml` (Java tier scope) + `docs/works/ladder.md` →
ADR-0090/0089 (Phase B — IMPLEMENTED, Stage 1.7 = hardening) →
`.dev/project_facts.md` F-004/F-006 → CLAUDE.md (§ Project spirit + The only
stop) → `.dev/principle.md`.
