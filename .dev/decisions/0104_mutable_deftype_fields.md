# ADR-0104 — Mutable deftype fields (`^:unsynchronized-mutable` / `^:volatile-mutable` + `set!`)

- Status: Proposed → Accepted (2026-06-07)
- Drives: D-288 (deftype mutable fields), campaign Stage 1.3 ladder rung 6
  (`clojure.tools.reader`'s `StringReader`).
- Related: D-202 (field-in-scope read), ADR-0036 (dual-backend parity),
  ADR-0096 (`set!` Var semantics), F-002 / F-004 / F-005 / F-009 / F-011 /
  F-012 / F-013.

## Context

cljw `deftype` instances are value records whose fields live in a per-instance
`gc.infra`-owned slice (`TypedInstance.field_values_ptr`,
`runtime/type_descriptor.zig`). That slice is **already mutable in place** and
GC-safe under the non-moving mark-sweep collector (no write barrier; each slot
is already traced) — it is simply never written after construction.

Two real gaps block `(set! field v)` inside a method (the D-288 driver,
`clojure.tools.reader`'s `StringReader`, whose `^:unsynchronized-mutable ^long
s-pos` is mutated via `(set! s-pos (inc s-pos))`):

1. **Mutability metadata is dropped at field-parse.** `lowerDefType`
   (`lang/macro_transforms.zig`) reads only the field symbol's name; the
   reader's `^:unsynchronized-mutable` lives on `field_form.meta` and is never
   inspected. `FieldEntry` has no mutable flag.
2. **`set!` is Var-only and field READS are stale snapshots.**
   `analyzeSetBang` (`eval/analyzer/special_forms.zig`) only resolves dynamic
   Vars; a bare field symbol is a method-body local → "Unable to resolve
   symbol". Worse, D-202's field-in-scope wraps the body in
   `(let* [field (.field this)] body)` — a **value copy**, so even if a write
   landed, a later read in the same body would see the stale snapshot.

Oracle (clj 1.12) fixes the target semantics:

- In-method `(set! n (inc n))` then `(str n)` reads the **live** updated value
  (`#"1" / 2 3` across three calls) — reads of a mutable field MUST hit the
  live slot, not a snapshot.
- External `(set! (.n c) 5)` **fails** ("No matching field found: n") — a
  deftype mutable field is assignable ONLY inside the type's own methods.
- `(defrecord R [^:unsynchronized-mutable n])` **fails at macro time**
  (":volatile-mutable or :unsynchronized-mutable not supported for record
  fields").

## Decision

Implement mutable deftype fields with **in-method-only** assignment, matching
clj. The field slice's in-place mutability is reused (no value-rep change).

1. **Mutability is carried macro→analyzer, not on the descriptor.**
   `lowerDefType` inspects each `field_form.meta` for `:unsynchronized-mutable`
   / `:volatile-mutable` (a shared `fieldIsMutable` helper); the two keywords
   are **unified to one "assignable" flag** while single-threaded (AD-018).
   Mutable fields are **rejected on `__defrecord!`** at macro time (clj parity)
   via a new `error_catalog` Code `defrecord_mutable_field`. The mutable
   field-name set flows into `wrapMethodBodyWithFields` → the `__mut-fields!`
   transport form → the analyzer `Scope`.

   A descriptor-level `FieldEntry.mutable` flag is **deferred** (YAGNI /
   finished-form = no dead field): the MVP has no runtime consumer — the macro
   is the mutability SSOT, the analyzer produces `set_field_node` only for
   in-context mutable fields, and `set!` on a non-mutable field falls through to
   the existing Var path (its "unresolved" error is acceptable; the precise
   clj "Cannot assign to non-mutable" message is a deferred nicety that would
   need all-fields-with-flag context). When a runtime consumer arrives
   (introspection, the reference-identity equality refinement, or the precise
   non-mutable error), add `FieldEntry.mutable` then.

2. **Writable slot.** `TypedInstance.setField(index, v)` writes
   `field_values_ptr[index]`. GC-safe (mark-sweep, slot already traced; no
   barrier). The receiver value being written is on the eval stack / rooted by
   the caller's frame at the write point (no new root site — `GC-ROOT` audit
   not triggered; the write replaces a traced slot in an already-rooted
   instance).

3. **Field-context carried on the analyzer `Scope`.** A new optional
   `Scope.mutable_fields: ?*const MutFieldCtx` (the `this` local slot + a
   field-name set), chain-inherited exactly like `recur_target`. It is
   **established by a minimal internal transport form** the macro emits:
   `(rt/__mut-fields! this [mfield…] <body>)`. The transport is necessary
   because only the macro layer knows which fields are mutable; the form is to
   `mutable_fields` what `loop*` is to `recur_target` (a form whose analyzer
   handler pushes an analysis-context frame), not redundant machinery.

4. **`wrapMethodBodyWithFields`** splits fields: **immutable** fields keep the
   existing `(let* [field (.field this)])` value-copy (correct + faster — they
   never change); **mutable** fields are NOT bound in the `let*` and the body is
   wrapped in `(rt/__mut-fields! this [mfield…] …)`.

5. **Read** (`analyzeSymbol`): a bare symbol in the `Scope.mutable_fields`
   context lowers to the **existing `instance_member` read node**
   (`(.field this)`, field-only) — live each eval, reusing the dot-read on BOTH
   backends. No new read node.

6. **Write** (`analyzeSetBang`): a bare symbol in the `mutable_fields` context
   builds a new **`set_field_node { target, field_name, value_expr }`** (target
   = the `this` local-ref). The field index is resolved at eval from the
   receiver's descriptor (reusing `evalInstanceMember`'s field-first resolver).
   Non-symbol `set!` targets (the external `(set! (.field obj) v)` form) stay
   `feature_not_supported` — clj rejects them too, so this is not a gap
   (F-013: comprehensive per the DEFINITION, and the definition is in-method
   assignment).

7. **Dual-backend** (ADR-0036 / F-012): `set_field_node` lands TreeWalk arm +
   VM compile arm + `op_set_field` opcode + VM dispatch arm + a `diff_test`
   case INCLUDING a read-after-write-in-one-body (`(do (set! n 1) n)` shape) to
   lock both backends re-reading the live slot.

8. **Accepted divergences** (pinned, per `accepted_divergences.md`):
   - **AD-017** — `^long` / primitive field type hints are parsed-and-ignored
     (NaN-box: every slot is a uniform 8-byte `Value`; cljw does not enforce
     clj's "must assign primitive to primitive mutable"). `derives_from`
     F-004 / F-005.
   - **AD-018** — `:unsynchronized-mutable` ≡ `:volatile-mutable` (both → one
     assignable flag) while single-threaded; the cross-thread visibility
     distinction is dormant until Phase 15+ concurrency. `derives_from` the
     single-thread posture; the original keyword is recoverable from source for
     a future differentiation.

### Stance: a mutable deftype is a reference type

cljw's value model is otherwise immutable. A mutable deftype is a genuine
**reference type**: equality / hash stay identity-or-user-method (clj excludes
mutable fields from structural equality), and mutating a field breaks no
sharing because deftype instances are never structurally shared / copied
(unlike a persistent collection). GC is unaffected (per-instance slice, already
traced). This is the "mutability in an otherwise-immutable value model" tension
D-288 flagged; the resolution is "reference identity, no structural sharing".

## Alternatives considered (Devil's-advocate, fresh context)

> Verbatim from a fresh-context `general-purpose` Devil's-advocate fork
> (CLAUDE.md § ADR-level designs are handled inline). Active F-NNN envelope:
> F-002 / F-004 / F-005 / F-009 / F-011 / F-012 / F-013.

**Leading finding:** no alternative requires violating an F-NNN. The two
prose decisions (`^long` ignore, keyword unification) must be PINNED as
`AD-NNN` rather than buried — adopted (AD-017 / AD-018).

**Alt 1 — Smallest-diff: macro-level body rewrite to dot-forms (survey Shape
B).** Keep the analyzer untouched; recursively walk the method body rewriting
bare `field` → `(.field this)` and `(set! field v)` → `(set! (.field this) v)`,
then implement the non-symbol `set!` target as the field write. *Better:* no
new special form / Scope surgery / symbol-read codepath; the general
`(set! (.field obj) v)` it forces into existence is independently clj-real.
*Breaks:* the recursive symbol-rewrite must hand-re-implement shadowing /
quoting / nested-rebinding — the exact work `let*`/the analyzer give for free;
this is the **Smallest-diff bias smell**, and a wrongly-rewritten quoted
`field` is a silent correctness bug. Recommended against on F-002 grounds.

**Alt 2 — Finished-form-clean (RECOMMENDED): field context on `Scope` +
general field-set, bare-field as sugar.** (2a) Thread mutable-field context
through the `Scope` chain (parallel to `recur_target`) rather than a new
special form. (2b) Implement `(set! (.field obj) v)` generally for any
receiver; bare-field set! is sugar over the same node. *Better:* reuses the
analyzer's existing analysis-context mechanism; one `set_field_node` for both
in-method and external; pins the two AD decisions. *Breaks:* larger analyzer
change (not a cost under F-002).

> **Main-loop adjustment to Alt 2 (recorded, not deferred):** the oracle shows
> clj REJECTS the external `(set! (.field obj) v)` form for deftype fields
> ("No matching field found"), so Alt 2b's general external receiver
> **over-reaches clj semantics** and is dropped — F-013 mandates comprehensive
> coverage of the DEFINITION (in-method assignment), not a superset clj does
> not have. The `set_field_node` carries a general `target` Node (clean, no
> this-hardcoding) but `analyzeSetBang` PRODUCES it only for in-method bare
> mutable fields. Alt 2a (Scope-carried context) is adopted; the DA's
> "`__mut-fields!` is redundant" critique is answered by the macro-only-knows-
> mutability transport argument (Decision §3) — the Scope CARRIES the context,
> the transport form ESTABLISHES it, mirroring loop*→recur_target.

**Alt 3 — Wildcard: per-field mutable cell.** Store each mutable field as a
one-slot reference cell; `set!` writes the cell interior. *Better:* makes
mutability first-class in the value model; clean Phase-15 volatile story; no
mid-eval slice-write consideration. *Breaks:* a per-field cell allocation +
a transparent deref-on-every-read clj does not have, diverging from clj's
identity model (F-011); solves a GC/visibility problem that does not exist
(the slot is already traced, mark-sweep needs no barrier). Recommended
against — Phase 15 can branch the slot-write on the recorded keyword instead.

## Consequences

- `(deftype C [^:unsynchronized-mutable n] …)` methods can `(set! n v)` /
  `(set! n (inc n))` with live reads — `clojure.tools.reader` unblocks (ladder
  rung 6).
- `defrecord` with a mutable field now errors at macro time (clj parity) —
  previously the hint was silently dropped.
- One new analyzer Node (`set_field_node`) + one new opcode (`op_set_field`);
  the dual-backend gate enforces both arms + a diff case in the same commit.
- Two new pinned accepted divergences (AD-017 / AD-018).
- External `(set! (.field obj) v)` stays unsupported (clj-faithful).

## Affected files

- `src/runtime/type_descriptor.zig` — `TypedInstance.setField` (write a slot).
  (`FieldEntry.mutable` deferred — no MVP consumer.)
- `src/lang/macro_transforms.zig` — `fieldIsMutable` helper; `lowerDefType`
  defrecord reject; `wrapMethodBodyWithFields` mutable/immutable split +
  `__mut-fields!` wrap.
- `src/eval/analyzer/analyzer.zig` — `Scope.mutable_fields` +
  `analyzeSymbol` mutable-field read hook + `__mut-fields!` special form.
- `src/eval/analyzer/special_forms.zig` — `analyzeSetBang` field arm +
  `__mut-fields!` handler.
- `src/eval/node.zig` — `set_field_node`.
- `src/eval/backend/tree_walk.zig` — `set_field_node` eval arm.
- `src/eval/backend/vm/opcode.zig` / `vm/compiler.zig` / `vm.zig` —
  `op_set_field`.
- `src/lang/diff_test.zig` — parity case (incl. read-after-write-in-one-body).
- `src/runtime/error/catalog.zig` — `defrecord_mutable_field` Code.
- `.dev/accepted_divergences.yaml` — AD-017 / AD-018 + pin tests.
- `test/e2e/` — mutable deftype counter + read-after-write cases.
