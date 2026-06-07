# ADR-0110 — Symbol value-metadata (`with-meta`/`meta` on symbols)

- **Status**: Accepted
- **Date**: 2026-06-07
- **Discharges**: D-304 (the D-075 symbol residual)
- **Amends**: ADR-0095 (the GC membrane rationale — corrects the
  symbol/keyword conflation; flips `.symbol` to GcManaged)
- **Cross-refs**: F-002, F-004, F-006, F-011; ADR-0037 D6 (where symbol
  meta was deferred); D-239 (var/atom/ns mutable-ref meta — out of scope)

## Context

`(with-meta sym m)` / `(meta sym)` errored (`with-meta: cannot attach
metadata to symbol`) because `Symbol{header, ns, name, hash_cache}` carried
no meta field (deferred at ADR-0037 D6 → D-075 → D-304). This blocks the
real-library ladder: `clojure.core.cache` and
`clojure.algo.generic.math-functions` both die attaching meta to a symbol.

clj oracle (verified 2026-06-07):

- `(meta 'a)` → `nil`; `(meta (with-meta 'a {:x 1}))` → `{:x 1}`.
- `(= 'a (with-meta 'a {:x 1}))` → **true** — meta is NOT part of symbol
  identity; `(= (with-meta 'a {:x 1}) (with-meta 'a {:y 2}))` → true.
- `(hash 'a)` == `(hash (with-meta 'a {:x 1}))` — hash ignores meta.
- `(get {'a 1} (with-meta 'a {:x 1}))` → `1` — map-key consistency.
- `(identical? 'a (with-meta 'a {:x 1}))` → **false** — distinct objects.
- `(with-meta :a {})` → ClassCastException — keyword has no meta (cljw
  keeps its type error).

The load-bearing crux is GC. A with-meta'd symbol carries a GC-managed
`meta` map that must be traced, but `.symbol` is excluded from the GC
membrane (`isGcManaged`, ADR-0095 Alt D) — the single per-tag classifier
that `Value.heapHeader()` consults so every root walk filters
heap-tagged-but-non-GC pointers before `mark()`.

## Decision

1. **`Symbol` gains `meta: Value = nil_val`.** Interned symbols leave it
   nil (the interner mints them unchanged); only `with-meta` sets it.
2. **`with-meta` on a symbol gc.allocs a FRESH non-interned `Symbol`**
   sharing the interned base's `ns`/`name` slices (no dupe → no finaliser,
   slices stay interner-owned + alive) + the new `meta`. This is the
   collection-meta precedent (`vector.withMeta`) applied to symbols: the
   value is collectable transient data, so it lives in the GC layer (F-006),
   not pinned. `(meta sym)` reads the field; `vary-meta` rides
   `meta`+`with-meta`.
3. **Flip `.symbol` to GcManaged = true** + register a `.symbol` trace that
   marks `sym.meta` (the `vector.traceVector` shape — a no-op when meta is
   nil). This **corrects** ADR-0095's membrane comment, which wrongly lumped
   `symbol`/`keyword` with the genuinely-headerless `var_ref`/`ns`: a
   `Symbol` (like `Keyword`) HAS a valid `HeapHeader` at offset 0, so the
   "mis-decode to a non-header" OOB never applied to it. Symbols were
   excluded only for a *liveness-not-needed* reason (the interner keeps them
   alive). The membrane's true meaning is "header-safe + markable"; symbols
   are header-safe, so `true` is the honest classification.
4. **Symbol equality + hash become ns+name-structural (meta-ignored).**
   `valueEqual` / `keyEqValue` gain a `.symbol` arm (`symbolStructEq`); it
   only fires when pointers differ (the rare with-meta case — interned pairs
   still hit the identity fast-path). `valueHash` gains a `.symbol` arm using
   `hash_cache` (computed from ns+name, identical for the interned base and
   its with-meta'd twin) — this closes a latent bug: the prior
   `else`-pointer-bits hash would hash `'a` and `(with-meta 'a m)` apart,
   breaking `(get {'a 1} (with-meta 'a m))`.
5. **Keyword stays GcManaged = false** — keywords never carry meta (clj
   rejects), so they never need marking; the membrane comment is split to
   state symbol=markable, keyword=filtered-(liveness-not-needed).

### Why interned symbols need no `persistent_marks` registration

Flipping the membrane means live interned symbols (in constant pools) are
now handed to `mark()` each GC: bit set + trace = a nil-meta no-op. Their
mark bit is never cleared (not on `gc.allocations`, not a `persistent_marks`
waypoint). This is **provably inert**: an interned symbol has NO GC child
(meta is structurally always nil — `with-meta` always mints a *non-interned*
symbol), so a stale bit cannot strand anything. `persistent_marks` is
documented for never-swept waypoints *whose trace reaches GC children*
(`Function.closure_bindings`); registering childless interned symbols there
is off-purpose AND adds O(interned-symbols) `clearPersistentMarks` work to
EVERY collect — a common-path perf cost for a rarely-used feature, buying
nothing. The with-meta'd symbol (the only symbol WITH a GC child) is
gc.alloc'd, so sweep clears its bit normally; correctness holds without the
registration.

## Alternatives considered (Devil's-advocate, fresh-context subagent, verbatim)

> **Three load-bearing facts (verified against source):**
> **Fact 1** — the ADR-0095 "mis-decode" claim is NOT accurate for symbols.
> `Symbol` is `header: HeapHeader` at offset 0; the `tag_trace_table[112]`
> OOB came from a non-header pointer (`var_ref`/`ns`). The ADR's own Revision
> says symbol/keyword were filtered because they are gpa-interned, never
> swept, "never need marking" — a liveness-not-needed reason conflated with
> the headerless reason. **Fact 2** — the `Runtime.init` guard is
> one-directional (`trace ⇒ GcManaged`), so flipping symbol + registering a
> trace passes; but the guard does not catch the opposite hazard
> (GcManaged-but-never-swept-and-unregistered). **Fact 3** — `heapHeader()`
> is the single funnel; flipping `.symbol` changes every root-walk site at
> once.
>
> **Alt 1 — smallest-diff: gc.alloc the meta-symbol, DON'T flip the
> membrane; root the meta via a per-object `has_meta` header bit read inside
> `heapHeader()`.** Better: interned symbols stay membrane-false → never
> handed to `mark()`, so the per-GC cost + never-cleared-bit question both
> evaporate; only the rare meta-symbol is markable. Breaks: makes
> `heapHeader()` — the hottest funnel — tag-aware with a per-object branch,
> regressing the membrane from "total, closed, tag-indexed" back to
> "tag-indexed plus a hand-coded exception" — the exact allow-list smell
> ADR-0095 Alt D closed. Corrodes the SSOT the project just built.
>
> **Alt 2 — finished-form-clean (recommended): flip the membrane to true,
> register the trace, AND register interned symbols as `persistent_marks`
> waypoints so bit-hygiene is correct by construction (reuse the Class-1
> `registerPersistentMark`/`clearPersistentMarks` mechanism, F-011).** Better:
> closes the never-cleared-bit concern by reusing the existing mechanism
> instead of a "harmless no-op" hand-wave; honours the project's stated rule
> "never-swept markable object ⇒ registered in persistent_marks" so the next
> person who adds a symbol→GC-child edge is safe. Breaks: every interned
> symbol costs one persistent_marks slot (8 B) + one bit-clear per collect →
> O(interned symbols) growth (ADR-0095 already flagged the analogous Function
> accumulation). Honest finished form is to accept it (symbols are bounded by
> program text, far more benign than per-closure Functions).
>
> **Alt 3 — wildcard: a dedicated `symbol_with_meta` heap tag (burn a Group A
> slot).** Better: total separation — the hot interned path is byte-for-byte
> unchanged; GC cost paid only by rare meta-symbols. Breaks: Group A slots
> 0-15 are all assigned (no free slot → cross-group placement or reshuffle),
> AND it is the severe Cascade smell F-004 warns of — every `v.tag() ==
> .symbol` site (reader / analyzer / dispatch / equality / hashing / printing
> / `symbol?` / resolution / quoting) must also test `.symbol_with_meta` or
> silently mis-handle a meta-symbol, with the compiler's `else =>` arms
> swallowing omissions; the `(= 'a (with-meta 'a m))→true` invariant now needs
> a cross-tag equality arm. Trades a bounded localized GC cost for an
> unbounded scattered correctness surface — the inversion of F-002 + F-011.
> Reject.
>
> **Recommendation: Alt 2.** The equality/hash arms the draft adds are
> correct and necessary (the `else` pointer-bits hash in `valueHash` is a
> latent bug for meta-symbols). Strengthen the `Runtime.init` guard with a
> sibling assert ("every never-swept GcManaged object is registered in
> persistent_marks") so the next membrane-flip can't repeat the latent bug.

**Main-loop disposition (not bound by the DA recommendation within the F-NNN
envelope).** The loop takes the membrane flip + trace (Alt 2's core) but
declines Alt 2's `persistent_marks` registration of interned symbols. The
DA's bit-hygiene concern is real for waypoints *with GC children*; interned
symbols have none (structural — `with-meta` always mints a non-interned
symbol), so their stale bit is provably inert, and registering O(symbols)
childless entries adds common-path `clearPersistentMarks` cost for zero
correctness benefit and mis-uses a trace-the-children mechanism. This is a
**correctness+purpose** argument, not a cycle-budget defer (the chosen path is
not the smaller diff for diff's sake — it is the one that keeps
`persistent_marks` honest to its documented purpose). Alt 1's per-object
`heapHeader` branch is rejected for the SSOT-purity reason the DA gives. The
DA's guard-strengthening suggestion is folded as a code comment on the
membrane (a sibling assert would need to enumerate "never-swept" objects,
which the runtime does not track distinctly — the comment records the
inertness invariant instead).

## Consequences

- **Positive**: symbols join the metadata-bearing IObj family; the ladder
  advances (core.cache / algo.generic.math-functions). The membrane comment
  becomes honest (symbol = header-safe + markable). A latent symbol-hash bug
  is closed. No new heap tag, no cascade.
- **Negative**: live interned symbols now incur a trivial `mark()` (bit +
  nil-meta trace) per GC where they were filtered before — bounded by live
  program text, the irreducible cost of tracing meta-symbols through the
  shared tag. `(hash 'sym)` value changes (pointer-bits → ns+name hash);
  internal-only (cljw hash is not JVM-bit-identical), no corpus pins it.

## Affected files

- `src/runtime/symbol.zig` — `meta` field, `withMeta`, `metaOf`,
  `traceSymbol`, `registerGcHooks`.
- `src/runtime/value/heap_tag.zig` — `.symbol` out of the GcManaged-false
  arm; comment split.
- `src/runtime/value/value.zig` — `heapHeader` membrane comment.
- `src/runtime/runtime.zig` — `symbol.registerGcHooks()` call.
- `src/lang/primitive/metadata.zig` — `.symbol` arms in `metaFn`/`withMetaFn`.
- `src/runtime/equal.zig` — `.symbol` arms in `valueEqual` / `keyEqValue` /
  `valueHash` (`symbolStructEq`).
- `test/e2e/phase14_symbol_metadata.sh` — 14-case smoke.
