# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `5e633a27` (clean tree, all pushed). This session landed
  D-144 (user-throw EDN), D-134 (b) range 3-arg, D-145 (`fn` macro),
  D-146 (`#()` reader macro), and drove the **interop cycle's full design
  phase** (survey + Step 0.6 + mandatory DA) — Alt 2 is LOCKED.
- **First commit on resume MUST be**: the **interop `.instance_member`
  implementation (Alt 2)** — the design is locked, do NOT re-survey /
  re-DA. Read `private/notes/interop-DA-alt2.md` (the locked decision +
  the DA output to lift VERBATIM into the ADR). Order: (1) **ADR-0050
  amendment** (Accepted; Decision = collapse `.instance_field` +
  `.instance_method` → one `.instance_member` kind + `field_only` flag;
  ONE receiver-keyed resolver per backend; **field-first keyed on
  `field_layout` presence**; retire `op_field_access`) — depth-2 doc
  commit first. (2) Source: `node.zig` Kind→3, `analyzer.zig` 2 arms,
  TreeWalk `evalInstanceMember`, VM converge onto `op_method_call`,
  `runtime/java/lang/String.zig` + `installNativeMethods(rt)` populating
  the `.string` `method_table` (per-Runtime lazy — NOT System.zig's
  static pattern), diff cases, e2e (`(.toUpperCase "hi")` / `(.x
  deftype)`). (3) Verify NO deftype `(.field rec)` regression. This fixes
  the verified TreeWalk gaps: `(.toUpperCase "hi")` (instance method
  mis-routed to field) + opens `Math/abs` (Q1 short-name reg, follow-on).
- **Forbidden this session**: re-opening D-144/range/D-145/D-146 (DONE).
  Re-surveying or re-DA'ing interop (design LOCKED — Alt 2). Adopting
  **method-then-field** ordering (DA: use field-first keyed on
  `field_layout`, else a protocol-method-named-like-a-field silently
  shadows it). Flipping `phase_at_least_14` / tagging v0.1.0 (HELD).
  Treating §9.16 `[ ]` 14.12 / 14.14 as the next task.

## Current state

Phase 14 v0.1.0 substantive work DONE; release HELD. Mac gate **109/109**
green (`/tmp/gate_anon.log` @cac24171; handover-only commit since). Coverage
floor advancing fast: `(fn …)`, `#(…)`, `(range start end step)`,
structured user-throw EDN landed this session. cw v1 ≈ 60-70% of cw v0
surface in ~half the LOC; error UX + `--compare`/`render-error` exceed v0.
F-010-ordered gaps (JIT / nREPL / line-editor / Wasm-Component / deps)
deferred (§A26).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

§A26: **interop coverage** (implementation next, design locked) → **Phase
15** (concurrency; unblocks D-117/D-118 nREPL) → superinstruction/fusion →
narrow ARM64 JIT (D-133) → **M** → quality-elevation loop (`docs/works/`).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-130** interop `.static_method` VM arm (rides or follows the Alt 2
  cycle). **D-147** `fn*` self-name slot (dual-backend; from D-145).
  **D-076** destructuring (`let`/`fn*`/`fn`). **D-134** clojure.core —
  only `partition` 4-arg pad + comp/juxt multi-arity left. **D-143**
  apply multi-arity spread. **D-142** Env-scope `*error-context*`
  (multi-Env nREPL). **D-141** bench multi-lock anchor. **D-105/D-106**
  time/net+crypto. **D-116** line-editor. **D-117/D-118** nREPL richness
  (Phase-15-gated). **D-075** metadata. **D-133** JIT floor.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ `private/notes/interop-DA-alt2.md` (LOCKED design + DA verbatim) +
`private/notes/interop-coverage-survey.md` → `.dev/decisions/0050*`
(InteropCallNode) + `src/eval/analyzer/analyzer.zig` (~478-491) +
`src/eval/backend/{tree_walk,vm/compiler,vm}.zig` interop arms →
`src/runtime/runtime.zig` (~162 nativeDescriptor) → ROADMAP §9.17.
