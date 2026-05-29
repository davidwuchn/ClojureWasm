# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `c1ebe0c5` (clean tree, all pushed). Last two landings: interop
  `.instance_member` unified dispatch + native String methods (129309be,
  ADR-0050 am1); `java.lang.Math` static methods + `java.lang.*` auto-import
  resolution (c1ebe0c5, §A26 q1 — bare `Math/abs`/`System/…` resolve via
  `resolveJavaSurface` 3rd attempt `cljw.java.lang.<head>`). Mac gate 111/111.
- **First commit on resume MUST be**: **D-130 — the `.static_method` VM
  compile arm**. Today `vm/compiler.zig` `compileInteropCall .static_method`
  is `return error.NotImplemented` (VM-DEFER), so static dispatch is
  TreeWalk-only and static interop has NO differential-oracle coverage. The
  TreeWalk reference is `tree_walk.zig evalStaticMethodCall` (descriptor baked
  at analyze time in `n.descriptor`; `lookupMethod(null, name)` → `callFn`
  with user args, no receiver). **Bytecode-shape decision is ADR-level**
  (single `op_interop_call` with a kind operand vs a sibling
  `op_static_method_call`) — handle INLINE: Step 0 survey + Step 0.6, draft
  the ADR `Proposed→Accepted` with the mandatory DA fork (depth ≥ 2), then
  implement the arm + VM dispatch + remove the VM-DEFER marker + add the now-
  possible static-method diff_test cases (e.g. `(Math/max 3 7)` → 7) + close
  D-130. Per ADR-0050 base: `.static_method` carries an analyze-time
  descriptor pointer — the VM needs that pointer in a chunk side-table (the
  `call_sites`-style pattern) since a raw pointer can't sit in the u16 operand.
- **Forbidden this session**: re-opening the `.instance_member` work (DONE
  @129309be) or the Math/auto-import work (DONE @c1ebe0c5). Re-surveying /
  re-DA'ing the interop *dispatch* shape (LOCKED — ADR-0050 am1; D-130 is only
  the VM *bytecode* shape, a separate decision). Adopting method-then-field
  ordering (field-first keyed on `field_layout` is the contract). Faking
  `Math/PI` as a 0-arity method (static-field read is D-148). Flipping
  `phase_at_least_14` / tagging v0.1.0 (release HELD). Treating §9.17 `[ ]`
  (14.12 deferred / 14.14 release held) as the next task.

## Current state

Phase 14 v0.1.0 substantive work DONE; release HELD. Mac gate 111/111.
Interop instance-member dispatch unified across both backends; native
String surface (`.m str`); Java static methods (`Math/abs`, bare
`System/…`) via the `java.lang.*` auto-import. `.static_method` works in
TreeWalk; VM arm is VM-DEFER (D-130, the next task). F-010-ordered gaps
(JIT / nREPL / line-editor / Wasm-Component / deps) deferred.

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

§A26 interop coverage: D-130 `.static_method` VM arm (next, closes the
cluster) → **Phase 15** (concurrency; unblocks D-117/D-118 nREPL) →
superinstruction/fusion → narrow ARM64 JIT (D-133) → **M** →
quality-elevation loop (`docs/works/`). cw-v0 gap plan in
`.dev/cw_v0_parity_and_gap_plan.md` (§A26).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-130** interop `.static_method` VM arm (rides or follows Q1; bytecode
  shape op_interop_call vs sibling op_static_method_call undecided).
  **D-147** `fn*` self-name slot. **D-076** destructuring. **D-134**
  clojure.core (`partition` 4-arg pad + comp/juxt multi-arity). **D-143**
  apply multi-arity spread. **D-142** Env-scope `*error-context*`.
  **D-141** bench multi-lock. **D-105/D-106** time/net+crypto. **D-116**
  line-editor. **D-117/D-118** nREPL (Phase-15-gated). **D-075** metadata.
  **D-133** JIT floor.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ `.dev/decisions/0050_unified_interop_call_node.md` (base + § Amendment 1)
→ `src/eval/analyzer/special_forms.zig` (`resolveJavaSurface` ~48 +
`analyzeStaticMethodCall`) + `src/runtime/java/lang/System.zig` (surface
pattern) → ROADMAP §A26 + `.dev/cw_v0_parity_and_gap_plan.md`.
