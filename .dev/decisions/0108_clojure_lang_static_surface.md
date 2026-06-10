# 0108 — `clojure.lang.*` host-static surface tree (clojure.lang.Util)

- **Status**: Accepted
- **Date**: 2026-06-07
- **Phase**: Phase 14 (post-v0.1.0 coverage) — Convergence Campaign Stage 1.3 (library ladder)
- **Amends**: ADR-0029 (surface layout adds a third tree)
- **Tags**: phase-14, host, interop, clojure-lang, surface, ladder, F-013

## Context

The real-world pure-Clojure library ladder (Stage 1.3) finds that
data-structure libraries drop to `clojure.lang.*` runtime internals for
static helpers: `(clojure.lang.Util/hash x)` (data.finger-tree:405),
`(clojure.lang.Util/equiv …)`, `(clojure.lang.RT/count …)`, etc. A grep of
the official corpus shows ~95 `Util`/`RT` static call sites (Util/equiv 24×,
Util/isInteger 21×, Util/hash 14×, RT/map 12×, Util/hasheq 10×, Util/equals
10×, …). cljw has NO `clojure.lang.*` surface, so these error
`No namespace: 'clojure.lang.Util'`.

cljw already has the host-surface mechanism (ADR-0029): a `___HOST_EXTENSION`
with `cljw_ns` + a `TypeDescriptor` whose `method_table` maps method names to
`BuiltinFn`s. Static dispatch resolves `(Class/method …)` via
`resolveJavaSurface(head)` → `rt.types.get(head)` then
`rt.types.get("cljw." ++ head)`. A surface registered as `cljw.clojure.lang.Util`
therefore makes `(clojure.lang.Util/method …)` resolve with no resolver change.

But ADR-0029 established only TWO surface trees — `runtime/java/**`
(`cljw.java.*`) and `runtime/cljw/**` (`cljw.*`). `clojure.lang.*` is the JVM
Clojure runtime's internal namespace: neither `java.*` nor cljw-original. This
ADR adds a third tree.

## Decision

1. **A new `src/runtime/clojure/lang/` surface tree** mirrors the JVM package,
   registered under `cljw.clojure.lang.*`. First member: `Util.zig`
   (`cljw_ns = "cljw.clojure.lang.Util"`). This is the finished-form placement
   (DA Alt 2) — an honest package mirror, not the `runtime/java/lang/Util.zig`
   category-lie (DA Alt 1) where the `cljw_ns` string and the directory would
   contradict each other.

2. **Scope = the `clojure.lang.Util` class's pure public statics only**
   (F-013 definition-derived; the class is a closed, enumerable API). `RT`,
   `Numbers`, `APersistentMap` are separate definition-derived big-bang units
   (debt rows), NOT crammed in here. The Tier-D statics (`loadWithClass`,
   classloader/reflection) are excluded.

3. **Method mapping (oracle-verified 2026-06-07):**

   | Util static      | cljw impl                      | oracle parity                                                                                                                                                                         |
   |------------------|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
   | `equiv(a,b)`     | `=` (equal.zig)                | ✓ `(equiv 1 1.0)`→false = cljw `=` (both category-strict, F-005)                                                                                                                    |
   | `identical(a,b)` | `identical?`                   | ✓ `(identical 1 1)`→true (small-int immediates)                                                                                                                                     |
   | `compare(a,b)`   | `compare`                      | ✓ nil-least: `(compare nil 1)`→-1, `(compare nil nil)`→0                                                                                                                           |
   | `isInteger(x)`   | `integer?`                     | ✓ Long/BigInt; **F-005 divergence** on cljw-absent Short/Byte (`(short 5)` is a cljw Long → true; clj false) → AD                                                                  |
   | `hash(x)`        | cljw hash                      | **AD-009** (cljw-native hash; intra-cljw consistency only)                                                                                                                            |
   | `hasheq(x)`      | cljw hash                      | **AD-009** (same)                                                                                                                                                                     |
   | `classOf(x)`     | `class`                        | ✓ `(classOf 5)`→Long                                                                                                                                                                |
   | `equals(a,b)`    | **custom** same-type-and-value | clj `(equals 1 1N)`→false (Java `.equals`, type-sensitive); cljw `.equals`/`=` both →true, so a faithful `equals` needs an explicit same-descriptor-AND-value check, NOT a fn alias |
   | `pcequiv(a,b)`   | `=`                            | persistent-collection equiv = `=`                                                                                                                                                     |
   | `hashCombine`    | `hash.zig` Murmur3 combine     | AD-009 (intra-cljw)                                                                                                                                                                   |
   | `isPrimitive(c)` | `false`                        | cljw has no primitive Classes (F-005/ADR-0059)                                                                                                                                        |

   `equiv`'s long/double/char/boolean overloads collapse to the `Object,Object`
   form (F-005: no primitive specialization).

4. **Gate amendments (Alt 2 is incomplete without them — the zone/marker gates
   hardcode `runtime/java/*` + `runtime/cljw/*`):**
   - `scripts/zone_check.sh`: add `runtime/clojure/*` to the surface whitelist
     AND a D2 arm forbidding `runtime/clojure/* → runtime/java/* | runtime/cljw/*`
     (the three surface trees all reach the shared neutral impl, never each other).
   - `_host_api`: a `runtime/clojure/_host_api.zig` aggregator (or extend the
     single `installAll`) lists the new surface.
   - `.claude/rules/feature_name_consistency.md`: extend the scan set to
     `runtime/clojure/**` + the `Backend:` marker convention — **CARRY-OVER**
     (the auto-mode classifier blocks `.claude/rules/*` edits; surface to the
     user). Enforcement is the scripts (editable); the `.md` is doc-accuracy.

## Alternatives considered

_Devil's-advocate subagent output (fresh context), verbatim:_

> **Pre-note on a factual error in the draft brief:** the brief cited AD-006 for
> the cljw-native-hash divergence; the correct anchor is **AD-009** (AD-006 is
> `Double/parseDouble`). Corrected throughout this ADR.
>
> **Alt 1 — Smallest-diff: `Util.zig` under `runtime/java/lang/`.** Better: zero
> new wiring — drops into the existing `installAll` next to `Math.zig`;
> `cljw_ns = "cljw.clojure.lang.Util"` resolves via the existing
> `rt.types.get("cljw." ++ head)` fallback; the zone gate + feature_name gate
> already cover `runtime/java/*` for free. Breaks: category lie — `clojure.lang.*`
> is not `java.*`; a `clojure.lang.Util` file physically in `runtime/java/lang/`
> next to `java.lang.Math` is exactly the smallest-diff convenience F-002 forbids;
> the `cljw_ns` string says `clojure.lang.Util` while the directory says `java/lang`
> — self-contradictory metadata.
>
> **Alt 2 — Finished-form: new `runtime/clojure/lang/` tree + aggregator
> (RECOMMENDED).** Better: honest package mirroring; scales to the inevitable
> `clojure.lang.RT`/`Numbers`/`APersistentMap`; the cljw_ns/directory/FQCN triple
> is internally consistent. Breaks/hidden cost the brief understates: the zone gate
> and consistency gate HARDCODE `runtime/java/*` + `runtime/cljw/*` — a third tree
> is invisible to G1, so `runtime/clojure/lang/Util.zig` could import from
> `runtime/java/**` with no gate complaint, silently violating ADR-0029 D2. So Alt 2
> is incomplete unless it ALSO amends both gates to admit a third surface root (and
> decides `runtime/clojure/**` may NOT import the other surface trees). This is an
> ADR-0029 amendment, mandatory not optional. Per F-002 the size is irrelevant.
>
> **Alt 3 — Wildcard: flat FQCN-keyed host-static registry, tree-independent.**
> Better: decouples "internal runtime helper class" surfaces from directory layout;
> one registry serves Util/RT/Numbers without three directories. Breaks: a second,
> parallel dispatch mechanism competing with ADR-0029's `TypeDescriptor`/`method_table`
> — a fork in the surface model; loses the per-file `Backend:` marker + the neutral-impl
> zone discipline the file-tree gates enforce. Trades a category-lie for an un-gated
> escape hatch. Rejected.
>
> **Recommendation: Alt 2**, citing F-002 (finished-form wins; the new tree + the two
> gate amendments are the honest shape, LOC is not a constraint). Alt 1's category lie
> is the smallest-diff bias the project forbids; Alt 3 forks the dispatch model. The ADR
> must scope-in the `zone_check.sh` + `feature_name_consistency.md` amendments to
> recognize `runtime/clojure/**` as a third surface root.
>
> **Method-mapping correctness (flag-before-ship):** cljw `=` is category-gated, which
> the brief's draft mappings handle correctly for `equiv` (both category-strict → match)
> but NOT for `equals`: `Util/equals` is Java `.equals` (type-sensitive),
> `(Util/equals 1 1N)`→false, must NOT alias to cljw `=`/`.equals` (both →true) — needs a
> same-type-AND-value check, oracle-pinned. `Util/identical`→`identical?` safe for small
> ints but probe boxed Longs. `Util/isInteger` differs on cljw-absent Short/Byte (F-005) →
> AD. `Util/compare` confirm nil-least. `hashCombine` only matters intra-cljw under AD-009.
>
> **`Util/hash`/`hasheq` under AD-009: acceptable** — AD-009's contract is intra-cljw
> consistency (equal values hash equal — the HAMT key contract); libs call `Util/hash` to
> BUILD their own runtime structures, which is all they need. The one corruption vector is a
> lib shipping a precomputed JVM hash constant and asserting against it — pre-existing AD-009
> surface, does not block; add a corpus pin `(= (Util/hash :a) (hash :a))` and never claim
> cross-runtime hash stability.
>
> **Scope (F-013): one class (Util) is the correct definition-derived unit** — a real,
> enumerable JVM class with a closed public-static API. NOT "all of clojure.lang statics"
> (RT alone has ~200, mostly Tier-D) — forcing RT+APersistentMap in would be the opposite
> F-013 failure (ad-hoc "make finger-tree pass"). Land Util's complete pure set now, build
> the tree + gate amendments now (next class = pure file-add), record RT/Numbers/APersistentMap
> as separate big-bang debt rows.
>
> **Gate-amendment checklist:** `zone_check.sh` add `runtime/clojure/*` whitelist + a D2 arm
> forbidding `runtime/clojure/* → runtime/java/* | runtime/cljw/*`;
> `feature_name_consistency.md` extend the scan set + Backend-marker convention; `_host_api`
> aggregate the new tree (hand-maintained enumeration must list `Util`).

## Consequences

- `(clojure.lang.Util/method …)` resolves for the pure statics; data.finger-tree
  advances past :405. Broadly unblocks corpus libs that drop to `Util` internals.
- A third surface tree exists; future `clojure.lang.*` classes are pure file-adds
  + an aggregator line + (if a new sub-namespace) a zone whitelist row.
- `Util/hash`/`Util/hasheq` inherit AD-009 (cljw-native hash). A new AD records
  the `Util/isInteger` Short/Byte F-005 divergence. `equals` ships faithful
  (same-type-and-value), oracle-pinned in the corpus.
- The `feature_name_consistency.md` scan-set update is a tracked carry-over until
  the user lands it; the new tree carries the `Backend:` marker regardless.

## Amendment 1 — APersistentMap / APersistentSet / Murmur3 (D-375, 2026-06-10)

The "next class = pure file-add" path promised above is exercised. Custom-collection
libraries (flatland.ordered, data.avl, gvec, tech.ml.dataset) call clojure.lang
abstract-collection STATIC hash/equality helpers from their deftype hashCode/hasheq/
equals bodies. flatland.ordered.map:123 `(hashCode [this] (APersistentMap/mapHash this))`
errored `No namespace: 'APersistentMap'`. Definition-derived closed set (F-013) across
three real clojure.lang classes:

- **`clojure.lang.APersistentMap`** statics: `mapHash`, `mapHasheq`, `mapEquals`.
- **`clojure.lang.APersistentSet`** static: `setEquals` (JVM has NO `setHash` static —
  hashCode/hasheq are instance methods; inventing a `setHash` would be the 個別最適化 trap).
- **`clojure.lang.Murmur3`** statics: `hashOrdered`, `hashUnordered`, `mixCollHash` —
  thin wrappers; `hashOrdered`/`hashUnordered` delegate to the existing
  `clojure.core/hash-ordered-coll`/`hash-unordered-coll` (the same coll-fold), `mixCollHash`
  to `runtime/hash.zig::mixCollHash` (byte-for-byte JVM Murmur3, already verified).

Wiring per the gate-amendment checklist (all already in place from the base ADR): 3 new
`runtime/clojure/lang/*.zig` surface files mirroring `Util.zig` + 3 `@import` lines in
`_host_api.zig::clojure_surfaces` + a neutral rt+env-taking helper in `runtime/coll_hash.zig`
(iterates a map-like via the `rt.vtable.callFn`→`clojure.core/seq` callback, the confirmed
`java/util/Iterator.zig` pattern, so it works on a native map AND a deftype instance) +
`compat_tiers.yaml` entries. zone_check / resolver unchanged.

### The one design choice: `mapHash` return value (DA-fork, depth-2)

cljw collapsed the JVM's two-hash split (additive Object.hashCode vs Murmur hasheq) into a
SINGLE value-hash: `Util/hash` and `Util/hasheq` both route to `equal.valueHash`, and
`(.hashCode native-map)` = `(hash native-map)` = `map.contentHash` (mixCollHash-finalized).
So `mapHash` and `mapHasheq` return the SAME cljw content hash over the seq'd entries
(matching an `=`-equal native map's `.hashCode`), NOT JVM's additive `sum(keyHash ^ valHash)`.
This is the AD-009/F-011 choice: intra-cljw equal-maps-equal-hash beats JVM-bit-parity (which
is unobservable and impossible since cljw hashes strings UTF-8). The neutral helper REUSES
the `entryHash` + order-independent `+%` + single `mixCollHash` fold `map.contentHash` uses
(fast-path native maps to `contentHash` directly; seq-walk for deftype instances).

### Alternatives considered (Devil's-advocate, fresh context — verbatim)

> **Fresh-context grounding:** cljw has ONE value-hash — `Util/hash` (Java hashCode) and
> `Util/hasheq` (Clojure hasheq) BOTH route to `equal.valueHash`; `valueHash` of a map →
> `map.contentHash` = `mixCollHash(Σ entryHash(k,v), count)` (order-independent, then
> mix-finalized). The JVM's additive-vs-murmur duality has no cljw counterpart.
>
> **Alt 1 — JVM-shape-additive** (`Σ keyHash ^ valHash`, not finalized): closest to the
> JVM source text. **Fatal:** `(.hashCode native-map)` in cljw IS finalized contentHash, so
> an additive mapHash returns a different integer → `(= (.hashCode om) (.hashCode
> equal-native-map))` is FALSE — the exact invariant the lib wired the call to preserve.
> Ports the unobservable JVM internal shape (AD-009) while breaking the observable collision
> contract (F-011). VIOLATES F-011.
>
> **Alt 2 — cljw-consistent** (return cljw's `contentHash`-equivalent, mix-finalized, over
> the seq'd entries): makes both `(.hashCode om)` and `(hash om)` agree with an equal native
> map within cljw. Honours cljw's "one value-hash" architecture. Risk: the helper MUST reuse
> the identical `entryHash`+`mixCollHash` fold (don't re-derive) or OrderedMap silently
> mis-collides. FULLY COMPLIANT (F-011 observable contract; AD-009; F-002).
>
> **Alt 3 — route the instance through universal `(hash …)` dispatch**: maximal
> commonization. **Fatal circularity:** `valueHash` on a `.typed_instance` hits the
> defrecord-fields hash or the deftype identity bit-hash, NEITHER equal to the native map's
> content hash — and the lib overrides hashCode *because* the default instance hash is wrong
> for a collection, so routing back re-introduces the wrong hash. VIOLATES F-011.
>
> **RECOMMENDATION: Alt 2.** The libs wire `(APersistentMap/mapHash this)` into hashCode for
> ONE observable reason — a custom map collides with an `=`-equal native map inside the
> runtime. cljw collapsed the two-hash split into one finalized `valueHash`/`contentHash`, so
> mapHash must return that same finalized value over the seq'd entries, reusing the native
> fold. Alt 1's JVM-shape fidelity is unobservable (AD-009) and trades against the observable
> contract (Smallest-diff bias). **mapHash and mapHasheq return the SAME value in cljw** —
> forced, not stylistic: cljw has one hash notion (Util/hash and Util/hasheq both → valueHash),
> so a single OrderedMap reporting two different hashes from hashCode vs hasheq would break
> the collision contract on one path. Preserving the JVM additive/murmur distinction here
> would be Reservation-as-bias (obeying the JVM shape because it is "the named algorithm").

Main loop adopts **Alt 2** verbatim.

### Out of scope (filed as debt, NOT this unit)

- **D-376** — `Murmur3/hashUnencodedChars` (2 sites, data.xml): hashes UTF-16 code units;
  cljw `hashString` hashes UTF-8 (WASM/edge choice). Defer.
- **D-377** — cross-impl map-hash consistency: `(hash map)` (= `contentHash`, per-entry
  `vh(k)*31+vh(v)`) ≠ `(hash-unordered-coll map)` (= `collHash`, per-entry the map_entry-as-
  vector hash), whereas clj keeps them equal. A deftype map whose `hasheq` uses
  `hash-unordered-coll` therefore will not `(hash)`-collide with a native map. Plus the
  deeper gap that `(hash deftype-inst)` does not consult the deftype's own `hasheq`/IHashEq
  impl (it returns the identity bit-hash). Both are a hash-consistency campaign affecting all
  map hashes (corpus regen), distinct from adding the static surfaces. mapHash here is
  unaffected (it computes contentHash directly).
