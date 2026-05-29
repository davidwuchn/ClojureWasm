# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `1d393882` (clean tree, all pushed). This session landed
  D-144 (user-throw EDN), D-134 (b) range 3-arg, D-145 (`fn` macro),
  D-146 (`#()` reader macro), and **ADR-0050 amendment 1** (interop
  `.instance_member` design — Alt 2, LOCKED + DA recorded in the ADR).
- **First commit on resume MUST be**: the **interop `.instance_member`
  SOURCE implementation** per **ADR-0050 amendment 1** (authoritative —
  read `.dev/decisions/0050_unified_interop_call_node.md` § Amendment 1
  for the full locked decision + DA + the 3 caveats + the implementation
  order; do NOT re-survey / re-DA — design is locked). ONE atomic source
  commit (the parity hook + exhaustive switch force it): `node.zig`
  `InteropCallNode.Kind` → 3 + `field_only`; `analyzer.zig` collapse the
  dot arms + add `.-` arm; TreeWalk `evalInstanceMember`; VM converge onto
  `op_method_call` + retire `op_field_access`; `runtime.zig`
  `installNativeMethods(rt)` + `runtime/java/lang/String.zig` populating
  the `.string` `method_table`; diff cases; e2e (`(.toUpperCase "hi")` /
  `(.x deftype)`). Then VERIFY no deftype `(.field rec)` regression
  (gate + targeted e2e). Fixes the verified TreeWalk gaps Q1 (`Math/abs`
  → follow-on) + Q2 (`.toUpperCase` mis-routed to field).
- **Forbidden this session**: re-opening D-144/range/D-145/D-146 (DONE).
  Re-surveying or re-DA'ing interop (LOCKED — ADR-0050 am1). Adopting
  **method-then-field** ordering (use FIELD-FIRST keyed on `field_layout`
  presence — else a protocol method named like a field silently shadows
  it). Re-attempting "lazy-seq Layer-2 wiring" (closed, ADR-0054).
  Flipping `phase_at_least_14` / tagging v0.1.0 (release HELD). Treating
  §9.16 `[ ]` 14.12 (deferred, F-010) / 14.14 (release, held) as the next
  task — the next task is the interop SOURCE above, NOT the §9 first-`[ ]`
  scan.

## Current state

Phase 14 v0.1.0 substantive work DONE; release HELD. Mac gate **109/109**
green (`/tmp/gate_anon.log` @cac24171; doc-only commits since — build
re-verified clean @1d393882). Coverage floor advancing: `(fn …)`, `#(…)`,
`(range start end step)`, structured user-throw EDN landed this session.
cw v1 ≈ 60-70% of cw v0 surface in ~half the LOC; error UX +
`--compare`/`render-error` exceed v0. F-010-ordered gaps (JIT / nREPL /
line-editor / Wasm-Component / deps) deferred (§A26).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

§A26: **interop coverage** (source impl next; design locked) → **Phase 15**
(concurrency; unblocks D-117/D-118 nREPL) → superinstruction/fusion →
narrow ARM64 JIT (D-133) → **M** → quality-elevation loop (`docs/works/`).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-130** interop `.static_method` VM arm (rides or follows the Alt 2
  cycle). **D-147** `fn*` self-name slot (dual-backend; from D-145).
  **D-076** destructuring (`let`/`fn*`/`fn`). **D-134** clojure.core —
  only `partition` 4-arg pad + comp/juxt multi-arity left. **D-143** apply
  multi-arity spread. **D-142** Env-scope `*error-context*` (multi-Env
  nREPL). **D-141** bench multi-lock anchor. **D-105/D-106** time/net+
  crypto. **D-116** line-editor. **D-117/D-118** nREPL richness (Phase-15-
  gated). **D-075** metadata. **D-133** JIT floor.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ `.dev/decisions/0050_unified_interop_call_node.md` § Amendment 1
(AUTHORITATIVE locked design + DA) → `src/eval/analyzer/analyzer.zig`
(~478-491) + `src/eval/backend/{tree_walk,vm/compiler,vm}.zig` interop
arms + `src/runtime/runtime.zig` (~162 nativeDescriptor) → ROADMAP §9.17.
