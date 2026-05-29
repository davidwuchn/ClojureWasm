# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `cac24171` (clean tree, all pushed). This session landed
  D-144 (user-throw EDN), D-134 (b) range 3-arg, D-145 (`fn` macro),
  D-146 (`#()` reader macro) — see `git log`.
- **First commit on resume MUST be**: the **interop coverage cycle**
  (§A26 ordering: fn → #() → interop). **Survey-first** — the scope is
  broader than the D-130 row suggests. Verified 2026-05-29: interop
  SYNTAX landed (ADR-0050 `InteropCallNode`, TreeWalk) but common forms
  FAIL even in TreeWalk: `(Math/abs -5)` → "No namespace: 'Math'"
  (static-method symbol `Class/method` not routed to interop / `Math`
  not a registered host class); `(.toUpperCase "hi")` → "field access:
  expected number, got string" (instance-method `.name` mis-dispatched
  to instance-FIELD). **Step 0 survey**: how `InteropCallNode` kinds
  (.static_method / .instance_method / .instance_field / .constructor)
  are analysed + dispatched (`src/eval/analyzer/` + both backends +
  `runtime/error/host_class.zig` + `compat_tiers.yaml` host_classes),
  which host classes are registered, JVM `.`/`Class/method`/`new`
  semantics. Pick the highest-corpus-impact concrete gap to land first
  (likely static `Class/method` resolution + instance method-vs-field
  disambiguation in TreeWalk, the production default); **D-130** (the VM
  `.static_method` bytecode arm, ~150 LOC, dual-backend parity) folds in.
  Likely depth ≥ 2 (analyzer + dual-backend) → Devil's-advocate fork.
- **Forbidden this session**: re-opening D-144 / range 3-arg / D-145 `fn`
  / D-146 `#()` (DONE). Re-attempting "lazy-seq Layer-2 wiring" (closed,
  ADR-0054). Treating D-130 as a NARROW VM-only task — TreeWalk interop
  is itself incomplete (verified above). Flipping `phase_at_least_14` /
  tagging v0.1.0 (release HELD). Treating §9.16 `[ ]` 14.12 / 14.14 as
  the next task.

## Current state

Phase 14 v0.1.0 substantive work DONE; release HELD. Mac gate **109/109**
green (`/tmp/gate_anon.log` @cac24171). Coverage floor advancing fast:
`(fn …)`, `#(…)`, `(range start end step)`, structured user-throw EDN all
landed this session. cw v1 ≈ 60-70% of cw v0 surface in ~half the LOC;
error UX + `--compare`/`render-error` exceed v0. F-010-ordered gaps (JIT /
nREPL-richness / line-editor / Wasm-Component / deps-test) deferred (§A26).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

§A26 ordering: **interop coverage** (next) → **Phase 15** (concurrency;
unblocks D-117/D-118 nREPL richness) → superinstruction/fusion → narrow
ARM64 JIT (D-133) → **M** → quality-elevation loop (`docs/works/`).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-130** interop `.static_method` VM arm (+ broader TreeWalk interop
  gap, next cycle). **D-147** `fn*` self-name slot (dual-backend; from
  D-145). **D-076** destructuring (`let`/`fn*`/`fn` params). **D-134**
  clojure.core — only `partition` 4-arg pad + comp/juxt multi-arity left.
  **D-143** apply multi-arity spread. **D-142** Env-scope `*error-context*`
  (multi-Env nREPL). **D-141** bench multi-lock anchor. **D-105/D-106**
  time/net+crypto. **D-116** line-editor. **D-117/D-118** nREPL richness
  (Phase-15-gated). **D-075** metadata. **D-133** JIT floor.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ `.dev/cw_v0_parity_and_gap_plan.md` §2 + ordering note → `.dev/debt.md`
D-130 → `.dev/decisions/0050*` (InteropCallNode) + `src/eval/analyzer/`
interop + `runtime/error/host_class.zig` + `compat_tiers.yaml` →
ROADMAP §9.17 (Phase 15).
