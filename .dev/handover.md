# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.4 first red —
  `defrecord` analyzer + eval surface. ROADMAP row 7.4 description:
  "5.12.b carry-forward — defrecord analyzer + eval. Implicit
  IPersistentMap semantics (get/assoc/keys/vals over field names).
  Uses Phase 7 dispatch ABI." Phase 5 task 5.12 left the
  deftype/defrecord analyzer skeleton; row 7.4 picks it up with
  the row 7.3 protocol dispatch surface (`__extend-type!` +
  `.protocol_fn` arm + per-Tag registry) now landed. Survey first
  via Step 0 (Clojure JVM `core_deftype.clj` defrecord + cw v0
  prior art + cw v1 5.12 skeleton) before macro/primitive design.
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
  all [x]. Row 7.3 closed at `d2b1c98` (cycles 1-8.5 across the
  same session: runtime helpers → Layer-2 primitives →
  TypeDescriptorRef wrap → macros → analyzer pre-register +
  per-method-Var restore → .protocol_fn dispatch arm + per-Tag
  descriptor registry). Active = row 7.4 (defrecord).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 44/44 + OrbStack Ubuntu x86_64 43/43 green at HEAD
  `d2b1c98`.
- **VM-DEFER markers**: 4 active (3 deftype-family in
  `vm/compiler.zig` + 1 `require_libspec` in `compileRequire`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.4 (defrecord)

`defrecord` analyzer + eval, plus implicit IPersistentMap semantics
(get/assoc/keys/vals over field names). Uses the Phase 7 dispatch
ABI (row 7.3's `dispatch(rt, env, cs, receiver, protocol, method,
args, loc)` + `.protocol_fn` arm + extend-type). Row 7.4 enables
user-typed_instance receivers which unblock (a) full survey §8
7-case ladder e2e for row 7.3 (the user-type subset) and (b) D-082
discharge (typed_instance walk in isaCheck). Step 0 survey before
implementation per `.claude/rules/textbook_survey.md`.

## Open questions / blockers

None testable from inside the loop. D-081 (multimethod ergonomic
surface) blocked-by D-012 (Atom + swap!, Phase 15 target). D-082
(typed_instance walk in isaCheck) re-recallable at row 7.4 entry
once deftype lands user typed_instances. D-083 (multimethod
diff_test parity) opportunistic.

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`
for detail. Landmarks: Phase 6→7 boundary triad (ADR-0036 /
ADR-0037 / ADR-0035 D9 second amendment); Row 7.2 close (5 cycles
+ ADR-0008 amendment 2); Row 7.3 close (cycles 1-8.5 + ADR-0008
amendment 3 + ADR-0038; per-Tag descriptor registry + analyzer
pre-register + .protocol_fn dispatch arm).
