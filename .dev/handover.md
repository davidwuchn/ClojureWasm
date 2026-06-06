# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. This session landed: the **F-013 + ADR-0102 structural
  framework** (the 個別最適化-entry close: `host_interfaces.yaml` closed-set SSOT +
  `src/runtime/host_interface.zig` single read point + G4 `check_host_interface.sh`
  gate w/ set-bound + route-soundness) + **D-275/D-279/D-280 — the ENTIRE
  `clojure.lang.*` deftype/reify host-supertype family modeled & proven**
  (Object toString/equals/hashCode/hasheq/equiv, ILookup, IPersistentMap
  multi-target, IPersistentStack, IHashEq, IFn, IObj, Reversible, Sorted, markers +
  method arity-overload). D-280e: the real `(require 'clojure.data.priority-map)`
  now advances 266→374 (past all clojure.lang.*).
- **First commit on resume MUST be**: **D-282** — ship the bundled
  `clojure.core.protocols` ns (CollReduce / IKVReduce / Datafiable / Navigable) under
  `src/lang/clj/clojure/`, wiring its protocol methods to cljw's reduce / kv-reduce
  surface (`-reduce` exists). It is ABSENT today (`require` → "Could not locate"); it
  is the gating blocker for priority-map's `clojure.core.protocols/IKVReduce` AND for
  reducers/datafy libs broadly (high reuse — F-013). Once it exists, IKVReduce
  resolves through the ordinary protocol-Var path (no host-interface remap). Sibling
  blocker **D-281** (priority-map's `java.util.Map`/`java.lang.Iterable` deftype
  supertypes — a java host-interface family via the same ADR-0102 mechanism; java.util.Map
  methods are no-JVM-inert per ADR-0059). Then Stage 1 continues: 1.4 native cider ops →
  1.5 v0→v1 backfill (D-273) → 1.6 clj-parity → 1.7 Phase B hardening (D-242). The
  campaign (`.dev/convergence_campaign.md`) is the SSOT. FUNCTIONAL follow-up cluster
  (post-load): IFn call-path, meta/with-meta consult, find/-entry-at, subseq/Sorted-nav,
  cross-type equiv (D-280d8).
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
- **D-275 → D-280 (a/b/c + d1/d1b/d2/d3/d4/d5/d6/d7/d8) + D-279**: the whole
  `clojure.lang.*` deftype/reify host-supertype family is modeled via that
  mechanism (macro rewrite to bare cljw protocol sections + Object method-family
  + multi-arity), gate-green throughout, and PROVEN end-to-end — the real
  priority-map `(require)` advances 266→374. 23 e2e cases (phase14_deftype_object).

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
