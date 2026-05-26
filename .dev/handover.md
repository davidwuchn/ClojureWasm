# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.3 cycle 6 first
  red — NEW `src/lang/primitive/protocol.zig` with Layer-2
  primitives wrapping the runtime helpers landed in cycles 1-5:
  `rt/__make-protocol!` (name-sym, methods-vec) →
  ProtocolDescriptor Value; `rt/__make-protocol-fn!` (proto,
  method-name-str) → ProtocolFn Value; `rt/__extend-type!` (td,
  proto, impls-vec) → mutates td via `extendTypeWithImpls`;
  `rt/__satisfies?` (proto, val) → bool (calls `satisfies`
  helper). Register in `src/lang/primitive.zig` + `src/main.zig`
  aggregator. Mirror row 7.2 cycle 5b primitive shape. Cycle 7
  then lands macros (defprotocol / extend-type / extend-protocol),
  cycle 8 e2e + diff_test. Row 7.3 [x] flip after D-082 discharge
  (typed_instance walk in row 7.2 isaCheck per survey §7).
- **Forbidden this session**: (a) re-deriving Phase 7 entry triad
  (T1 ADR-0036 + T2 ADR-0037 + T3 ADR-0035 D9 second amendment).
  (b) commits adding VM compile arm bodies of the form
  `return error.NotImplemented` without an adjacent `// VM-DEFER:`
  marker. (c) re-introducing evalInNs / op_in_ns auto-refer
  block. (d) calling `TypeDescriptor.lookupMethod` directly from
  new code — route through the row 7.1 `dispatch(rt, env, cs,
  receiver, protocol, method, args, loc)` ABI. (e) Re-deriving
  row 7.2 multimethod shape (ADR-0008 amendment 2 Alt 1 binding).
  (f) Re-deriving row 7.3 cycles 1-5 — protocol_generation /
  extendTypeWithImpls / CallSite.cached_generation guard /
  ProtocolFn extern / ProtocolDescriptor extern / satisfies are
  all landed.

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell catalogue) → `.dev/ROADMAP.md`
§9.9 → ADR-0008 (entry ADR; amendment 1 Alt 1 + amendment 2 are
both binding) → `private/notes/phase7-7.3-survey.md` §5 (binding
shape) → `private/notes/phase7-7.3-cycle1to5.md` (this row's
state) → `feature_deps.yaml` → `.dev/debt.md` Step 0.5 sweep.

## Current state

- **Phase**: Phase 7 IN-PROGRESS — §9.9 rows 7.0 / 7.1 / 7.2 all
  [x]. Row 7.3 cycles 1-5 landed (runtime-layer foundation):
  cycle 1 (4f57ee6) protocol_generation + extendTypeWithImpls;
  cycle 2 (b80d853) CallSite.cached_generation guard; cycle 3
  (25a9195) ProtocolFn extern; cycle 4 (135e876) ProtocolDescriptor
  extern; cycle 5 (5243a50) satisfies helper. Active = row 7.3
  cycle 6 (Layer-2 primitives).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 42/42 + OrbStack Ubuntu x86_64 42/42 green at
  HEAD `5243a50`.
- **VM-DEFER markers**: 4 active sites (3 deftype-family in
  `vm/compiler.zig` + 1 `require_libspec` in `compileRequire`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.3 cycle 6

Layer-2 primitives wrapping the cycle-1-to-5 runtime helpers.
See Resume contract + the survey §5.6 spec for the shape. The
Devil's-advocate Alt 1 verdict from ADR-0008 amendment 1
(generation deferred from 7.1 to 7.3) discharged naturally at
cycle 2; no new Devil's-advocate fork expected at cycle 6 unless
a provisional behaviour surfaces in Step 0.6 re-laying.

After cycle 6: cycle 7 (macros per row 7.2 cycle 5c pattern),
cycle 8 (e2e + diff_test), D-082 discharge (typed_instance walk),
row 7.3 [x] flip.

## Open questions / blockers

None testable from inside the loop. D-081 (derive ergonomic
surface) blocked-by D-012 (Atom + swap!, Phase 15 target);
neither blocks row 7.3.

## Guardrail refresh history (condensed)

Waves 1-16 (2026-05-23..26): F-NNN + Bad Smell + ADR-0029..0035 +
provisional-marker mechanisation + handover_framing hook. Phase
6→7 boundary triad (T1 ADR-0036 / T2 ADR-0037 / T3 ADR-0035 D9
second amendment) + audit-2026-05-26 clean. Row 7.2 close
(2026-05-26, 5 cycles + ADR-0008 amendment 2). Row 7.3 cycles
1-5 landed in the same session (runtime-layer foundation: 17
commits total this session, all gates green).
