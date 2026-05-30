# ADR-0059 — `class` / `type` return an interned `.type_descriptor` Value

- **Status**: Accepted
- **Date**: 2026-05-31
- **Phase**: Phase 14 (post-v0.1.0 coverage) / cluster A26
- **Supersedes**: —
- **Superseded by**: —

## Context

`(class x)` and `(type x)` were absent (`name_error`, verified 3x).
They are extremely common clojure.core surface (`(group-by class
coll)`, `(condp = (type x) …)`, multimethod dispatch on `class`), so
the quality loop (F-010) needs them. The representation is a
**load-bearing, user-observable decision** — what value `class`
returns governs its print form, its `=` behaviour, and whether it is
a valid map key — so it rides an ADR with a Devil's-advocate fork.

cljw has **no JVM Class**. The substrate it does have:

1. A `.type_descriptor` Value tag (28, already in the F-004 NaN-box
   layout) wrapping a `*const TypeDescriptor` via a `TypeDescriptorRef`
   heap object (`type_descriptor.zig:171`).
2. Native types reach a descriptor through `rt.nativeDescriptor(tag)`
   (`runtime.zig:190`), which caches one descriptor per Tag and
   populates a clean `fqcn` via `nativeFqcnFor` (`runtime.zig:214`:
   `.integer → "Long"`, `.float → "Double"`, `.string → "String"`,
   `.vector → "PersistentVector"`, `.nil → "nil"`, …).
3. `(rt/__native-type :integer)` already maps a tag-keyword to that
   `.type_descriptor` Value; `defrecord`/`deftype` already bind their
   name Var to a `.type_descriptor` Value; `instance?` / `extends?` /
   `satisfies?` already all speak `TypeDescriptor` / `.td_ptr`.

So a type representation **already exists and is already wired into
the type-system machinery**. The cw-v0 precedent went the other way:
`class` and `type` were the *same* function returning a **keyword**
(`:integer`), Class was dropped entirely, and `(class nil)` → `:nil`.
v0 could afford the keyword shape because v0 had no protocol/instance
dispatch to compose with; cw v2 does. A keyword-as-class cannot carry
a method table, cannot be told apart from a user keyword `:Long`, and
does not compose with `instance?`/`extends?`/`satisfies?`. That is the
load-bearing reason v2 diverges from v0 on all three points — not
"changed our minds".

**The load-bearing sub-problem — `=` / hash / print.** Today a
`.type_descriptor` Value:

- prints as the generic placeholder `#<type_descriptor>`
  (`print.zig:208` `else => "#<{s}>"`).
- has **no** equality arm: `valueEqual` (`equal.zig:271-276`) and the
  HAMT key path fall to bit-identity / `else => false`, and
  `valueHash` (`equal.zig:217`) falls to `else =>
  hash.hashLong(@bitCast(@intFromEnum(v)))` (hashes the wrapper bits).
- is minted **fresh per call** by `makeTypeDescriptorRef` (a new
  `TypeDescriptorRef` heap object each time), even though the
  underlying `*TypeDescriptor` is interned (native: cached per-Tag;
  user: registered once).

Consequence: today `(= (class 5) (class 6))` is **false** and `(class
5)` is broken as a map key, because two fresh wrappers carry different
NaN-box bits. JVM returns the interned `java.lang.Long` Class
(identity == equality), so `(= (class 5) (class 6))` is true and
`(group-by class coll)` works. Shipping `class` with broken equality
would be a **representation-divergence defect** (structural-defect
class #4 in `structural_defect_hunting.md`) — not acceptable per
F-002. So the finished form must fix identity/equality, not just add
a wrapper.

## Decision

Adopt **Alt 2 (finished-form-clean)** from the Devil's-advocate fork.

1. **`(class x)` returns the existing `.type_descriptor` Value**
   (Candidate A — one representation for native + user types,
   composing with the already-wired `instance?`/`extends?`/`satisfies?`/
   `__native-type` machinery). `(class nil)` → `nil` (JVM semantics).
   typed_instance / reified_instance carry their own descriptor; every
   other value consults `rt.nativeDescriptor(v.tag())`. New primitive
   `rt/__class` (Layer 1, in `protocol.zig` next to `nativeType`);
   `.clj` wrapper `(def class (fn* [x] (rt/__class x)))`.

2. **`(type x)` = `(or (:type (meta x)) (class x))`** — a pure `.clj`
   wrapper. This **un-collapses** v0's `class`==`type` so `type`
   honours `:type` metadata (JVM semantics), the one place `type`
   legitimately differs from `class`.

3. **Interning is a correctness invariant, not an opportunistic
   cache** (the DA's sharpening of A1). `makeTypeDescriptorRef`
   becomes the sole minting site and **always returns one canonical
   boxed Value per descriptor**: it caches the wrapper in a new
   `ref_cache: ?Value = null` field on `TypeDescriptor`, returning the
   cached Value on every subsequent call. Two `(class 5)` calls then
   return the **bit-identical** Value, so identity equality holds
   automatically in `valueEqual` **and** the HAMT `keyEqValue` **and**
   `valueHash` — `.type_descriptor` joins the interned-singleton family
   (keyword / symbol / primitives), and `equal.zig` is **not touched**.
   `(= (class p) Point)` works because `defrecord`'s `Point` and
   `(class p)` resolve to the same cached wrapper. The cached ref is
   `rt.gc.infra`-allocated (process-lifetime, never GC-collected) and
   the descriptor is per-Runtime, so the cache never dangles and needs
   no GC trace edge; a one-line invariant comment at
   `makeTypeDescriptorRef` records that bit-equality ⇔ same descriptor,
   so a future refactor cannot quietly add a non-interned minting path.

4. **Print** adds a `.type_descriptor` arm to `print.zig` printing
   `td.fqcn` (simple name `Long`, not JVM FQCN `java.lang.Long`, per
   the no-JVM-assumption rule). Per the DA, the **simple-name-vs-FQCN
   choice is scoped as separable**: the arm prints whatever
   `nativeFqcnFor` policy yields; revisiting FQCN is an independent
   print-policy decision, not re-litigating class identity.

**Rejected — Alt 1 (A2 equality+hash arms, keep fresh wrappers):**
correct and shippable, and its explicitness (a visible
`.type_descriptor => a.td_ptr == b.td_ptr` arm) is a genuine virtue,
but it permanently complicates `equal.zig`'s equality/hash contract
with a **3-way sync liability** (valueEqual + keyEqValue + valueHash
must stay mutually consistent forever) and **invalidates** the
"bit-identity is contract-consistent for every non-string key"
invariant comment (`equal.zig:213`) — when interning is available and
makes all of that unnecessary. Its only edge over Alt 2 (no cache
field → no GC-reachability question) dissolves once Alt 2 documents
the infra-lifetime reasoning. Per F-002 the smaller blast-radius in
`makeTypeDescriptorRef` is a bits-today convenience, not a
finished-form gain.

**Rejected — Alt 3 (dedicated `.class` NaN-box tag):** redundant
representation. `.type_descriptor` already models "a type"; a `.class`
tag forces either deleting `.type_descriptor`'s user role (a much
larger surgery) or a cross-tag equality arm (worse than Alt 1). It
re-breaks the native+user unification that is the decision's core
virtue and spends a finite F-004 reserve slot on a speculative
need (reservation-as-bias). F-004's own challenge text predicts this
verdict.

## Alternatives considered

The following is the Devil's-advocate subagent's verbatim output
(fresh context, briefed with the F-NNN envelope + the
`equal.zig`/`print.zig`/`type_descriptor.zig` file:line facts +
the A1-vs-A2 sub-decision):

> ## Devil's-advocate: Alternatives considered (ADR-0059)
>
> **F-NNN gate result up front:** None of the three alternatives below requires violating an F-NNN. The finished-form-clean option (Alt 2) sits entirely inside the F-004 layout (reuses tag 28, no new tag) and inside F-009's carve-out (it edits `type_descriptor.zig` / `equal.zig` / `print.zig`, all language-core, explicitly out of F-009 scope). So there is **no "leading entry" forced disclosure** of an F-NNN block — the clean shape is reachable. The interesting tension is entirely *within* the envelope: A1 (intern) vs A2 (equality arms), and simple-name vs FQCN print, neither of which any F-NNN decides.
>
> ---
>
> ### Alternative 1 — Smallest-diff: A2 equality+hash arms, keep fresh wrappers (the draft's explicitly-rejected sub-option), simple-name print
>
> Keep `makeTypeDescriptorRef` minting a fresh ref per call. Add three `.type_descriptor` arms — one in `valueEqual` (equal.zig:271, the same-tag switch), one in `keyEqValue`, one in `valueHash` (equal.zig:217) — each dereferencing `.td_ptr` and comparing/hashing the *underlying* `*const TypeDescriptor` pointer (which IS interned: native via `rt.native_descriptors[idx]` runtime.zig:181/206, user via the registry). Print arm prints `td.fqcn`.
>
> **What it does better than the draft (A1):**
> - Does not introduce a cache field (`ref_cache: ?Value`) onto `TypeDescriptor`, so it does not add a GC-reachability question ("is the cached wrapper Value traced, or does it dangle if GC moves/frees?"). A1's cache field is a *new* live Value reference held by a runtime-core struct; Alt 1 holds zero new Values, sidestepping that analysis entirely.
> - The equality is *semantically explicit*: a reader of `valueEqual` sees a `.type_descriptor => a.td_ptr == b.td_ptr` arm and immediately knows "two type descriptors are equal iff same underlying descriptor". A1's equality is *implicit* — it works only because two calls happen to return bit-identical wrappers, a fact that lives in `makeTypeDescriptorRef`'s memoization, three files away from `valueEqual`. The invariant is "spooky action at a distance".
> - Robust against any *future* code path that mints a non-interned wrapper. If Phase-N code ever constructs a `TypeDescriptorRef` by a path that bypasses the cache (e.g. a deserializer, a reify fast-path, a `with-meta` on a class), A1 silently breaks `=` again (two valid wrappers for one descriptor → unequal); Alt 1 stays correct because it compares the payload, not the box.
>
> **What it breaks / risks:**
> - The draft's stated objection is real and load-bearing: `valueHash`'s own docstring (equal.zig:208-216) warns `keyEqValue(a,b) ⇒ valueHash(a) == valueHash(b)` must hold, and Alt 1 now has **three** arms (valueEqual, keyEqValue, valueHash) that must stay mutually consistent forever. The hash arm must hash `@intFromPtr(td_ptr)` while both equality arms compare `td_ptr` — a future edit to one without the others reintroduces a HAMT corruption (key present but unfindable). This is exactly the maintenance hazard the draft cites.
> - It does *not* shrink the surface — it grows `equal.zig`, a runtime-core hot file, by three arms in two functions whose comment block (equal.zig:208-216) explicitly enumerates "the ONLY branch needing care is `.string`". Alt 1 makes that comment false: now `.type_descriptor` also needs care. The comment must be rewritten, and the "bit-identity is contract-consistent for every non-string key" invariant (equal.zig:213) is now violated by a second tag.
> - It is a smallest-diff-against-current-bits choice, not a smallest-diff-against-finished-form choice: it optimizes "don't touch `makeTypeDescriptorRef`" at the cost of "permanently complicate the equality/hash contract".
>
> **Explicit answers:**
> - (a) unify native+user types? **Yes** — both go through `.type_descriptor` / `.td_ptr`, same as the draft.
> - (b) `(= (class 5) (class 6))` true? **Yes** — both wrappers' `.td_ptr` point at the single interned `native_descriptors[@intFromEnum(.integer)]` descriptor, so the new `valueEqual` arm returns true.
> - (c) class-as-map-key / `(group-by class coll)` work? **Yes** — the `valueHash` arm hashes `td_ptr` and the `keyEqValue` arm compares `td_ptr`, consistently, so the HAMT finds the key. (Conditional on the three arms staying in sync — the standing risk.)
> - (d) `(class 5)` prints as? **`Long`** (simple name, `td.fqcn` via nativeFqcnFor).
> - (e) composes with instance?/extends?/satisfies?? **Yes** — those already speak `TypeDescriptor` / `.td_ptr`, unchanged.
> - (f) reusable-precedent quality: **Medium-low.** The "add an equality+hash arm per heap-payload tag" pattern is a real precedent (`.vector` already did it, equal.zig:225/233 vectorHash + keyEqValue vector arm), so it is not unprecedented. But each such arm is a standing 3-way-sync liability, and the draft is right that the codebase should prefer *interning so bit-identity just works* over *adding payload-comparison arms* wherever interning is feasible. Vector keys can't be interned (infinitely many); type descriptors *can* (finite, already interned at the descriptor level). So the vector precedent does not transfer — type descriptors are the case where A1 is available and A2 is the inferior copy.
>
> ---
>
> ### Alternative 2 — Finished-form-clean: A1 intern-the-wrapper (the draft) BUT make interning a structural invariant of `makeTypeDescriptorRef`, not an opportunistic cache; FQCN-faithful print deferred to a print-policy decision
>
> This is the draft's A1, sharpened. The draft frames A1 as "memoize one `TypeDescriptorRef` Value per `TypeDescriptor` (e.g. a `ref_cache: ?Value` field, filled on first `makeTypeDescriptorRef`)". The finished-form-clean version makes the *non-existence of a non-interned path* the invariant: `makeTypeDescriptorRef` becomes the sole minting site and **always** returns the cached wrapper (allocating + caching on first call, returning the cache thereafter), and `asTypeDescriptorRef` / any other consumer never constructs a fresh ref. The cache field is documented as "the canonical boxed identity of this descriptor", and a `comptime`/debug assertion or a one-line invariant comment records that two `.type_descriptor` Values are bit-equal iff same descriptor — so the equality/hash contract is upheld *by construction at the box layer*, and `equal.zig` is genuinely never touched (the draft's central claim).
>
> **What it does better than the draft-as-written:**
> - The draft says "cache it, e.g. a `ref_cache` field". The word "e.g." and the framing "memoize on first call" leave it as an *optimization* ("we cache to avoid re-allocating"). The finished-form framing is stronger: interning is a *correctness invariant*, not a perf optimization. This matters because an optimization can be "optimized away" by a later well-meaning refactor (someone adds a `makeFreshTypeDescriptorRef` fast-path for a reify hot loop and silently breaks `=`), whereas an invariant with an assertion catches that at the door. The draft's A1 is correct but under-specified on *why the bits stay identical forever*; Alt 2 closes that gap.
> - It keeps `equal.zig`'s "bit-identity is contract-consistent for every non-string key" invariant (equal.zig:213) **literally true** — type descriptors join nil/bool/int/char/keyword/symbol as "interned, so bit-identity = value-identity". This is the cleanest possible finished form for the equality contract: the comment block at equal.zig:208-216 needs *zero* edits, because `.type_descriptor` is now genuinely in the "bit-identity-compared, hashing raw bits is contract-consistent" bucket. That is a strictly better finished state than Alt 1, which *invalidates* that comment.
> - It generalizes: interning the box is the same shape the codebase *already chose* for keyword and symbol (interned → identity equality → no equal.zig arm). A reader who understands why `(= :a :a)` needs no keyword arm in valueEqual immediately understands why `(class 5)` needs no type_descriptor arm. One mental model, reused. This is the highest-precedent-quality outcome.
>
> **What it breaks / risks:**
> - The cache field adds a Value held by a `TypeDescriptor` (which lives on `rt.gc.infra`, process-lifetime per runtime.zig:194/196 + the type_descriptor.zig:167 docstring "process-lifetime"). Since both the descriptor and the ref are infra-allocated and process-lifetime, the cached Value never dangles — but this must be *verified and stated*, not assumed. The draft does not currently note the GC-reachability reasoning; Alt 2 requires the ADR to record "cache holds an infra-allocated, process-lifetime, never-collected ref, so no trace edge is needed." If cw's GC ever moves infra objects, this invariant needs revisiting (low risk — infra is explicitly the non-moving arena).
> - The print question is *orthogonal and under-decided*. The draft picks simple-name (`Long`) via existing `nativeFqcnFor`. The no-JVM-assumption rule (`no_jvm_specific_assumption.md`) says cljw is not a JVM reimplementation, which the draft reads as license to diverge to simple names. But that rule cuts *both* ways: it argues against *assuming JVM class hierarchy*, not specifically for *simple names over FQCN*. JVM Clojure's `(pr-str (class 5))` → `java.lang.Long`; cw printing `Long` is a *visible round-trip divergence* that `(group-by class coll)` users will see in their output. Alt 2's position: the print *representation* is a separable decision from the *identity/equality* decision, and bundling them into one ADR risks locking simple-name print prematurely. Recommend the ADR explicitly scope print to "prints `td.fqcn`; whether fqcn is `Long` or `java.lang.Long` is the existing `nativeFqcnFor` policy, revisitable independently" rather than ratifying simple-name as a class-identity decision.
> - Bigger diff than Alt 1? No — it is essentially the same diff as the draft's A1 (cache field + print arm), plus an invariant comment/assertion and a tightened `makeTypeDescriptorRef`. The "expansion" is documentation and a guard, not code volume. Per F-002, even if it *were* larger, that is not a reason to prefer Alt 1.
>
> **Explicit answers:**
> - (a) unify native+user types? **Yes** — identical to the draft; one `.type_descriptor` representation for both.
> - (b) `(= (class 5) (class 6))` true? **Yes** — both calls return the bit-identical cached wrapper for the interned integer descriptor; `valueEqual`'s identity fast-path (equal.zig:247, `@intFromEnum(a) == @intFromEnum(b)`) returns true with zero new code.
> - (c) class-as-map-key / `(group-by class coll)` work? **Yes** — bit-identity means `keyEqValue` hits identity and `valueHash`'s `else => hash.hashLong(@bitCast(@intFromEnum(v)))` (equal.zig:226) hashes the *same* bits for both, so the HAMT contract holds automatically. No new hash arm, no sync liability.
> - (d) `(class 5)` prints as? **`Long`** with the draft's choice — but Alt 2 flags this as a separable print-policy decision, recommending the ADR not bind it as identity-load-bearing.
> - (e) composes with instance?/extends?/satisfies?? **Yes** — unchanged; they speak `.td_ptr`.
> - (f) reusable-precedent quality: **High — the highest of the three.** "Intern the box so bit-identity = value-identity, and add no equal.zig arm" is the exact precedent already set by keyword/symbol/interned-primitives. It reuses one mental model, leaves the equality contract's invariant comment literally true, and makes the next interned-singleton type (future: namespace objects? interned class hierarchy nodes?) follow the same recipe.
>
> ---
>
> ### Alternative 3 — Wildcard: a dedicated `class` tag (new NaN-box tag in F-004's Group B reserve), with print/equality/hash native to that tag, `.type_descriptor` retained only as the *internal* descriptor pointer
>
> Mint a fresh `.class` Value tag (consuming one of F-004's ~10 Group-B reserved slots) whose payload is the interned `*const TypeDescriptor` directly (no intermediate `TypeDescriptorRef` heap object — the tag *is* the boxed class). `(class x)` returns a `.class`-tagged Value; `.type_descriptor` / `TypeDescriptorRef` stays an internal-only thing the protocol/instance machinery uses, never user-visible. The new tag gets its own print arm (`Long` or `java.lang.Long`), and equality/hash via interned-pointer identity (same bit-identity story as Alt 2, because the interned descriptor pointer is the payload).
>
> **What it does better than the draft:**
> - *Separation of "the user-facing Class value" from "the internal descriptor reference."* Today `.type_descriptor` is overloaded: it is simultaneously what `__native-type` returns internally, what `defrecord`'s `Point` resolves to, what `instance?` consumes, *and* (post-draft) what `(class x)` returns to user code. A dedicated `.class` tag would let the user-facing surface (print as a class, equal as a class) evolve independently of the internal descriptor-reference plumbing. If cw ever wants `(class x)` to carry user-visible class metadata (a `getName` method, a `(supers c)` hierarchy walk) that the *internal* descriptor reference should not carry, the tag split is the seam for it.
> - Eliminates the `TypeDescriptorRef` heap indirection for the class value entirely — the tag NaN-boxes the `*const TypeDescriptor` pointer directly, one fewer allocation and one fewer pointer-chase than even Alt 2's cached ref. (Whether this matters perf-wise is unmeasured and almost certainly negligible.)
>
> **What it breaks / risks:**
> - **This is redundant representation, and F-002 weighs against it.** F-004 explicitly invites the challenge: "minting a fresh `class` tag when `.type_descriptor` already models 'a type' should be justified against F-002 (would it be a cleaner finished form, or redundant representation?)." The honest answer: it is **redundant**. `.type_descriptor` *already* models "a type"; `defrecord`'s `Point`, `__native-type`, `instance?`, `extends?`, `satisfies?` already all speak it. A `.class` tag would mean `(= Point (class p))` requires either (i) `Point` also becomes `.class`-tagged (then `.type_descriptor` has no remaining user-facing role and should be deleted, a much bigger surgery) or (ii) a cross-tag equality arm `.class == .type_descriptor when same td_ptr` (reintroducing the exact equal.zig arm-maintenance hazard Alt 2 avoids, now *worse* because it is cross-tag). Both outcomes are strictly less clean than Alt 2's single-representation finished form.
> - The hypothetical motivation ("class value evolves independently of internal descriptor reference") is **speculative** — there is no current requirement for `(class x)` to carry anything the descriptor reference doesn't. Building the seam now is a reservation-as-bias smell (`.dev/principle.md`): consuming an F-004 reserve slot for a need that does not materialize. F-004's reserve is finite (~10); spending one here on speculation is the kind of "memo, not contract" the project spirit warns against.
> - It consciously *re-breaks the unification* the draft's whole thesis rests on. The draft's load-bearing virtue is "UNIFIES native + user types under one representation and composes with existing instance?/extends?/satisfies?". Alt 3 *splits* the representation, then has to *re-bridge* it. That is motion away from the finished form, not toward it.
>
> **Explicit answers:**
> - (a) unify native+user types? **Partially / awkwardly** — both native and user classes would be `.class`-tagged, so *as classes* they unify; but the class representation is now *split from* the descriptor representation that `instance?`/`defrecord` use, requiring a bridge. Net: less unified than the draft.
> - (b) `(= (class 5) (class 6))` true? **Yes** — both `.class` values box the same interned integer descriptor pointer; bit-identity holds.
> - (c) class-as-map-key / `(group-by class coll)` work? **Yes** — interned-pointer payload → bit-identity → HAMT contract holds, same mechanism as Alt 2.
> - (d) `(class 5)` prints as? **Free choice** — a dedicated tag gets a dedicated print arm, so `Long` or `java.lang.Long` is equally easy. (This is the one genuine degree of freedom the tag buys, and it is also achievable in Alt 2 by choosing the print arm's format.)
> - (e) composes with instance?/extends?/satisfies?? **Worse** — those speak `.type_descriptor` / `.td_ptr` today; a `.class` tag forces either a conversion at every boundary or a dual-tag acceptance in each of those functions. The draft/Alt-2 single-tag approach composes for free; Alt 3 adds friction at exactly the composition points the draft cites as its strength.
> - (f) reusable-precedent quality: **Low.** "Spend an F-004 reserve slot to split a user-facing view from its already-existing internal representation, then re-bridge them" is a precedent the project should *not* want repeated — it is the redundant-representation anti-pattern F-004's own challenge text anticipates.
>
> ---
>
> ### Non-binding ranked recommendation
>
> 1. **Alt 2 (finished-form-clean A1: interning as a structural invariant, not an opportunistic cache; print-policy scoped as separable).** This is the draft's chosen direction, sharpened. It is the cleanest finished form: type descriptors join the interned-singleton family (keyword/symbol/primitives), `equal.zig`'s invariant comment stays literally true with zero edits, the equality/hash contract is upheld by construction at the box layer, and it reuses one mental model the codebase already teaches. The two things the draft should *add* (not change): (i) frame the cache as a correctness invariant with a one-line guard/assertion + a recorded GC-reachability note (infra-allocated, process-lifetime, never collected), so a future refactor cannot quietly add a non-interned minting path; (ii) explicitly scope the print decision as "prints `td.fqcn`; simple-name-vs-FQCN is the existing `nativeFqcnFor` policy, revisitable independently" so the ADR does not over-commit on print while deciding identity.
>
> 2. **Alt 1 (A2 equality+hash arms).** Correct and would ship, and its *explicitness* virtue is genuine — but it permanently complicates `equal.zig`'s equality/hash contract with a 3-way sync liability and *invalidates* the "bit-identity is contract-consistent for every non-string key" invariant comment, when interning is available and makes all of that unnecessary. The draft is right to reject it. Its only edge over Alt 2 (no cache field → no GC-reachability question) is dissolved by Alt 2 documenting that reasoning. Per F-002, the slightly-smaller-blast-radius-in-`makeTypeDescriptorRef` is a *bits-today* convenience, not a finished-form gain.
>
> 3. **Alt 3 (dedicated `class` tag).** Rejected. F-004's own challenge text predicts the verdict: it is redundant representation. It consumes a finite reserve slot for a speculative need, re-breaks the unification that is the draft's core virtue, and forces either a much larger surgery (delete `.type_descriptor`'s user role) or a worse cross-tag equality arm than Alt 1. The seam it builds (user-class-view independent of internal-descriptor-ref) has no current requirement — reservation-as-bias.
>
> **One cross-cutting flag for the ADR regardless of choice:** the cw-v0 precedent (`class`==`type`, returns a keyword `:integer`, `(class nil)`→`:nil`, no Class) that the draft consciously breaks on all three points is the *right* break — a keyword-as-class loses identity-as-a-type (you can't distinguish `(class 5)` the class from the keyword `:Long` someone might type), can't carry method tables, and doesn't compose with `instance?`. The ADR should record that the v0 keyword approach was rejected *because it cannot compose with the protocol/instance machinery that already exists in v2* (which v0 lacked), not merely "we changed our minds" — that is the load-bearing reason the divergence from v0 is finished-form-correct rather than churn.

The main loop adopts the DA's recommendation (Alt 2) unchanged,
including both sharpening additions (interning-as-invariant +
print-policy-scoped-separable) and the cross-cutting v0-divergence
rationale.

## Consequences

- **Positive**: `class` / `type` work and compose with the existing
  type system. `(= (class 5) (class 6))` is true; `(class 5)` is a
  valid map key, so `(group-by class coll)` works. `.type_descriptor`
  joins the interned-singleton family — `equal.zig`'s "bit-identity is
  contract-consistent for every non-string key" invariant stays
  literally true, no equality/hash arm added. Interning also removes
  the per-call `TypeDescriptorRef` allocation (one ref per descriptor,
  reused). Sets the reusable precedent "intern the box so bit-identity
  = value-identity" for future singleton types.
- **DIVERGENCE from JVM**: `(class 5)` prints `Long`, not
  `java.lang.Long` (no-JVM rule). `(class nil)` → `nil` (matches JVM).
  Print form is a separable `nativeFqcnFor` policy, revisitable.
- **DIVERGENCE from cw-v0**: v0's keyword-returning `class`==`type` is
  rejected because a keyword cannot compose with the v2
  protocol/instance machinery (carry a method table, be told apart
  from a user keyword) — the load-bearing reason, not a mind-change.
- **Negative / watch**: `ref_cache` is a per-descriptor `?Value`
  written through `@constCast` (logical-const memoization, mirroring
  `extendType`'s existing `@constCast`). Valid because descriptors are
  per-Runtime and infra-allocated (process-lifetime, never GC-moved);
  a future GC that moves infra objects would need to revisit this.

## Affected files

- `src/runtime/type_descriptor.zig` — `ref_cache: ?Value = null` field
  on `TypeDescriptor`; `makeTypeDescriptorRef` interns (cache-or-mint)
  with the invariant comment.
- `src/runtime/print.zig` — `.type_descriptor` arm printing `td.fqcn`.
- `src/lang/primitive/protocol.zig` — `rt/__class` primitive +
  registration + unit tests.
- `src/lang/clj/clojure/core.clj` — `class` / `type` wrappers.
- `test/e2e/` — `class` / `type` surface cases.
- `.dev/handover.md` — verified-gap list updated.
