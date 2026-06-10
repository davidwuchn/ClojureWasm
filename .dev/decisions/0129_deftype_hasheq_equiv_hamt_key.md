# ADR-0129 — deftype/reify `hasheq` + `equiv` participate in HAMT key bucketing & comparison (D-377 facet 2)

- Status: Proposed → Accepted (2026-06-10)
- Related: D-377 (the driving debt — facets 1 + `=`/facet 3 landed; this is
  facet 2), ADR-0127 (the `active_consult` thread-local precedent this mirrors),
  ADR-0119 (`treeWalkCall` = the single both-backend call choke point this arms),
  ADR-0110 (the `valueHash` interned-cache arms this completes), D-280d1/d5 (the
  `(hash x)` primitive's inline hasheq dispatch this commonizes), D-151 (the
  `keyEq` residual comment this closes), F-002 / F-011 / F-013 (finished-form +
  commonization + definition-derived coverage), F-005.
- Drives D-377 facet 2 toward discharge; opens a deferred perf row (lazy
  hasheq cache).

## Context

cljw maps/sets use a HAMT. Key **bucketing-hash** and within-bucket
**key-equality** are computed by two rt-FREE functions in `equal.zig`:
`valueHash(v) u32` (bucketing) and `keyEqValue(a, b) bool` (compare). "rt-free"
= no `*Runtime`/`*Env`, so neither can dispatch a user `deftype`/`reify`
instance's `Object/hasheq` or `Object/equiv` method (dispatch needs the
per-Runtime vtable + an Env). For a non-record deftype/reify `valueHash`
returns the identity bit-hash and `keyEqValue` compares identity.

Measured on a ReleaseSafe binary (2026-06-10):

- `(hash (->Box 1))` with custom `hasheq`→12345 ⟹ **12345** — the `(hash x)`
  PRIMITIVE (`core.hashFn`) already dispatches `Object/hasheq`→`hashCode` for
  typed/reified instances (D-280d1/d5). So the top-level `(hash deftype)` was
  NOT the gap.
- `#{(->Box 1) (->Box 2)}` (hasheq const 7, equiv true) ⟹ **2** (clj 1 — no
  dedup; the SET key path uses neither the deftype's hash nor its equiv).
- `(get {(->Box 1) :a} (->Box 9))` (hasheq 7, equiv true) ⟹ **nil** (clj `:a` —
  the map-key path dispatches neither hash nor equiv).

So the real gap: a `deftype`/`reify` with a custom `hasheq`+`equiv` used as a
**map key / set element** does not bucket or dedup against an `=`-equal value,
breaking the `(= a b) ⟹ (= (hash a) (hash b))` contract for mixed
deftype/native keys & elements. Real driver: flatland.ordered.map LOADS and
`(= ordered-map native)` is true (the `=`/facet-3 `instanceEquiv` landed last
session), but `#{om nm}` does not dedup and `(contains? #{om} nm)` is false.

User directive (2026-06-10): **take it あるべき論 — wide blast radius is OK,
but NO ad-hoc; a proper fix of cljw's hash architecture.** F-013 forbids a
"just make flatland pass" patch; the fix must be definition-derived and raise
the system one level (any deftype with `hasheq`/`equiv` works as a key).

### Architecture facts (verified this session)

1. `dispatch.current_env: ?*Env` is a thread-local whose doc says "The Env
   currently being evaluated. Set on call entry, cleared on exit … needed in
   low-level callbacks where env isn't otherwise in scope" — but it is set
   ONLY in a unit test, NEVER in production. It is dormant, half-built code for
   exactly this purpose. `Env.rt` reaches the Runtime.
2. `driver.evalForm` is the single per-top-level-form eval entry (both
   backends). `tree_walk.treeWalkCall` is the single value-producing call
   choke point for BOTH backends (`evalCall`→`vt.callFn`; VM `op_call`→
   `vt.callFn`; ADR-0119). Arming `current_env` at these two sites makes it set
   during ALL evaluation (the top-level-form window + every nested call).
3. ADR-0127 precedent: native-collection printing consults a deftype's
   `print-method` via a dedicated armed thread-local (`print.active_consult`,
   armed at the print boundary, gated on an override dirty flag). The hash/equiv
   problem is the same shape (a Layer-0 rt-free routine must dispatch a user
   method mid-evaluation) — but its arming locus is eval-time, not print-time
   (print runs at the REPL boundary AFTER eval returns), so the two contexts
   stay distinct.
4. `map.keyEq` (map.zig:134) is the single local wrapper every within-bucket /
   array-map compare delegates to; its doc already names this residual
   ("Collection / ratio / big_int keys stay identity-compared … the recursive
   `=` … needs `rt`, which the ~68 map call sites lack"). The bucketing-hash
   sites inline `equal.valueHash(k)`.

## Decision

**Revive `current_env` as the ambient eval-env, and add Layer-0 rt-aware
consult wrappers that the HAMT key sites use; commonize the `(hash x)`
primitive onto the shared dispatch core.**

1. **Arm `dispatch.current_env`** (save→set→`defer` restore) at
   `driver.evalForm` AND `tree_walk.treeWalkCall`. This completes the TL's
   documented-but-unwired intent; `current_env` is now the Env currently being
   evaluated, available to Layer-0 callbacks. Null outside evaluation
   (bootstrap / host-init) ⇒ consult falls to the rt-free path (safe — those
   paths never build custom-hash deftype-keyed maps).

2. **Shared dispatch core in `equal.zig`**: `hashDispatch(rt, env, v) u32` =
   non-record typed/reified instance with an `Object/hasheq` impl → dispatch it
   (then `hashCode`), truncate to u32; else `valueHash(v)`. The `(hash x)`
   primitive (`core.hashFn`) is refactored to call this (F-011 — it currently
   inlines the identical dispatch). The equiv core already exists as
   `instanceEquiv` (left-operand asymmetric, clj-exact — ADR/D-377 facet 3).

3. **Layer-0 consult wrappers** (read `current_env` → its `.rt`):
   `equal.hashConsult(v) u32` = armed + custom-hash deftype → `hashDispatch`;
   else `valueHash(v)`. `equal.eqConsult(a, b) bool` = armed → `instanceEquiv`
   consult ahead of `keyEqValue`; else `keyEqValue(a, b)`.

4. **Wire the HAMT**: a new `map.keyHash(k)` wrapper → `equal.hashConsult`,
   used at the bucketing-hash sites (hamtGet/Contains/Assoc/Dissoc + the
   assoc-split / array-map→hamt rehash of EXISTING keys); `map.keyEq` →
   `equal.eqConsult`. set.zig delegates to map, so it is covered. The map's own
   recursive content-hash sites (`contentHash` / `entryHash`) stay on
   `valueHash` (the nested-deftype-in-a-collection-key residual, shared with the
   existing `(hash x)` primitive residual).

5. **Defer the perf cache** (a lazy per-instance `hasheq` cache so a collection
   deftype does not recompute its O(size) content-hash on every bucket op). It
   is a PERFORMANCE optimization, not a correctness requirement — correctness
   here comes from arming coverage (every deftype-key hash/compare runs under
   `evalForm`/`treeWalkCall`). Tracked as a new debt/optimization row; landed
   later under F-010's perf window. Eager-at-construction caching was rejected
   precisely because it makes building an N-entry ordered-map O(N²).

### Residuals (documented, not silent)

- **Nested deftype inside a collection that is itself a key** hashes rt-free
  (the recursive `valueHash`/`contentHash` walk has no `current_env` hook) —
  shared with the existing `(hash x)` primitive residual; the top-level
  deftype key is the common case.
- **equiv asymmetry**: `eqConsult` consults the left/stored operand's `equiv`
  (matching cljw `=` / clj `Util.equiv`). Whether `#{om nm}` and `#{nm om}`
  both dedup is decided against the live `clj` oracle during implementation
  (F-011), and any accepted asymmetry is pinned as an AD-NNN.

### Why this shape (vs. the alternatives below)

It reaches behavioural equivalence with `clj` for the verification targets
(`#{om nm}`→1, `(contains? #{om} nm)`→true) by completing a mechanism the
codebase already half-built (`current_env`) rather than minting a third
thread-local; it commonizes the `(hash x)` dispatch (F-011); and it keeps the
correctness/perf concerns separate (arming for correctness, a deferred cache
for perf) so the landed diff is the minimum that is *correct and clean*, not a
perf-coupled rewrite. It does not touch the working print path (ADR-0127).

## Consequences

- `current_env` becomes load-bearing: a future backend/eval entry that produces
  values must arm it (or the F-012 dual-backend oracle catches the asymmetry).
  Anchored with a comment at both arm sites.
- A per-call thread-local pointer write at `treeWalkCall` (+ per-form at
  `evalForm`). Negligible; F-010 defers optimization. The deferred lazy cache
  removes the bigger O(size)-per-bucket-op cost when it lands.
- `equal.zig` gains `hashDispatch` / `hashConsult` / `eqConsult`; `map.zig`
  gains `keyHash` and routes `keyEq` to `eqConsult`. `core.hashFn` shrinks
  (shares `hashDispatch`).

## Affected files

- `src/runtime/dispatch.zig` — `current_env` doc updated to "live".
- `src/eval/driver.zig` (`evalForm`) + `src/eval/backend/tree_walk.zig`
  (`treeWalkCall`) — arm/restore `current_env`.
- `src/runtime/equal.zig` — `hashDispatch` / `hashConsult` / `eqConsult`.
- `src/runtime/collection/map.zig` — `keyHash` wrapper; bucketing sites →
  `keyHash`; `keyEq` → `eqConsult`.
- `src/lang/primitive/core.zig` — `hashFn` shares `hashDispatch`.
- `test/e2e/phase14_deftype_key_hash.sh` (new) + a unit/diff case.
- `.dev/debt.yaml` (D-377 facet 2 status; new deferred perf row), handover.

## Alternatives considered

The mandatory Devil's-advocate fork (general-purpose, fresh context, briefed
with the F-NNN envelope) returned the following verbatim:

> ### Leading finding on F-NNN
> None of the three alternatives below requires violating an F-NNN. All reach
> behavioural equivalence with `clj` for the verification targets (`#{om nm}` →
> 1, `(contains? #{om} nm)` → true) within F-002/F-011/F-013. The proposed
> design and all three alternatives are F-compliant; the choice is purely about
> which reaches the cleanest finished form.
>
> ### Alternative 1 — SMALLEST-DIFF: dedicated thread-local armed at `treeWalkCall`, no `current_env` revival
> Mirror ADR-0127's `active_consult` exactly. Add `equal.hash_consult: ?struct
> { rt, env }` (a thread-local local to `equal.zig`), armed/restored at the
> single `treeWalkCall` entry — and only there, because vm.zig:418 confirms the
> VM's value-producing call already funnels through `vt.callFn =
> &tree_walk.treeWalkCall`. Gate the arming on a dirty flag ("any deftype with a
> non-default `Object/hasheq`-or-`equiv` impl is registered globally"), exactly
> as `print.zig` gates on a registered non-default `print-method`.
> `hashConsult`/`eqConsult` read this TL; `valueHash`/`keyEqValue` stay rt-free
> fallbacks.
> - Better than proposed: Does NOT revive the dormant `current_env` as a
>   general-purpose mechanism — `current_env` is a tempting but unbounded
>   surface ("any low-level callback can now reach rt/env"), and reviving it
>   invites future code to depend on it implicitly. A purpose-named
>   `equal.hash_consult` is the narrowest correct surface and directly
>   precedented by ADR-0127. The dirty-flag gate means the common/bootstrap path
>   pays zero per-call TL write — proposed design arms `current_env`
>   unconditionally at every `treeWalkCall`, a per-call write on the hottest
>   path in the interpreter, which F-010 tolerates but is gratuitous when a
>   dirty flag makes it free.
> - Breaks / costs: It is a second consult thread-local with the same shape as
>   `print.zig`'s — two near-identical armed-TL mechanisms is a DRY smell
>   (F-011) the proposed design partly avoids by reusing one `current_env`. The
>   honest finished form would extract a shared "armed rt/env consult" helper
>   (see Alt 2). Also, arming only at `treeWalkCall` is correct ONLY while the
>   VM has no independent value-producing call path; if a future Phase gives the
>   VM its own inline `apply` that bypasses `vt.callFn`, the arming site silently
>   goes stale (the F-012 dual-backend oracle catches the resulting asymmetry,
>   but as a gate failure, not by construction).
>
> ### Alternative 2 — FINISHED-FORM-CLEAN: one unified "evaluation consult context" TL, shared by print + hash + equiv (F-011 commonization)
> The finished form recognises that print-method consult (ADR-0127), hash
> consult, and equiv consult are the same problem: a Layer-0 rt-free routine
> that, mid-evaluation, must dispatch a user method on a deftype and therefore
> needs the ambient `{rt, env}`. Introduce ONE canonical mechanism —
> `runtime/eval_consult.zig` (or fold into `dispatch.zig`) — exposing `armed:
> ?struct { rt, env }`, `arm(rt, env) → token` / `disarm(token)`, and a single
> per-feature dirty flag set. Arm it once at `treeWalkCall`. `print.zig`'s
> `active_consult`, `equal.hashConsult`, and `equal.eqConsult` all read this ONE
> context. Retire `dispatch.current_env` (the dormant half-built version of
> exactly this) and retire `print.active_consult` (its feature-specific
> predecessor), folding both into the unified surface. The `(hash x)`
> primitive's inline hasheq/hashCode dispatch also routes through `hashConsult`.
> - Better than proposed AND Alt 1: This is the F-011 finished form. Today the
>   codebase will end up with `current_env` (dormant), `print.active_consult`
>   (live), and a new hash/equiv TL — three thread-locals expressing one
>   concept, drifting independently. Unifying them is the "raise the system one
>   level" outcome F-013 demands: the next Layer-0-needs-rt consumer (a future
>   user-defined `compare` for sorted-map keys, or `toString` consult) plugs
>   into the existing armed context for free instead of minting TL #4. It also
>   resolves the proposed design's ambiguity about where to arm by making "the
>   single value-producing call entry" the canonical, documented, one-and-only
>   arm site.
> - Breaks / costs: Widest blast radius — it rewrites `print.zig`'s consult
>   wiring (a working, gated mechanism) and deletes `current_env`, touching the
>   print path's gate-covered behaviour. Per F-002 this rework is a feature, not
>   a cost, and per the user's 2026-06-10 directive it is squarely in scope. The
>   genuine risk is correctness regression in printing while refactoring a path
>   the proposed design leaves untouched — must be driven by the existing print
>   e2e/diff corpus staying green. The arming-site staleness hazard from Alt 1
>   remains (single arm site assumes VM has no independent value-producing
>   call), but now it is centralized and documented in one place with a
>   `GC-ROOT`-style anchor comment.
>
> ### Alternative 3 — WILDCARD: cache the deftype instance's hasheq at construction (rt-free hash), keep equiv dispatch via the armed TL
> Attack the asymmetry the consistency question raises. Hash can be made rt-free
> by caching: when a deftype/reify instance with a custom `Object/hasheq` is
> constructed (construction already runs under evaluation, so rt/env are in
> scope), dispatch hasheq once and store the resulting `u32` in a `hasheq_cache`
> slot on `TypedInstance`/`ReifiedInstance`. Then `valueHash`'s `.typed_instance`
> arm reads `inst.hasheq_cache` with NO rt/env — staying genuinely rt-free,
> exactly as the existing `.symbol`/`.keyword`/`.big_int` arms cache or derive
> their hash without dispatch. Equiv cannot be cached (equality is binary,
> between two values), so the within-bucket key compare still needs the armed-TL
> `eqConsult` — but equiv is consulted far less often than hash (only on a hash
> collision within a bucket).
> - Better than proposed: Directly eliminates the consistency hazard —
>   "inserted while armed (rt-aware hash) but looked up while unarmed (rt-free
>   hash) → mismatch → key lost." With a construction-time cache, an instance's
>   hash is the SAME value forever regardless of whether any TL is armed at
>   insert vs lookup. In the proposed/Alt-1/Alt-2 designs, a deftype key whose
>   hasheq is consulted at `assoc` time but NOT at a later `get` (because that
>   `get` ran outside `treeWalkCall` — e.g. a host-internal `map.get` during GC
>   trace, REPL result rendering, or a native reduce) buckets inconsistently and
>   silently loses the key. Caching makes the hash a property of the value,
>   which is what `clj`'s `IHashEq` contract semantically is (`hasheq()` is
>   idempotent per instance). It also keeps `valueHash` honestly rt-free.
> - Breaks / costs: (1) Adds a field to every deftype/reify instance (memory + a
>   construction-time dispatch even for instances never used as keys — though
>   gated on "has custom hasheq impl"). (2) Does not solve equiv — the
>   within-bucket compare STILL needs rt/env, so you still build the armed-TL
>   mechanism for `eqConsult`, meaning this is additive to Alt 1/2, not a
>   replacement. (3) The equiv side reintroduces a narrower version of the same
>   consistency hazard. (4) Caching at construction assumes the fields a custom
>   `hasheq` reads are immutable post-construction — true for deftype; a `reify`
>   closing over a mutable atom could compute a time-varying hasheq; clj has the
>   identical latent issue, so this is an accepted edge, worth an AD-NNN if
>   pursued.
>
> ### Overall recommendation (non-binding)
> Alt 2 (unified evaluation-consult TL) is the finished-form-clean choice and
> the one I recommend on F-011/F-013/F-002 grounds, with Alt 3's
> construction-time hasheq cache folded in as the hash-side representation —
> they are complementary, not competing. The strongest single finding is that
> the codebase is heading toward three thread-locals for one concept; the
> proposed design reduces this to two by reusing `current_env`, but
> `current_env` is an unbounded surface whereas the print precedent is a
> purpose-named, dirty-flag-gated surface. On the consistency hazard (the most
> dangerous property): the pure-TL designs all share it for hash — a key can
> bucket differently depending on whether a TL happened to be armed at insert vs
> lookup, and lookups from host-internal paths run unarmed. Alt 3's
> construction-time hasheq cache is the only shape that eliminates it for the
> hash side. So the cleanest finished form is Alt 2's unified TL for equiv +
> Alt 3's cached hasheq for hash, accepting a residual equiv-only consistency
> edge that can be pinned as an AD-NNN.

### Main-loop disposition of the DA output

The DA's two strongest findings are **accepted and reshaped**, not rejected:

1. **Consistency hazard (DA's central point).** The DA assumed the arming
   locus is `treeWalkCall`-only, under which host-internal map ops (native
   reduce/into/merge, a top-level map literal evaluated before the first call)
   run unarmed and a deftype key buckets inconsistently. The proposed design
   closes this by arming at **both** `evalForm` (the top-level-form window —
   exactly the `(get {deftype-key …} …)` case) **and** `treeWalkCall` (every
   nested call). With that coverage, every deftype-key hash/compare reachable
   from user code is armed; the only unarmed map ops are bootstrap/host-init,
   which never use custom-hash deftype keys. The hazard is closed by **arming
   coverage** rather than by a per-instance cache — so the cache is demoted to
   what it actually is (a perf optimization, deferred per F-010), avoiding its
   O(N²) ordered-map-construction cost and the extra instance field. Caching is
   the right *perf* answer later, not a *correctness* prerequisite now.

2. **Three-TLs-for-one-concept (DA's DRY/F-011 point).** Accepted in
   substance: the proposed design **removes the dormant dead `current_env`** by
   giving it its real purpose (the DRY win the DA wanted) instead of minting a
   new TL. Full Alt-2 unification (deleting `print.active_consult`, folding
   print into the same context) is **rejected** because the two contexts have
   genuinely different arming loci and lifetimes: `print.active_consult` is
   armed at the print boundary and must be live during REPL result rendering,
   which runs AFTER eval returns (when `current_env` is restored to null). Print
   therefore cannot read `current_env`; forcing a shared surface would couple a
   working, gate-covered path (ADR-0127) to this change for no behavioural gain
   — the F-002 "excessive rework that does not improve the finished form" line.
   The shared **`hashDispatch` core** captures the commonization that is real
   (the `(hash x)` primitive + the key-hash site dispatch the same way).

This disposition keeps the landed change the minimal *correct + clean* form,
defers the perf cache explicitly (no silent omission), and leaves the
print-path untouched.
