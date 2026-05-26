# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (row 7.7 cycle 5 close commit is HEAD).
- **First commit on resume MUST be**: §9.9 row 7.8 — Step 0 survey for
  D-070 multi-arity `fn*` / `defn` analyzer extension. Expected shape:
  `(fn* ([x] body1) ([x y] body2))` analyzer pre-pass that builds an
  arity dispatch table on the resulting `.fn_val`; `treeWalkCall`'s
  `.fn_val` arm consults arity dispatch (currently single-arity); VM
  compile arm mirrors. Back-fills transducer 1-arg arity + multi-arg
  comp / juxt / partial / complement / every? deferred at row
  6.16.a-3 (`.dev/ROADMAP.md` §9.9 row 7.8 placeholder cross-references
  the affected `.clj` defns). Reference: `~/Documents/OSS/clojure/src/jvm/clojure/lang/Compiler.java`
  FnMethod + FnExpr classes for the JVM arity-dispatch shape.
- **Forbidden this session**: (a) `return error.NotImplemented`
  in VM compile arms without an adjacent `// VM-DEFER:` marker.
  (b) calling `TypeDescriptor.lookupMethod` directly from new
  code — route through `dispatch(rt, env, cs, receiver,
  protocol, method, args, loc)` or `dispatchOrNull(...)`. (c)
  widening `BytecodeChunk.call_sites` semantics beyond ADR-0040
  without an amendment. (d) re-introducing manual `defer rt.gc.
  infra.destroy(...)` for ProtocolDescriptor / ProtocolFn /
  TypeDescriptorRef — row 7.7 cycle 1's `rt.trackHeap`
  registrations in `makeProtocol` / `makeProtocolFn` /
  `makeTypeDescriptorRef` own the destroy via `rt.deinit`.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow
+ § The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.9 → `.dev/debt.md`
Step 0.5 sweep (D-070 row + D-087..D-089 row 7.7 follow-ups).

## Current state

Phase 7 IN-PROGRESS — §9.9 rows 7.0..7.7 all [x]. Row 7.8 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 48/48 +
OrbStack Ubuntu x86_64 47/47.

## Active task — §9.9 row 7.8

D-070 — multi-arity `fn*` / `defn` analyzer extension. The
analyzer currently rejects `(fn* ([x] body1) ([x y] body2))`
(only single-arity bodies); user-facing `.clj` defns that need
multi-arity (transducer 1-arg of map/filter/take/etc., multi-arg
comp/juxt/partial/complement/every?) are PROVISIONAL pending
this row. Step 0 survey produces the `feature_deps.yaml#fn_multi_arity`
+ analyzer-pass + dispatch-table design.

## Open questions / blockers

None testable from inside the loop. Outstanding debt referenced
by ID: D-073 (sub-sites d require_libspec + has_rest VM mirror
+ diff_test descriptor cleanup remain), D-081 (multimethod
ergonomic surface; blocked-by D-012 Phase 15), D-083
(multimethod diff_test parity, opportunistic), D-085
(keyword-as-fn callable, opportunistic), D-086 (defrecord
`__extmap`, dedicated cycle), D-087 (deftype Name var binding,
opportunistic), D-088 (protocol fqcn ns-prefix collision,
opportunistic), D-089 (row 7.7 Q6 retro-audit cluster — other
collection primitives needing hybrid slow-path, Phase 8+).

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`.
Landmarks: Phase 6→7 boundary triad (ADR-0036 / ADR-0037 /
ADR-0035 D9 second amendment); row 7.2 close (ADR-0008
amendment 2); row 7.3 close (cycles 1-8.5 + ADR-0008 amendment 3
+ ADR-0038); row 7.5 close (ADR-0039 DA fork); row 7.6 close
(ADR-0040 DA fork); row 7.7 close (ADR-0008 amendment 4 R3a-
extracted + DA fork + bundled latent-leak fixes across
`extendTypeWithImpls` / `registerType` / `rt.deinit` /
trackHeap-cleanups for ProtocolDescriptor / ProtocolFn /
TypeDescriptorRef).
