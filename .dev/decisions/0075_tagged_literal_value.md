# ADR-0075 — Activate slot-24 `tagged_literal` as clojure.lang.TaggedLiteral

- Status: Accepted
- Date: 2026-06-02
- Supersedes: none
- Refs: D-200 (the reader-literal debt this completes a piece of), ADR-0073
  (reader infra + the `*default-data-reader-fn*` plumbing this reuses),
  ADR-0074 (which deferred this generic carrier), F-002 / F-004 / F-009.

## Context

ADR-0073 landed the tagged-literal reader infra (`#tag form` → data-reader
dispatch over `*data-readers*` / `*default-data-reader-fn*`, else raise
`reader_tag_unknown`). ADR-0074 landed `#uuid` as a real value and noted the
generic `tagged_literal` carrier — clj's `clojure.lang.TaggedLiteral` — as
"the correct SEPARATE mechanism for the unknown-tag FALLBACK, deferred."
This ADR is that piece: the `tagged-literal` value type + `tagged-literal?`.

clj's `TaggedLiteral` is a **fixed two-field class** (`tag: Symbol`,
`form: Object`) `implements ILookup` answering only `:tag`/`:form`:
`(tagged-literal 'foo 5)` → `(tagged-literal? t)`=true, `(:tag t)`=foo,
`(:form t)`=5, `(pr-str t)`=`#foo 5`, `=` by (tag, form),
`hashCode = 31*hash(tag)+hash(form)`. `*default-data-reader-fn*` defaults to
`nil` (so unknown tags throw) — this ADR does NOT change that default.

## Decision (DA Alt 2 — a dedicated slot-24 heap struct)

clj's TaggedLiteral is a fixed two-field class (NOT a deftype), so the
faithful finished form is a dedicated two-field Zig struct, not a `.clj`
deftype reusing `typed_instance` (which would drag the whole protocol stack
into the Layer-1 reader fallback and still hand-roll the print form).

1. **Value**: `runtime/tagged_literal.zig` heap carrier
   `extern struct { header, tag: Value, form: Value }` on the day-1-named
   slot `tagged_literal = 24`, modelled on `runtime/uuid.zig`. GC **trace**
   marks **both** `tag` and `form` (both are GC Values); **no finaliser**
   (nothing on `gc.infra`, unlike regex's payload / uuid's inline bytes).
2. **Constructors / predicate** (`clojure.core`): `tagged-literal`
   (2-arity, `[tag form]` — `tag` must be a symbol) + `tagged-literal?`
   (O(1) tag compare, not an `instance?` walk). Both Zig builtins, so the
   reader fallback (`liftTagged`'s `invokeReaderFn` builtin fast path) reaches
   them without the protocol stack being hot.
3. **ILookup-only** (NOT map-like — no assoc/keys/seq/count, matching clj):
   a dedicated `valAt(v, key, not_found)` in `tagged_literal.zig` answering
   `:tag`/`:form`/not-found, wired into the `get` + keyword-invoke path
   (`collection/lookup.zig`, the same single-source pattern `recordGet` uses
   for `typed_instance`).
4. **print** arm: `#` + tag pr-str + " " + form pr-str (→ `#foo 5`, EDN
   round-trips). **equal** arm: `=`(tag) ∧ `=`(form). **hash**:
   `31*hash(tag)+hash(form)` (match clj where observable).
5. **No change to ADR-0073's default unknown-tag-raises contract.** The
   carrier is reachable two clj-grounded ways: the `tagged-literal`
   constructor, and `(binding [*default-data-reader-fn* tagged-literal]
   (read-string "#unknown 5"))` — the existing plumbing already passes
   `(tag-symbol, form-value)` to the default fn.

### Slot allocation note (DA fact-correction)

Slot 24 is NOT the last reserved slot (Group B/C/D carry unwired declared
entries — `reader_conditional`=25, `host_instance`=29, `reified_instance` —
plus D-043 anonymous reserves). So this is NOT scarcity-driven and NOT
Reservation-as-bias: the justification is "clj has a distinct fixed-shape
TaggedLiteral value and cljw wants the faithful analogue," not "the slot
exists, fill it." Activating a day-1-named slot is WITHIN F-004's 64-slot
shape (the loop's call); the shape is unchanged (no F-004 amendment).
`#inst`/Date (D-200's remaining piece) does NOT need a fresh slot — its
natural cljw home is `host_instance` (a `java.util` class).

## Consequences

- `(tagged-literal 'foo 5)` / `(tagged-literal? x)` / `(:tag x)` / `(:form x)`
  / `(pr-str …)` → `#foo 5` / `=` by (tag, form) — clj-parity.
- `(binding [*default-data-reader-fn* tagged-literal] (read-string "#x 5"))`
  carries unknown tags instead of raising (opt-in; default still raises).
- `reader_conditional` (slot 25) is the sibling reader-support carrier; a
  `.cljc`-gated follow-up (tracked in D-200's remaining notes) co-designs it.

## Affected files

- `src/runtime/value/value.zig` / `heap_tag.zig` (slot 24 already named; wire
  the value behaviour).
- `src/runtime/tagged_literal.zig` (new — carrier + valAt + trace + GC hooks).
- `src/runtime/runtime.zig` (registerGcHooks).
- `src/runtime/print.zig` (print arm), `src/runtime/equal.zig` (equal + hash),
  `src/runtime/collection/lookup.zig` (`.tagged_literal` ILookup arm).
- `src/lang/primitive/core.zig` (or a peer): `tagged-literal` / `tagged-literal?`.
- Tests: `test/e2e/phase14_tagged_literal.sh` (+cases) + a unit test.

## Alternatives considered

(Verbatim from the mandatory Devil's-advocate subagent, fresh context, within
the F-NNN envelope. The Decision adopts Alt 2 with all fact-corrections.)

### Fact corrections the draft absorbed (verified against source)

1. **"Slot 24 is the ONLY reserved-but-unused slot left" is false.**
   `heap_tag.zig` shows `tagged_literal = 24` is a *named day-1 entry* in
   Group B (B8, between `regex` B7 and `reader_conditional` B9). The header
   still lists `reader_conditional`, `reified_instance`, `host_instance` as
   declared-but-unwired, and D-043 tracks anonymous reserves. Claiming slot 24
   does not exhaust the space; the "last slot" urgency evaporates — the
   decision rests on feature value, not scarcity.
2. **`tagged-literal` is NOT a deftype in clj** — it is
   `clojure.lang.TaggedLiteral`, a hand-written class `implements ILookup`
   with two fields, `valAt` returning only `:tag`/`:form`/notFound, structural
   `equals` (tag+form), `hashCode = 31*hash(tag)+hash(form)`. Print is `#` +
   tag + space + form (NOT `#<tag-name>`; the draft's print arm was wrong).
3. **`*default-data-reader-fn*` defaults to `nil`** → unknown tag throws. The
   draft's "no contract change to ADR-0073's raise" is correct — confirmed.

### Alternative 1 — smallest-diff: reuse `typed_instance` (define `TaggedLiteral` as a deftype in `lang/clj/`)

Don't touch slot 24. Define a `(deftype TaggedLiteral [tag form] ILookup …)`
in bootstrap `.clj` + `tagged-literal`/`tagged-literal?` over it; `(:tag t)`/
`(:form t)` ride the already-wired `recordGet` declared-field path.

**Better:** Near-zero Zig — no new heap struct, trace, print/equal/hash arms,
or ILookup wiring (the `typed_instance` paths exist + are tested). F-009-clean
by construction.

**Breaks:** (1) The Layer-1 reader fallback (`liftTagged`) calls
`*default-data-reader-fn*` at analyze time; a deftype-backed `tagged-literal`
lives in Layer-2 `.clj`, reachable only via `rt.vtable.callFn` — works, but
makes the fallback depend on the whole protocol stack being live, a heavier
prerequisite than a Zig primitive. (2) deftype default print is
`#user.TaggedLiteral{…}` unless you wire a print-method — so you still
hand-roll the `#tag form` print, just in `.clj`. (3) `=`/`tagged-literal?`
correctness depends on deftype's structural-equality + `instance?` wiring.
**Anti-Reservation-as-bias** (its strongest argument): refuses to claim slot
24 just because the enum names it.

### Alternative 2 — finished-form-clean (RECOMMENDED): dedicated slot-24 heap struct

The draft, corrected: `runtime/tagged_literal.zig` `{header, tag: Value,
form: Value}` on slot 24, modelled on uuid.zig (trace marks **both** fields,
**no finaliser** since both are GC Values). `tagged-literal`/`tagged-literal?`
builtins. ILookup via a dedicated `valAt`. Print `#` + tag + " " + form;
equal (tag,form); hash `31*hash(tag)+hash(form)`.

**Better:** (1) Matches clj's actual representation — a fixed two-field class,
not a deftype; the Zig struct is the faithful analogue. (2) The Layer-1 reader
fallback needs no Layer-2 dependency (`tagged-literal` as a builtin takes
`invokeReaderFn`'s `.builtin_fn` fast path), the cleaner bootstrap story.
(3) `tagged-literal?` is O(1), not an `instance?` walk. (4) Self-contained
(~40 lines of arms, grep-discoverable by keyword per `feature_name_consistency`).

**Breaks:** (1) Permanently spends slot 24 — but per fact-correction #1 slots
are not scarce, so the cost is small. (2) ILookup wiring is 2 call-sites (the
keyword-invoke branch ends `else => unreachable`, only `typed_instance` is
special-cased) — route `.tagged_literal` through a dedicated `valAt`. (3) Mild
shape-overlap with `reader_conditional` (slot 25, also a small Value-field
carrier) — but clj keeps them distinct classes, so clj-parity argues for two.
**(b) Minimal ILookup surface:** answer ONLY `:tag`/`:form`/notFound (clj's
`valAt`); do NOT make it map-like (no assoc/keys/seq) — that would be
divergence-creating over-reach.

### Alternative 3 — wildcard: defer entirely; transient stub, claim no slot now

Leave `tagged-literal`/`tagged-literal?` raising `feature_not_supported`
(permitted transient stub); file a debt row scheduled to co-implement with
`reader_conditional` (slot 25) in one big-bang push (per `clj_diff_sweep.md`
Discipline 2) when `.cljc` lands.

**Better:** Avoids spending a slot on a feature with (arguably) no current
consumer; co-designs both reader-support carriers coherently; honours the
Micro-coverage-grind warning.

**Breaks:** (1) Leaves a `feature_not_supported` stub on core-since-1.7 fns
(`tagged-literal`/`tagged-literal?`) — a visible hole. (2) The "no consumer"
claim is weak — EDN round-trip of unknown tags via `*default-data-reader-fn*
tagged-literal` is a real defensive-config idiom; deferring keeps a
`clj_diff_sweep` DIFF open. (3) `.cljc`/reader-conditional may be many Phases
out; binding `tagged_literal`'s fate to it defers a cheap, useful, clj-grounded
type — a Progress-by-coupling risk.

### Recommendation (DA)

**Alt 2 (dedicated slot-24 struct)** with all fact-corrections. clj's
TaggedLiteral is a fixed two-field class, so the dedicated struct is the
faithful finished form; Alt 1's deftype reuse is the smaller-diff convenience
the finished-form owner would unwind (protocol-stack dependency in the
Layer-1 fallback + hand-rolled print). The slot cost is not the scarcity the
draft claimed. Alt 3's defer loses on the weak "no consumer" claim + the open
clj-parity DIFF; if honouring big-bang, the better move is Alt 2 now + note
the slot-25 `reader_conditional` sibling for a future co-design. Corrections
that MUST land: print is `#`+tag+" "+form (no angle brackets); ILookup-only
(`:tag`/`:form`); hash `31*hash(tag)+hash(form)`; trace marks both fields, no
finaliser. No F-NNN is violated (activating a day-1-named slot is within
F-004's shape).
