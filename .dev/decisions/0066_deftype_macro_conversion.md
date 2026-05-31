# ADR-0066 — `deftype` becomes a macro mirroring `defrecord` (retire the special form)

- **Status**: Proposed → Accepted (2026-06-01)
- **Discharges**: D-087 (deftype Name/->Name unbound + protocol body silently dropped)
- **Related**: ADR-0007 (TypeDescriptor / Option β), ADR-0041 (fn multi-arity),
  ADR-0050 (interop call node), `.claude/rules/dual_backend_parity.md` (ADR-0036),
  F-002 / F-009 / F-011, D-048 (catch-by-deftype-class, orthogonal)

## Context

`deftype` was a **special form** (`analyzer/special_forms.zig::analyzeDeftype`
→ `deftype_node` → `tree_walk::evalDeftype` / VM `op_deftype`). `analyzeDeftype`
parsed only `(deftype Name [fields])` and **silently ignored any protocol-impl
body** after the field vector — `(deftype T [v] IFoo (foo [_] ...))` "succeeded"
while dropping the `IFoo` impl (a permanent-no-op, forbidden by
`provisional_marker.md`). It also never bound the positional constructor `->Name`
(`(->T 42)` → "Unable to resolve symbol"), unlike JVM Clojure.

`defrecord` is **already a macro** (`macro_transforms.zig::expandDefrecord`)
lowering to `(do (def Name (rt/__defrecord! 'Name ['fields])) (def ->Name
(fn* [..] (Name. ..))) extend-type-sections...)`. deftype and defrecord differ
only in the registered `TypeDescriptor.kind` (`.deftype` vs `.defrecord`) and the
absence of map semantics for deftype — and the downstream map-protocol arms
already gate on `inst.descriptor.kind != .defrecord` (collection.zig:429/564/615),
so a `.deftype`-kind instance is correctly excluded from map behaviour.

A Devil's-advocate review (general-purpose subagent, fresh context, F-NNN-
constrained) also surfaced a **latent VM bug (BUG-1)**: the VM `op_deftype` arm
pushed nil and relied on a (false) "analyzer-time registerType" comment — a
deftype run on the VM backend ALONE never registered the type. The diff harness
masked this by running TreeWalk first on the same `rt` (state leak).

## Decision

Convert `deftype` to a macro `expandDeftype` mirroring `expandDefrecord`, and
**retire the special form**. Per the DA's correction, do NOT duplicate
`defrecordPrim`: extract a shared kind-parameterised registration helper that
both `rt/__defrecord!` and the new `rt/__deftype!` thunk into (F-011 — the two
primitives differ only in the `.kind` passed to `registerType`).

Removed (the deletion is fully enumerable; the VM's exhaustive `Opcode` / `Node`
switches make completeness compiler-enforced):

- `deftype` from the analyzer special-forms table + `deftype_form` enum tag +
  dispatch arm + `analyzeDeftype`.
- `deftype_node` from the `Node` union + `evalDeftype` (TreeWalk) + the VM
  compile arm + `op_deftype` (opcode enum + emit + VM dispatch).
- The false "analyzer-time registerType" comments.

The macro's `rt/__deftype!` call is a backend-neutral primitive (executed
identically by TreeWalk eval and VM `op_call`), so registration no longer splits
by backend — **BUG-1 is fixed as a side effect**.

## Consequences

- `(deftype Name [fields] Proto (m [..] ..))` now binds `Name` + `->Name` and
  applies the protocol impls via the shared `extend-type` lowering. clj-grounded.
- deftype gets NO map semantics (kind-gated) — matches JVM `deftype` vs
  `defrecord`.
- catch-by-deftype-class is unaffected: `host_class.isKnownException` scans a
  static list, never `rt.types` (D-048 remains the orthogonal open row).
- `(Name. args)` constructor still resolves via eval-time `rt.types.get` inside
  the macro's `(do ...)` — same ordering as before.
- A **VM-only** (fresh-`rt`) deftype test is added so the diff harness no longer
  masks backend-specific registration (dual_backend_parity test point 4).
- The analyzer unit test asserting `n.* == .deftype_node` is rewritten to assert
  macro expansion.

## Alternatives considered (Devil's-advocate output, verbatim summary)

- **Alt 1 — smallest-diff: keep the special form, parse the body + emit ->Name in
  `analyzeDeftype`.** Rejected: re-implements `expandDefrecord`'s entire
  extend-type lowering in analyzer/Node space — a direct F-011 violation
  (commonization outranks effort); leaves BUG-1 unfixed. Its only honest sub-
  variant (raise `feature_not_supported` for the body) is a strictly-worse
  transient stub than implementing it.
- **Alt 2 — finished-form: the macro conversion (CHOSEN).** Maximal F-011
  commonization (`expandDeftype`/`expandDefrecord` differ only in primitive name +
  `.kind`); F-009-clean; deletes a Node variant + opcode; incidentally fixes
  BUG-1. DA corrections folded in: (1) share a kind-parameterised registration
  primitive instead of a duplicated `__deftype!`; (2) verified the map-semantics
  gate keys on `.kind` not `field_layout`.
- **Alt 3 — wildcard: one `expandDefType(kind)` body + one kind-param primitive
  for BOTH deftype and defrecord.** Primitive-level unification adopted (the
  registration genuinely never diverges); macro-level unification rejected —
  defrecord grows map-only factory/assoc/`=`-by-fields that deftype must never
  have, so a single macro body would accumulate a `kind`-branch thicket. Two thin
  macro bodies sharing extracted helpers is cleaner than one branchy body.

DA recommendation (non-binding): Alt 2 with the shared kind-param primitive — the
main loop adopts exactly this. No F-NNN blocks any alternative; cycle/diff size
did not factor into the ranking.
