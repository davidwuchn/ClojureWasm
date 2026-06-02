# ADR-0078 — Distinct MapEntry value type (activate the reserved `.map_entry` slot)

**Status**: Proposed → Accepted (2026-06-03, clj-parity campaign C4 / D-209)

## Context

ADR-0076 §9.2.P clj-parity campaign unit **C4 (D-209)**: cljw represents a map
entry as a plain 2-element PersistentVector, so `(map-entry? (first {:a 1}))` →
`name_error` (no such fn) and there is no way to distinguish `(first {:a 1})`
(a MapEntry in clj) from a literal `[1 2]`.

clj ground truth (oracle-verified): `clojure.lang.MapEntry extends AMapEntry
extends APersistentVector implements IMapEntry`. A MapEntry **IS-A vector** in
every observable way — `(vector? (first {:a 1}))`→true, `(= (first {:a 1}) [:a
1])`→true (both directions), `nth`/`count`/`seq`/`pr-str`/destructure all behave
as a 2-vector — EXCEPT two discriminators: `(map-entry? …)`→true and `(class …)`
→MapEntry. Critically `(conj (first {:a 1}) 99)` → `[:a 1 99]` a PLAIN
PersistentVector (`map-entry?`→false): conj/assoc route through `asVector()` and
DROP the map-entry nature.

The F-004 Group-A `.map_entry` HeapTag slot (value 15) is DECLARED + NaN-box
encode/decode already unit-tested (value.zig:460), `coll?` already forward-wired
(core.zig:306), but otherwise unwired.

## Decision

Activate the reserved `.map_entry` slot as a distinct heap type — the finished
form (matches JVM's distinct class; F-004 reserved the slot for exactly this;
activating a reservation is *consuming a memo*, NOT amending F-004).

```
src/runtime/collection/map_entry.zig: MapEntry = extern struct { header, key: Value, val: Value }
```

- Substrate mirrors `range.zig` (ADR-0063 / D-178) but owns 2 Value children, so
  it registers a `traceMapEntry` GC hook (mark key + val) — unlike range.
- Map-seq producers (`map.zig::seqArrayMap` + `hamtSeqInto`) and `find`
  (core.clj) emit a `.map_entry` instead of a 2-vector.
- A `.map_entry` arm is added to every op a map-entry flows through, delegating
  to the 2 fields so it behaves EXACTLY as a 2-vector — EXCEPT:
  - `map-entry?` (new core fn) → `tag()==.map_entry` (the discriminator).
  - `conj`/`assoc` on a `.map_entry` → a PLAIN `.vector` `[k v …]` (JVM
    `asVector()` — the nature drops, `map-entry?`→false on the result).
  - `class` → "MapEntry" simple name (AD-003, no-JVM).
- `key`/`val` (core.clj, `(nth e 0/1)`) work unchanged once `nth` handles
  `.map_entry`. A single arm-set covers both backends (TreeWalk + VM share the
  primitive table — no per-backend duplication).

## Consequences

- `(map-entry? (first {:a 1}))`→true, `(map-entry? [1 2])`→false, while
  `(vector? (first {:a 1}))`→true and `(= (first {:a 1}) [:a 1])`→true (both
  directions) — clj parity. `(conj (first {:a 1}) 99)`→`[:a 1 99]` plain vector.
- Memory: a MapEntry (header + 2 Values) is SMALLER than a 2-element vector (no
  tail-node array), so this is perf neutral-to-win.
- Blast radius (DA correction — see Alternatives): the `.vector` arms span ~12
  files; each is a place the `else =>` value-dispatch idiom silently swallows a
  `.map_entry` until wired. A **corpus pin per behaviour** (`map_entry.txt`)
  converts every potentially-missed arm into a gate failure (anti-D-177).
- Closes D-209. `.getName`/`.getSimpleName` on the class object remain (D-207
  residual). Next campaign unit: C6 = D-200.

## Affected files

- new: `src/runtime/collection/map_entry.zig` (substrate + traceGc) +
  `test/diff/clj_corpus/map_entry.txt` (corpus pins).
- edit (`.map_entry` arms): `runtime/equal.zig` (isSequential / isCountable /
  seqEqual cursor / valueHash cursor), `runtime/compare.zig`, `runtime/print.zig`,
  `lang/primitive/core.zig` (vector?/sequential?/associative? + new `map-entry?`),
  `lang/primitive/sequence.zig` (count/first/rest/nth/seq), `lang/primitive/
  collection.zig` (nth/conj→vector/contains?), `runtime/collection/map.zig`
  (producers), `lang/clj/clojure/core.clj` (`find` producer + `map-entry?`),
  `runtime/runtime.zig` (registerGcHooks). Plus any of walk.zig / json.zig /
  lookup.zig / transient the sweep surfaces.

## Alternatives considered

(Devil's-advocate subagent, fresh context, per CLAUDE.md depth-≥2 mandate.
Verbatim-reflected; the DA confirmed Option A = Alt 2 with two corrections.
Within the F-004 envelope — no new slot; `map-entry?` stays faithful.)

### Alt 1 — Smallest-diff: an `is_map_entry` flag bit on the `.vector` HeapHeader

Set a spare `HeapHeader.Flags` bit on the 2-vector map-seq produces; `map-entry?`
reads it; every other op ignores it (a flagged vector behaves as a plain vector).

**Better:** near-zero blast radius — no substrate, no GC hook (the existing
`traceVector` already walks both slots), no per-op arms; `map-entry?` is one
header-bit read.

**Breaks/risks (fatal, F-011):** conj/assoc/pop/subvec/with-meta must DROP the
nature (clj). The flag rides the source vector's header, but those ops clone the
header, so the flag must be *explicitly cleared* on every structural/meta path —
auditing MORE sites than Alt 2's arms, in the most error-prone direction (silent
wrong-`true`). And it makes `.vector` a **two-headed type** (vector OR map-entry
by a bit): every future `.vector` reader must know the bit exists — the
Silent-default-shift / two-headed smell, the textbook smallest-diff-bias the
finished-form owner unwinds (F-002). Rejected: smaller diff, larger finished-form
debt.

### Alt 2 — Finished-form-clean (CHOSEN): distinct `.map_entry` tag, per-arm

Option A as proposed. The map-entry nature is **isolated in the tag**, so
`.vector` stays single-headed; "drops nature on conj" is automatic-by-
construction (the conj arm just builds a `.vector` — no flag to forget). Mirrors
`.range` / `.string_seq` / `.array_seq` (each a distinct heap tag with scattered
per-op arms — the codebase's own established precedent; the DA grep confirmed
there is NO `asVectorView` funnel today, so `.map_entry` follows the same
per-arm pattern as every other non-`.vector` sequential heap type).

**DA corrections folded in:** (1) the blast radius is **~12 files** (`equal`,
`compare`, `print`, `lookup`, `vector`, `macro_transforms`, `metadata`,
`transient`, `sequence`, `json`, `collection`, `walk`), not "14 arms in 4 files"
— `compare` / `clojure.walk` / `json` are first-class arms, the easiest to miss;
enumerate the full set, and let a broad clj-diff sweep surface any miss. (2) the
`else =>` idiom makes a missed arm a *silent* bug → a **corpus pin per behaviour
is mandatory in the same cycle** (the guard, not exhaustive-switch). **Risk:** a
missed arm degrades a MapEntry silently until the pin catches it — mitigated by
the sweep + corpus.

### Alt 3 — Wildcard: `.map_entry` laid out as a 2-vector + introduce the `asVectorView` funnel (option d)

Give `.map_entry` the same in-memory layout as a 2-element vector (so a
`*const Vector` reinterpret is valid) AND introduce the `asVectorView(Value)
?*const Vector` choke point that does NOT exist today, routing the uniform ops
(count/nth/seqEqual/valueHash/print) through one `.map_entry` arm; only the 3
divergent behaviours (map-entry?/conj/class) keep bespoke arms.

**Better:** the only shape that realizes option (d)'s arm-reduction; leaves a
reusable `asVectorView` funnel a future `.tuple`/small-vector opt could ride.

**Breaks/risks:** layout-punning couples `.map_entry`'s ABI to the internal
persistent-vector tail layout (a future vector representation change silently
corrupts MapEntry — needs a comptime offset assertion + still couples two types
F-009 keeps independent). And it is **scope creep beyond D-209**: introducing
`asVectorView` + retrofitting `.range`/`.string_seq`/`.array_seq` through it is a
separate refactor (its own ADR); bundling it risks taking map-entry parity down
with it (Surgical-changes). The net arm saving is modest (N full arms → N
view-producing arms + 1 funnel). Deferred to its own ADR — do not gate D-209 on
it.

### Decision

**Alt 2 chosen** (per the DA, = the survey's Option A), with the blast-radius
correction (~12 files, enumerate fully) + the mandatory corpus-pin-per-behaviour
guard. Alt 1 rejected (two-headed `.vector` smell + leak-prone flag clearing).
Alt 3's `asVectorView` funnel is a genuine improvement but is new construction +
ABI coupling + cross-type refactor — deferred to its own ADR, not bundled into
the parity fix. No F-NNN amendment needed (A15 is the reserved map_entry slot).

## Revision history

- 2026-06-03 created (Accepted): clj-parity C4 / D-209. Distinct `.map_entry`
  type (Option A) over the flag-bit (Alt 1) and the layout-pun+funnel (Alt 3),
  on finished-form-cleanliness grounds; DA blast-radius correction (~12 files) +
  corpus-pin mandate folded in; the `asVectorView` funnel deferred to its own ADR.
