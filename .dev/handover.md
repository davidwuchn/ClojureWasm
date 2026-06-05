# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ~`a05e3785` (see git log — CFP P1-P5 landed + P6 packaged). Active
  plan = ADR-0089 (A->B->C); the CFP campaign (D-256) is mid-flight ahead of it.
- **First commit on resume MUST be**: **D-257 — `cljw.http.server` request
  `:headers` + `:body`** (drain the request body; today the Ring map is
  `:request-method`/`:uri` only). This is the cljw-side enabler for the LIVE
  edge-demo's CRUD (CFP P8). Source-bearing → cljw gate applies. Entry: ADR-0098
  + D-257 row (the std.http.Server `discardBody` keep-alive caveat is in D-257).
- **Forbidden**: re-doing CFP P0-P6 (done/packaged — git log + below); publishing
  the CFP submission OR the v0.1.0 tag / GitHub Release / default-branch change
  (ALL user-owned — see `private/clojure_conj_2026_cfp/SUBMIT_READY.md` +
  `…/P3_DEFERRED_and_metrics.md`); pinning an in-progress zwasm v2 state / a
  zwasm tag or v1 (F-001: v2 ONLY from `zwasm-from-scratch`; wasm findings =
  zwasm-side feedback-note no-code, cljw-side real fix); turning auto-collect ON
  (user-owned #4a'); editing .claude/rules/* (permission-blocked → surface);
  trusting ~/Documents/OSS/zig for 0.16.

## CFP campaign (D-256) — status

P0-P5 DONE + P6 PACKAGED this overnight (git log = SSOT):
- **P1** polyglot wasm FFI: `wasm/load`+`wasm/call` behind `-Dwasm` (ADR-0099),
  `cljw examples/wasm/add.clj` → 42. Provisional handle = D-259 (Phase-16/F-004).
- **P2** README/quickstart/LICENSE(EPL-2.0)/CONTRIBUTING + ARCHITECTURE refresh.
- **P4** binary size locked (bench/RELEASE_METRICS.md: ReleaseSafe ~2.2MB / floor
  ~1.1MB / ~5ms cold start). **P5** docs/landscape.md (respectful map).
- **P6** SUBMIT_READY.md = copy-paste title/abstract/reviewer-note, pivot-
  reconciled (Fly+native, honest numbers, branch URLs).
- **Deferred (USER actions, never AI)**: (1) Sessionize submit by 6/13 —
  SUBMIT_READY.md checklist; (2) v0.1.0 tag + Release + make `cw-from-scratch` the
  default branch — P3_DEFERRED (v0.1.0 tag COLLIDES with old v1 lineage; version
  decision is the user's; recommend v0.6.0).
- **Next AI-doable (CFP P7-P10 reframed by the 2026-06-06 PIVOT)**: P8 edge-demo
  CRUD (needs D-257, the resume task) → P9 more polyglot examples → P10
  getting-started/tier guide. P7 browser Playground (cljw→wasm32) stays deferred
  (3 blockers). After CFP packaging exhausts, transition to cljw Phase B/C.

## Active plan — ADR-0089 post-M re-cut (2026-06-04)

```
Phase B  KNOWN-unimplemented CORE, concurrency-led (D-242): §7 redesign vs Zig
         0.16 FIRST, then STM-txn / agent / locking / real-threading / Thread +
         arrays (F-004) / *out*·in·err (D-238) / reflection. finished-form,
         rework-OK with test guards. North star = user-observable parity.
Phase C  Library-driven gap-hunt; workaround remediation folds in here.
```

## Open carry-overs (actionable)

- **D-260** (found this overnight): `*'` raises integer_overflow instead of
  auto-promoting (`+'` is correct) — clj-parity bug, fold into Phase C.
- **D-257** = the resume task (edge-demo CRUD enabler). **D-259** = the wasm FFI
  provisional handle (Phase-16/F-004). **D-258** = dormant multi-thread torture
  flake (D-244 #4).
- **3 rules** carry a stale `src/runtime/host/**` glob (ADR-0029); cleanup Edit is
  permission-blocked as self-mod (memory `claude-rules-edit-permission-block`).
- **D-243** (8 re-opened deferrals) · **D-244** #4a' hardening capstone (auto-
  collect dormant) · **D-245** locking Option C · **D-246** concurrency metadata.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source work only): `timeout 1800 bash test/run_all.sh --serial-e2e`
  (~5min; -P8 over-runs under load). Doc-only = no gate.
- Never poll a bg gate. `clj -M -e` → `timeout 20` + bound infinite seqs. Speed
  ONLY via `scripts/perf.sh` (ReleaseSafe shipped; never time Debug). Edit/Write
  TRANSCODES literal non-ASCII (keep source ASCII; splice non-ASCII via python).
  Default backend = VM (F-012).

## Cold-start reading order (tracked-only)

handover → **`private/clojure_conj_2026_cfp/SUBMIT_READY.md` + `…/PRIORITY.md`**
(CFP state) → `.dev/debt.yaml` D-257/259/260 → **`.dev/decisions/0098_*`**
(http.server, the D-257 base) + **`0099_*`** (wasm FFI) → `.dev/project_facts.md`
F-001/F-004/F-006/F-011 → CLAUDE.md (§ Project spirit + The only stop) →
`.dev/principle.md`.
