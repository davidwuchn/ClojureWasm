# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. This session built the **deftype/reify host-interface
  capability end-to-end** and drove `clojure.data.priority-map` from name_error to
  **FULLY FUNCTIONAL** (ladder rung 4): F-013 + ADR-0102/0103 (closed-set
  `host_interfaces.yaml` SSOT + `host_interface.zig` single read point + G4 gate =
  the 個別最適化-entry structural close) · D-275/D-279/D-280 (the whole clojure.lang.*
  family + arity-overload + IFn-call-path + IObj-meta consults) · D-281 (java.util.Map/
  Iterable host_inert) · D-282 (clojure.core.protocols ns) · D-283 (clj-name `.method`
  dot-calls) · D-284 (`(MapEntry. …)`→2-vec) · D-285 (keys/vals seq-derivation).
  `(priority-map :a 3 :b 1 :c 2)` → peek=[:b 1], count=3, keys=(:b :c :a).
- **First commit on resume MUST be**: continue the **Stage 1.3 ladder breadth-probe**
  — probe `clojure.data.generators` (rung 5) via `-cp` on
  `~/Documents/OSS/clojure-corpus/01_clojure_official/clojure__data.generators/src`,
  record its first blocker as a debt row (campaign Stage 1.3 loop). The deftype
  host-interface capability (D-275→D-286a) is COMPLETE + proven (priority-map fully
  functional; ordered cleared all its supertypes), so the open deftype gaps below
  are drive-when-needed, not the forced next task. Then Stage 1: 1.4 native cider
  ops → 1.5 v0→v1 backfill (D-273) → 1.6 clj-parity → 1.7 Phase B hardening (D-242).
  SSOT = `.dev/convergence_campaign.md`.
- **Scoped gaps the ladder probes surfaced** (drive when a target needs them):
  D-286b (bare names that ARE cljw Vars — IPersistentSet/IPersistentMap with
  clj-named methods — bypass protocol_remap; needs method-name disambiguation;
  completes ordered's supertypes) · D-287 (Java arrays: aset/aget/make-array —
  ordered's backing store; ADR-level repr choice) · D-288 (deftype mutable fields
  `^:unsynchronized-mutable` + set! — tools.reader; ADR-level) · the deftype
  FUNCTIONAL residuals: cross-type `(= deftype-map native-map)` (D-280d8) ·
  find/`-entry-at` · subseq/Sorted-nav · reduce-kv→IKVReduce wiring · reify
  protocol_remap (expandReify lacks the rewriteProtocolRemap path).
- **⚠ USER must act (time-sensitive, NOT AI-doable)**: see
  `private/clojure_conj_2026_cfp/DEFERRED_USER_ACTIONS.md` — (1) Sessionize submit
  by 6/13 (`SUBMIT_READY.md` copy-paste ready); (2) v0.1.0 tag/Release + make
  `cw-from-scratch` the default branch; (3) edge-demo CRUD `git push` + `fly deploy`.
- **Forbidden**: the 3 USER actions above (credential / product decisions — the
  safety layer blocks them); editing `.claude/rules/*` (permission-blocked →
  surface); pinning an in-progress zwasm v2 state / tag (F-001: v2 ONLY from
  `zwasm-from-scratch`); trusting `~/Documents/OSS/zig`.

## Just landed (2026-06-07, git log = SSOT)

- **F-013 + ADR-0102** institutionalised the user's directive: library-driven
  discovery surfaces gaps; the response is definition-derived comprehensive
  coverage (網羅) in canonical Zig-equivalent (non-JVM) form, NOT ad-hoc
  "make this lib pass". The 個別最適化 entry is closed structurally — a closed-set
  SSOT (`host_interfaces.yaml`) + a single read point + a G4 gate (set-bound +
  route-soundness), not vigilance.
- **D-275 → D-285** (+ D-279, ADR-0103): the whole deftype/reify host-interface
  stack — clojure.lang.* family (macro rewrite to bare cljw protocol sections +
  Object method-family + arity-overload + IFn-call-path + IObj-meta), java.util.*
  host_inert, clojure.core.protocols ns, clj-name dot-calls, MapEntry ctor,
  keys/vals seq-derivation — gate-green throughout. PROVEN end-to-end: real
  `clojure.data.priority-map` is **FULLY FUNCTIONAL** (peek/count/keys/vals/assoc).
  30 e2e cases (phase14_deftype_object).

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

## Stopped — user requested

User instruction (2026-06-07): 「コンテキストウィンドウ増大につき、クリア
セッションからcontinueできる形で配線確認しておいて」 / 「終わったら、止めて」.
Working tree clean, all work pushed to `origin/cw-from-scratch`. Resume with
`/continue` per the Resume contract above (probe rung 5 clojure.data.generators).
The directive applied to that session only; the next `/continue` resumes the loop
normally and deletes this section (handover_framing).
