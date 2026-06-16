# ADR-0154 — defrecord `__extmap` (non-declared keys on a record)

- **Status**: Proposed → Accepted
- **Date**: 2026-06-16
- **Discharges**: D-086 (assoc a non-declared key onto a defrecord)
- **Cross-refs**: ADR-0112 (the `meta` trailing-field twin this mirrors),
  ADR-0068 (record map-style surface), F-002 (finished-form), F-004
  (NaN-box 64-slot — no new tag), F-006 (non-moving mark-sweep GC),
  F-011 (clj behavioural equivalence), F-013 (definition-derived
  capability); `private/notes/9.0-D086-record-extmap-plan.md` (the
  wiring/reference-chain audit).

## Context

A JVM `defrecord` keeps non-declared keys in a hidden `__extmap` map, so a
record's IRecord/IPersistentMap identity survives `(assoc rec :extra v)`:

- `(assoc (->R 1 2) :z 9)` → `#user.R{:x 1, :y 2, :z 9}` (clj). cljw raised
  `defrecord_assoc_undeclared_key`.
- `(map->R {:x 1 :y 2 :z 3})` → keeps `:z` (clj). cljw dropped it.
- `(count (assoc (->R 1 2) :z 9))` → 3; `(keys …)`/`(vals …)`/`(seq …)`
  include the extra; `(get … :z)`/`(contains? … :z)` see it; `(dissoc … :z)`
  removes it; `(= (assoc r :z 9) (assoc r :z 9))` → true and they hash equal.

cljw's `TypedInstance` (extern struct: header + `field_count` + descriptor
pointer + flat `[]Value` field tail + `meta`) had no place to hold extras.
D-086 (written 2026-05-26) framed this as a heavy structural seizure
deferred to a layout owner (F-003). The **`meta` field (ADR-0112, landed
2026-06-07, after the row)** since proved the exact pattern — a trailing
optional `Value` on the same extern struct + a one-line GC trace + assoc
re-mint threading — so the struct/GC half is precedented and low-risk, and
the F-003 "layout owner" deferral resolves to the loop itself under the
gap-area model (ADR-0142).

## Decision

Mirror the ADR-0112 `meta` shape, with the differences extmap demands
(extmap is part of record **value identity**; meta is not):

1. **`TypedInstance` gains `extmap: Value = .nil_val`** (`type_descriptor.zig`,
   appended after `meta` — `header` stays at offset 0). Invariant: extmap is
   either `nil` (no extras — the common case) or a **non-empty** persistent
   map. `allocInstance` inits it nil; `allocInstanceFull` threads an explicit
   extmap (and meta). `instWithMeta` / the record `assoc` re-mint thread the
   source instance's extmap so it survives `with-meta` / declared-field
   updates.

2. **One descriptor-owned partition chokepoint** (the DA's Alt 2). The
   "is this key a declared field, and at what slot?" rule lives once as
   `TypeDescriptor.fieldSlotByName(name) ?u16`; `assoc`/`dissoc`/`get`/
   `contains?` all call it instead of each re-walking `field_layout`. A key
   that resolves to a slot writes/reads the field; everything else is an
   extmap key. This makes the declared/extmap split definition-derived
   (F-013) and structurally identical across `assoc` and `map->R`, so two
   `=` records can never diverge on which keys are "declared" (the DA's
   hazard 2).

3. **assoc** (`collection.zig` `.typed_instance` arm): a non-declared key (or
   empty/absent layout) re-mints via `allocInstanceFull` with the key
   assoc'd into extmap; multi-pair folds over single-pair (clj reduces over
   pairs), so `(assoc r k1 v1 k2 v2 …)` works. The two PROVISIONAL raise
   sites and the multi-pair raise are removed.

4. **dissoc** (`collection.zig`): a non-declared key in extmap → re-mint with
   extmap dissoc'd, **normalized back to nil when it empties** (so the result
   `=` a record that never had extras — the DA's leading finding). A
   **declared** key still demotes the record to a plain map (clj parity), and
   that demoted map now folds in the extmap entries too.

5. **Read paths route declared-then-extmap**: `recordGet` (declared field →
   extmap → ILookup → default); `contains?` (declared OR extmap key); `keys`
   / `vals` (declared in order, then extmap); `count` (`field_count` + extmap
   size); `seq` rides `recordToMap`, which now appends extmap entries (so
   `first`/`rest` follow free).

6. **print** (`printTypedInstance`): emit extmap entries after the declared
   fields (`#R{:x 1, :y 2, :z 9}`). The `#R` vs clj's ns-qualified `#user.R`
   name remains a **separate** tracked divergence (D-058/D-079, the ns
   surface) — out of scope here.

7. **Equality + hash include extmap** (unlike `meta`). `typedInstanceEqual` /
   `typedInstanceKeyEq` compare extmap with the existing value `=` after the
   positional field zip (map `=` is order-independent; nil-normalization
   makes nil and empty agree). `typedInstanceHash` adds the extmap as **one
   separate term** `h *% 31 +% valueHash(extmap)` only when extmap is
   non-nil — `valueHash` on a map is already the order-independent HAMT
   content hash, so `(assoc r :a 1 :b 2)` and `(assoc r :b 2 :a 1)` hash
   equal (the DA's leading-finding hazard 1), and a record with no extras
   hashes exactly as before (no churn for the common case).

8. **`map->R` factory** (`macro_transforms.zig`): the generated body changes
   from `(Name. (get m :f1) …)` (extras dropped) to
   `(reduce-kv assoc (Name. (get m :f1) …) (dissoc m :f1 …))` — the positional
   ctor for declared fields, then the now-extmap-aware `assoc` folds the
   leftover keys. When `m` carries no extras the `dissoc` empties and
   `reduce-kv` no-ops.

9. **reify (`.reified_instance`) is untouched** — like meta, a fixed struct
   with no field tail; extmap is a defrecord capability only.

## Alternatives considered (Devil's-advocate, fresh-context subagent, verbatim)

**Verification of the draft's structural premise (confirmed against source).**
The `meta` field (ADR-0112/D-312) is a trailing `meta: Value = Value.nil_val`
on the `TypedInstance` extern struct, set to nil in `allocInstance`, threaded
explicitly in `allocInstanceMeta`, marked by a single line in
`traceTypedInstance`, and ignored by `typedInstanceEqual`/`typedInstanceHash`.
Adding a trailing `extmap: Value = .nil_val` is the structurally identical
move; the only deltas vs. `meta` are (a) extmap participates in equality/hash,
and (b) extmap is mutated through structural ops, not just `with-meta`. The
draft is sound at the storage layer. The alternatives below differ on *where
the declared/extmap split is resolved* and *how the equality invariant is
guaranteed*.

**Leading finding — the equality/hash normalization hazard is not fully
covered by "empty extmap → nil".** The draft's stated invariant ("an empty
extmap after dissoc must equal a freshly-minted record with nil extmap") is
necessary but **not sufficient** for F-011. Two deeper hazards:

1. **Hash must fold extmap order-independently.** `typedInstanceHash`
   (equal.zig L617-624) currently folds fields through a *positional*
   `h = h *% 31 +% valueHash(fv)` loop. Extmap is an unordered map:
   `(assoc r :a 1 :b 2)` and `(assoc r :b 2 :a 1)` are `=` and MUST hash
   equal, but the persistent map's internal iteration order is not guaranteed
   stable across construction paths. So extmap's hash contribution cannot
   reuse the positional fold — it must use the **order-independent map hash**
   (the same `hashUnordered`/commutative combiner clj uses for
   `IPersistentMap`), folded in *separately* from the positional field fold. A
   naive "append extmap to the field loop" silently produces order-dependent
   hashes that break the equal-implies-equal-hash contract. This is the
   genuine risk the draft underweights.

2. **`map->R` and `assoc` must agree on the declared/extmap partition.** If
   `(map->R {:x 1 :z 3})` puts `:z` in extmap but `(assoc (->R 1 nil) :z 3)`
   reaches a different code path that partitions differently (e.g. one treats
   a declared key written as nil as "present", the other as "absent"), then
   two records that are `=` under clj diverge. The partition rule (declared
   key → slot; everything else → extmap) must be applied at exactly **one**
   chokepoint, or equality drifts. This argues against the draft's "every op
   routes over declared-fields-then-extmap" if each op re-derives the
   partition independently.

Neither hazard requires violating an F-NNN; both are containable. They shape
which alternative is cleanest.

**Alternative 1 — Smallest-diff: extmap field + per-op routing as drafted,
hash via a separate unordered fold.** This is the draft, with the one
mandatory correction from the leading finding: `typedInstanceHash` gains a
separate `hashUnordered(extmap)` term (combined into `h` with the commutative
combiner clj uses), not a positional append; `typedInstanceEqual` compares
extmap via the existing map `=` after the positional field zip; both
short-circuit `extmap == nil` for the common no-extras record. Each structural
op (`assoc`/`dissoc`/`get`/`keys`/...) routes "declared? → slot : extmap"
inline.
- *Better than the draft as written*: nothing structurally — it IS the draft,
  plus the hash fix that the draft must adopt regardless.
- *Breaks*: the partition logic is duplicated across ~8 ops. Each duplication
  is an independent chance to diverge on the edge cases (a declared key
  explicitly assoc'd to nil; `dissoc` of a declared key — clj actually
  *cannot* dissoc a declared key and returns a plain map, a behaviour each op
  must independently remember). This is the **Smallest-diff bias smell**: it
  minimizes the field-layer diff while scattering the invariant. Per F-013,
  "is this key declared?" is a property of the *descriptor*, so deriving it
  inline in every op is a per-feature bolt-on rather than a definition-derived
  capability.

**Alternative 2 — Finished-form-clean: extmap field + a single
descriptor-owned partition chokepoint.** Same storage as the draft (trailing
`extmap: Value`, mirroring `meta`), but the declared/extmap split is resolved
in **one** place: a descriptor-level helper (e.g.
`TypeDescriptor.partitionKey(key) -> .declared(index) | .extra` and a paired
`assocKey`/`dissocKey`/`getKey` on the instance) that every op — `assoc`,
`dissoc`, `map->R`, `get`, `keys`, `vals`, `count`, `seq`, `print`, equality,
hash — calls. The descriptor already knows the declared field names (it must,
to construct `->R`), so the partition is *definition-derived* (F-013): a
record carries extmap and routes keys because it is a record over a known
field set, not because each op was taught the rule. The hash uses the separate
unordered fold (leading finding) inside the chokepoint, so it cannot be gotten
wrong per-op. `map->R` and `assoc` share the same `assocKey`, structurally
guaranteeing the Alternative-1-hazard-2 agreement.
- *Better than the draft*: the F-011 equality invariant and the F-013
  definition-derived property are both enforced by construction at one
  chokepoint, not re-asserted in 8 ops. The "declared key cannot be dissoc'd,
  returns a plain map" clj edge lives once. This is the finished-form per
  F-002 — the partition is the record's contract, expressed once.
- *Breaks*: nothing semantically; it is a larger diff than Alternative 1 (a
  new descriptor-level key-routing surface). Per F-002, diff size is
  explicitly not a constraint and must not downgrade this. The only real cost
  is that `print`/`seq` ordering (declared-fields-then-extmap) becomes a
  property of the chokepoint's iteration contract, which must be specified —
  but that is a clarification, not a breakage.

**Alternative 3 — Wildcard: no extmap field; an extended record is a distinct
value that delegates to a plain map.** Mirror clj's actual *observable*
contract differently: when a non-declared key is assoc'd, do **not** re-mint a
`TypedInstance` with extras — instead the declared fields plus extras are
projected and the result is represented as the record's declared slots
*backed by* a persistent array-map for the extras, reusing the existing map
machinery wholesale for everything extmap-related (iteration, `=`, hash,
`dissoc`, `get` on extra keys). Concretely: keep `TypedInstance` exactly as-is
(no new field), and store extras in a side representation reached through the
descriptor — but **not** a pointer-keyed side-table (that would violate F-006:
a pointer-keyed table that roots instances forever / needs finaliser hooks is
exactly the anti-pattern F-006 names). The only F-006-clean way to do this
without the extmap field is to make the "extended record" a *different
descriptor variant* or a wrapper Value that holds both the base instance and
the extras map as traced children.
- *Better than the draft*: maximal reuse of the existing persistent-map
  `=`/hash/iteration — the order-independent-hash hazard (leading finding) is
  solved for free because the extras genuinely *are* a map value. No new
  equality/hash code in `typedInstanceEqual` beyond "compare the extras map".
- *Breaks*: it needs either a new wrapper Value (an extended-record tag) —
  which **violates F-004** (a new value tag on the 64-slot NaN-box is
  expensive/constrained and explicitly not wanted) — or a second descriptor
  variant, which fragments "what is a record" and makes `(record? x)` /
  `instance?` / `=` between a plain and an extended instance of the same type
  harder to keep clj-faithful (they must still be `=` when fields+extras
  match). **This is the F-NNN-blocked option**: the cleanest form of the
  wildcard (a dedicated extended-record value) requires a new tag and is ruled
  out by F-004. The descriptor-variant fallback avoids the tag but
  re-introduces the partition-fragmentation that Alternative 2 exists to
  eliminate, landing strictly worse than Alternative 2 on F-013. Recorded here
  per the brief: the tag-based wildcard would be F-004-violating; do not
  pursue it.

**Recommendation (non-binding): Alternative 2 — the descriptor-owned
single-chokepoint partition, with extmap stored as the drafted trailing
`Value` field and hash folded via a separate unordered combiner.** It is the
finished-form-clean shape (F-002), makes the extmap capability
definition-derived (F-013), and structurally guarantees the F-011
equality/hash invariant that Alternative 1 scatters and that the
leading-finding hash hazard makes too easy to break per-op. The draft is
correct at the storage layer and should keep its `meta`-mirroring field; it
needs only to consolidate the per-op routing into one descriptor-level
chokepoint and adopt the separate unordered hash fold.

## Main-loop disposition: ACCEPT Alternative 2

The draft's storage layer (trailing `extmap: Value`, `meta`-mirroring) is
kept. The DA's **leading finding is adopted in full**: extmap hashes as one
separate `valueHash(extmap)` term (order-independent, since `valueHash` on a
map is the HAMT content hash), and the empty→nil normalization on dissoc is
the equality invariant. The DA's **Alternative 2 chokepoint is adopted** at
the granularity the existing code supports: the declared-field-slot lookup
duplicated across `recordFieldGet`/`assoc`/`contains?` is consolidated into
`TypeDescriptor.fieldSlotByName`, so the partition rule lives once;
`map->R` and `assoc` reach extmap through the same `assoc` path, so they
cannot disagree (hazard 2 closed structurally). Per-op *read shaping* (keys
returns a key list, count returns a size, print emits entries) necessarily
differs by op and is not forced into one function — what is unified is the
**partition predicate** + the shared `recordToMap` full-view that `seq`
already rides. Alternative 3 is rejected on the F-004 ground the DA gives (a
dedicated extended-record tag) and the F-013 ground (descriptor-variant
fragmentation). Cycle/diff size did not enter the choice (F-002).

## Consequences

- **Positive**: records become fully IPersistentMap-faithful (F-011/F-013):
  `assoc`/`dissoc`/`get`/`keys`/`vals`/`count`/`seq`/`print`/`=`/`hash` and
  `map->R` all honour extra keys. The two PROVISIONAL markers + D-086 close.
  The partition rule is defined once (`fieldSlotByName`).
- **Negative**: a non-declared `assoc`/`dissoc` re-mints (copies the field
  array, like `with-meta`) and now also carries an extmap map alloc — the
  irreducible cost of immutability, paid only when extras exist. A record with
  no extras is unchanged in layout cost (one extra nil `Value` slot,
  `meta`-equivalent) and hashes/compares exactly as before.

## Affected files

- `src/runtime/type_descriptor.zig` — `TypedInstance.extmap` field;
  `TypeDescriptor.fieldSlotByName`; `allocInstanceFull` (meta + extmap);
  `allocInstance`/`allocInstanceMeta` rewired through it; `traceTypedInstance`
  extmap-mark line; `instExtmapOf`; `instWithMeta` threads extmap.
- `src/lang/primitive/collection.zig` — `assocFn` (.typed_instance: extmap
  re-mint + multi-pair fold, PROVISIONAL raises removed); `dissocFn`
  (extmap dissoc + normalize-to-nil; declared-key demote folds extmap);
  `containsQFn`; `keysFn`; `valsFn`.
- `src/runtime/collection/lookup.zig` — `recordGet` consults extmap.
- `src/lang/primitive/sequence.zig` — `recordToMap` appends extmap;
  `countFn` record arm adds extmap size.
- `src/runtime/print.zig` — `printTypedInstance` emits extmap entries.
- `src/runtime/equal.zig` — `typedInstanceEqual` / `typedInstanceKeyEq` /
  `typedInstanceHash` include extmap.
- `src/lang/macro_transforms.zig` — `map->Name` threads leftover keys.
- `test/e2e/phase9_record_extmap.sh` (new) — clj-parity round-trips;
  `test/run_all.sh` wires it.
- `feature_deps.yaml` (`runtime/record_extmap` → landed) + `.dev/debt.yaml`
  (D-086 → discharged).
