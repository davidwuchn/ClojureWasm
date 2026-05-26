# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.7 first red —
  D-069 polymorphic primitives (count / seq / conj / reduce)
  refactored to hybrid Zig Tag-switch fast-path + Protocol
  extension point opens. ROADMAP row 7.7 description:
  "D-069 — Phase 6.16.a-1/a-2 polymorphic primitives (count /
  seq / conj / reduce) refactored to hybrid: Zig Tag-switch
  fast-path + Protocol extension point opens
  (= `extend-type` reaches them)." Row 7.6 (.method dispatch +
  D-073 a/b/c/f) closed in the prior session. Step 0 survey
  required (Clojure JVM `clojure.core` count/seq/conj/reduce
  semantics + cw v1 current primitive shapes + extension hook
  design).
- **Forbidden this session**: (a) re-deriving Phase 7 entry triad
  (T1 ADR-0036 + T2 ADR-0037 + T3 ADR-0035 D9 second amendment).
  (b) commits adding VM compile arm bodies of the form
  `return error.NotImplemented` without an adjacent `// VM-DEFER:`
  marker. (c) re-introducing evalInNs / op_in_ns auto-refer block.
  (d) calling `TypeDescriptor.lookupMethod` directly from new code
  — route through the row 7.1 `dispatch(rt, env, cs, receiver,
  protocol, method, args, loc)` ABI. (e) Re-deriving row 7.2
  multimethod shape (ADR-0008 amendment 2 Alt 1 binding). (f)
  Re-deriving row 7.3 — all 12 cycles + 4 ADR amendments landed
  (cycles 1-8.5). (g) Reverting MethodEntry to `fn_ptr: ?*const
  anyopaque` (Alt 2 finished form). (h) Reverting analyzeDef to
  lazy-intern (ADR-0038 selected Alt 2 over status quo).

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` (Bad Smell catalogue) → `.dev/ROADMAP.md` §9.9
→ ADR-0008 (all 3 amendments binding) + ADR-0038 (analyzeDef
pre-register) → `private/notes/phase7-7.3-cycle8*.md` for row 7.3
end-state → `feature_deps.yaml` → `.dev/debt.md` Step 0.5 sweep.

## Current state

- **Phase**: Phase 7 IN-PROGRESS — §9.9 rows 7.0 / 7.1 / 7.2 / 7.3
  / 7.4 / 7.5 / 7.6 all [x]. Row 7.4 (defrecord) 6 cycles. Row
  7.5 (reify) 4 cycles + ADR-0039 (DA fork). Row 7.6 (.method
  dispatch + D-073 cluster) 2 cycles: cycle 1 (`40268e2`)
  MethodCallNode + analyzer arm + evalMethodCall (lookupMethod
  Path A2 widening); cycle 4 (`055a3cc`) ADR-0040 + 4 new opcodes
  + BytecodeChunk.call_sites side-table + 4 compile arms + 4
  dispatch arms + 2 diff_test cases. ADR-0039 + ADR-0040 +
  Devil's-advocate forks landed. D-082 DISCHARGED. D-073 cluster
  sub-sites a/b/c/f DISCHARGED (d require_libspec + e ns_filter
  remain). D-085 (keyword-as-fn) and D-086 (defrecord
  `__extmap`) remain opportunistic. Active = row 7.7 (D-069
  polymorphic primitives + protocol extension point).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 44/44 + OrbStack Ubuntu x86_64 44/44 green at HEAD
  row 7.4 close commit.
- **VM-DEFER markers**: 4 active (3 deftype-family in
  `vm/compiler.zig` + 1 `require_libspec` in `compileRequire`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table, D-086
  defrecord __extmap (2 markers in assocFn).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.7 (D-069 polymorphic primitives + protocol extension)

D-069 — refactor Phase 6.16.a polymorphic primitives (`count` /
`seq` / `conj` / `reduce`) to a hybrid shape: Zig Tag-switch
fast-path for native collection tags + Protocol extension point
that `extend-type` reaches. Today these primitives are closed
switches that raise on unknown tags; row 7.7 opens them up so
user-defined defrecord/reify can extend them via the row 7.3
dispatch ABI. Step 0 survey required.

## Open questions / blockers

None testable from inside the loop. D-073 cluster's d (require
libspec) + e (ns_filter) sub-sites remain — opportunistic. D-081
(multimethod ergonomic surface) blocked-by D-012 (Atom + swap!,
Phase 15 target). D-083 (multimethod diff_test parity)
opportunistic. D-085 (keyword-as-fn callable) opportunistic —
needs Layer-0 lookup helper. D-086 (defrecord __extmap overflow)
dedicated cycle later. Runtime.deinit cleanup for diff_test
process-lifetime descriptor handling deferred — surfaced at row
7.6 cycle 4 when 2 of 4 planned diff_test cases needed deferral.

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`
for detail. Landmarks: Phase 6→7 boundary triad (ADR-0036 /
ADR-0037 / ADR-0035 D9 second amendment); Row 7.2 close (5 cycles
+ ADR-0008 amendment 2); Row 7.3 close (cycles 1-8.5 + ADR-0008
amendment 3 + ADR-0038; per-Tag descriptor registry + analyzer
pre-register + .protocol_fn dispatch arm).
