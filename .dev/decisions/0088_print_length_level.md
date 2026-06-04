# ADR-0088 — `*print-length*` / `*print-level*` print-control vars

Status: Proposed → Accepted
Date: 2026-06-04
Phase: post-M quality loop (F-011 clj-parity)

## Context

The print-control dynamic var family is entirely absent in cljw:
`*print-length*`, `*print-level*`, `*print-dup*`, `*print-readably*`,
`*print-meta*`, `*print-namespace-maps*`, `*flush-on-newline*` all fail
to resolve as symbols. Binding them is a no-op — a real F-011
behavioural gap (a user's `(binding [*print-length* 100] …)` silently
prints unbounded, which in a REPL on an infinite/large structure is the
difference between a readable result and a hang).

This ADR lands the two highest-value members — `*print-length*` and
`*print-level*` — the truncation controls that make printing a large or
deeply-nested (or infinite, bounded by length) structure safe. The
remaining siblings are deferred (see Consequences): `*print-dup*` has no
cljw print-dup path, `*print-readably*` is already modelled by the
`print_readably` threadlocal, `*print-meta*` needs the value-meta print
surface, `*print-namespace-maps*` is a toggle over already-correct
behaviour (its absence only blocks *disabling* the compact form).

### Exact JVM semantics (probed against `clj` 1.12, the corpus golden)

- `*print-length*` (root nil = unlimited): each collection prints at most
  N elements; if more remain, a `...` pseudo-element is emitted after the
  normal separator. Exactly-N prints all N with no `...`. `0` → `(...)`.
  Maps count **entries** (k/v pairs), not scalars.
  - `(binding [*print-length* 3] (pr-str (range 10)))` → `"(0 1 2 ...)"`
  - `(binding [*print-length* 3] (pr-str [1 2 3]))` → `"[1 2 3]"`
  - `(binding [*print-length* 0] (pr-str [1 2 3]))` → `"[...]"`
  - `(binding [*print-length* 2] (pr-str {:a 1 :b 2 :c 3}))` → `"{:a 1, :b 2, ...}"`
- `*print-level*` (root nil = unlimited): a **collection** at nesting
  depth `d` (root collection = depth 0) prints as the single char `#`
  iff `d >= level`. Scalars are never replaced (only collections route
  through the check).
  - `(binding [*print-level* 2] (pr-str [[[[1]]]]))` → `"[[#]]"`
  - `(binding [*print-level* 1] (pr-str [1 [2 [3]]]))` → `"[1 #]"`
  - `(binding [*print-level* 0] (pr-str [1 2]))` → `"#"`
- Composed: `(binding [*print-level* 2 *print-length* 2] (pr-str [1 2 3 [4 5 6 [7]]]))`
  → `"[1 2 ...]"` (length cuts at 2 before the nested vector is reached).

## Decision

1. **Define** `(def ^:dynamic *print-length* nil)` and
   `(def ^:dynamic *print-level* nil)` in `src/lang/clj/clojure/core.clj`
   next to `*unchecked-math*` (line ~25).

2. **Cache** a `*const Var` pointer to each from `bootstrap.zig` after
   `core.clj` loads (mirroring `registerNsVar` → `env.ns_var`,
   `bootstrap.zig:244`), via a new `print.zig` setter
   `initPrintLimitVars(len_var, lvl_var)`. The Var *identity* is fixed
   after intern, so the pointer is a process-global `?*const Var`; the
   *binding* is read live. `Var.deref()` (`env.zig:103`) reads the
   threadlocal `current_frame` binding stack and needs no `rt`/`env`, so
   the pure `printValue(w, v)` renderer can read the user's current
   binding through the cached pointer with no signature change.

3. **Snapshot-at-surface, deref-once** (revised after DA fork). Each
   top-level print surface (`pr`/`prn`/`print`/`println`/`pr-str`/
   `print-str` and `printResult`) snapshots the two limits ONCE at entry
   into `threadlocal var print_length_limit: ?i64` /
   `print_level_limit: ?i64` by dereffing the cached Var pointers, and
   resets `threadlocal var print_depth: i64 = 0`. Because the surface
   runs *inside* the user's `(binding [*print-length* …] …)` scope, the
   single deref reads the user's current binding — responds to `binding`
   exactly, while paying one binding-stack walk per top-level print
   instead of one per element (the DA fork's per-element-deref objection).
   Printing never evaluates user code, so no re-entrant top-level print
   occurs; a hypothetical nested top-level print re-snapshots fresh
   (depth-0), matching clj. This reuses the established `print_readably`/
   `print_namespace_maps` surface-threadlocal pattern rather than
   introducing a new state model.

4. **`*print-level*` threading** — centralised in `printValue`'s
   dispatch for the collection tags **including `.map_entry` and the
   `tagged-literal` form** (clj counts a MapEntry as a vector level):
   before dispatching to a collection helper, `if (print_level_limit)
   |lvl| if (print_depth >= lvl) { write "#"; return; }`, then
   `print_depth += 1; defer print_depth -= 1;` around the helper call.

5. **`*print-length*` threading** — each collection element loop gains a
   guarded `if (print_length_limit) |n| { if (count >= n) { emit
   separator ++ "..."; break; } }`. The two RECURSIVE walkers
   (`printHamtEntries`, `printSortedEntries`) thread an extra
   `remaining`/`count` pointer alongside the existing `*bool first` — the
   DA fork correctly flagged that decision 5 is NOT a flat `i >= n` for
   the unordered/sorted collections. All collections are covered (the
   big-bang discipline), even though hash-set/hash-map > 8 keys stay out
   of the parity corpus per the AD-001 order note below.

6. The default (both nil) path is byte-identical to today → near-zero
   regression surface. The snapshot is read as null (= unlimited) when
   the Var is unbound, nil, or non-integer (clj's `(and *print-length* …)`
   guard).

### Known limitation — infinite lazy seq + `*print-length*` (deferred)

`printResult` deep-realizes lazy seqs BEFORE printing, so
`(binding [*print-length* 3] (prn (iterate inc 0)))` still hangs in
realization (the print-loop guard never fires). This unit delivers
truncation for **finite collections and the compact `.range` type**;
infinite-seq termination needs print-while-forcing (an `rt`-carrying
printer, entangled with the D-164 seq-realization overhaul) and is filed
as a debt row with the clj-`(0 1 2 ...)`-terminates case as its pin. The
parity corpus uses finite / range / bounded cases only — no over-claim.

## Alternatives considered

**Chosen vs DA recommendation.** The DA fork (verbatim below) recommended
Alt 2 (a value-threaded `PrintCtx`) extended with Alt 3's lazy-seq fix.
This ADR adopts neither wholesale, on **merit grounds (not cycle budget)**:

- The DA's two concrete objections to "threadlocals" both target the
  *per-element-deref* shape it assumed. The **snapshot-at-surface**
  refinement (decision 3) derefs ONCE per top-level print, eliminating
  the per-element cost, and re-snapshots fresh on any (hypothetical)
  nested top-level print — so both objections (perf + re-entrancy
  unbalance) dissolve without `PrintCtx`. The DA did not evaluate this
  hybrid.
- `PrintCtx` would also require migrating the two EXISTING, working
  surface threadlocals (`print_readably`, `print_namespace_maps`) into
  the struct for consistency — churning correct code for an aesthetic
  unification. clj itself models these as dynamic vars (= thread-local
  bindings), so the threadlocal shape is the **F-011-faithful** finished
  form, not a compromise. `PrintCtx`'s remaining advantages
  (concurrency / eval-during-print isolation) are **future** — cljw has
  no eval-during-print path today; threads get independent threadlocals
  regardless. Filed as a debt note: revisit `PrintCtx` if Phase 15
  introduces concurrent or eval-during printing.
- Alt 3's finding (the infinite-lazy-seq hang) is ACCEPTED as a real gap
  and filed as debt (see Known limitation); its proposed mechanism
  (couple `deepRealize` to the print Var) the DA itself judged the wrong
  layer.
- Option C (merge the 7 loops into one `printSequential`) is REJECTED,
  per the DA's grounded analysis: the backings are heterogeneous
  (array / HAMT recursion / LLRB recursion / range arithmetic) and a
  uniform iterator either heap-materialises (destroying deliberate
  alloc-free properties) or relocates the heterogeneity into a tagged
  iterator — a leakier finished form, not a cleaner one.

The `.map_entry` depth-count fix the DA flagged is folded into decision 4.

### Devil's-advocate subagent output (verbatim)

I read the ADR, all eight collection helpers in `src/runtime/print.zig`,
and the F-NNN constraints. Three alternatives within the F-NNN envelope,
then a recommendation.

**Grounding observations from the actual code**

1. The "~7 loops" are genuinely heterogeneous backings. `printVector`
   (array index), `printRange` (pure `start + i*step` arithmetic, zero
   allocation, no `rt`), `printList`/`printQueue` (Cons walk),
   `printMap`/`printSet` (HAMT recursion via `printHamtEntries`, threading
   a `*bool first` through pre-order traversal), `printSortedMap`/
   `printSortedSet` (LLRB in-order recursion via `printSortedEntries`,
   also `*bool first`-threaded). The HAMT and LLRB cases are not flat
   loops — they are recursive node walks where "element index" is an
   accumulated traversal position. Decisive for Option C.
2. `printValue` is `Writer.Error!void` — a pure renderer with no
   `rt`/`env`. The cached-`*const Var` + `Var.deref()` mechanism is the
   only way to read a user binding without a signature change.
   `Var.deref()` reads `current_frame` threadlocal, so it works.
3. `printResult` already does a deep-realize pass (`deepRealize`) before
   `printValue` runs, materialising lazy seqs. Correctness trap for
   `*print-length*` over infinite seqs (Alt 3).
4. `print_readably`/`print_namespace_maps` are surface-set threadlocals,
   not user-bindable. `*print-length*`/`*print-level*` MUST respond to
   `(binding …)`, so the value must be read live through a Var, not
   snapshotted by the surface to a fixed value. The ADR gets this right —
   the single most important correctness call.

**Alt 1 — Smallest-diff:** ADR-as-drafted but fold the length guard into a
tiny inline helper `emitEllipsisIfOver(w, i, sep) !bool`; leave level
centralised. BETTER: removes copy-paste across 7 sites (DRY; one place to
regress). Smallest behavioural surface. RISK: HAMT/LLRB have no `i` — you
must thread a `*count` through the two recursive walkers; the ADR's
"each loop gains a guarded `if (i >= n)`" is false for the 4
unordered/sorted collections. Threading length through `printHamtEntries`
buys no parity-corpus value (hash collections are corpus-excluded for
order); only `printSortedEntries` is corpus-relevant.

**Alt 2 — Finished-form-clean:** a single `PrintCtx` value struct
(`depth`, `length`, `level`, `readably`, `namespace_maps`) threaded
through every printer, replacing the free-standing threadlocals.
`printValue(w, v)` → `printValue(w, v, ctx)`; surfaces build one ctx
reading the Vars once; recursion passes `.{ .depth = ctx.depth + 1 }`.
BETTER: kills three module-global threadlocals; re-entrancy/unbalance
structurally impossible (nested `pr-str` gets fresh depth-0 ctx, matching
clj); reads the Var once not per-element; backend-agnostic (F-012). RISK:
signature change to `pub printValue` + every helper (large diff — but
F-002 says size is not a downgrade reason); changes the documented "pure
(w,v) renderer" contract; does not (correctly) merge the 7 loops.

**Alt 3 — Wildcard:** push `*print-length*` UP into `deepRealize` so
realization stops at N+1 elements. BETTER: actually delivers the ADR's
headline ("readable result, not a hang") — ADR-as-drafted hangs on
`(iterate inc 0)` because deepRealize runs before the print guard; only
the compact `.range` works. Makes the corpus claim honest. RISK: wrong
layer (realization depending on a print Var); getting length+level+
laziness jointly correct fights the realize-then-print split; touches the
lazy-seq engine (D-164 territory), higher regression risk. The finding is
the most valuable output; the mechanism is probably not the finished form
(that would be print-while-forcing with `rt` in a PrintCtx).

**On Option C (merge loops): No.** `printRange` is alloc-free scalar
arithmetic; HAMT/LLRB are recursive `*bool`-threaded walks, not loops. A
uniform `printSequential(iter)` either heap-materialises an element list
(destroying alloc-free properties the comments call out as deliberate) or
is a tagged-union iterator whose `next()` is the same 5-arm switch plus a
new type. Option C is smallest-conceptual-surface bias dressed as
cleanliness; it reaches a leakier finished form. Reject — the ADR is
right. The win is commonising the guard expression (Alt 1) and the state
(Alt 2), not the iteration.

**On the Var mechanism:** read-at-print-time via Var is mandatory and
correct (`print_readably`-style snapshot can't respond to `binding`). The
only refinement is to deref once at top-level entry rather than per
element.

**On `>= level` vs `> level`:** the ADR states the rule correctly
(collection at depth `d` prints `#` iff `d >= level`; root = depth 0;
`*print-level* 0` → `#`). Trap: the check must read current depth before
incrementing, and the increment must wrap only the collection-helper
call, not scalar branches. Note `.map_entry` prints as `[k v]` inline in
`printValue` WITHOUT a collection helper — a map-entry IS a vector in clj
and counts as a level; the tag list must include `.map_entry` (and
tagged-literal `form`) or depth under-counts for `(seq {:a {:b {:c 1}}})`.

**Recommendation:** Adopt Alt 2 (PrintCtx) extended to absorb the Alt 3
finding (give PrintCtx `rt`/`env` to force-and-truncate lazy seqs
element-by-element). The ADR-as-drafted adds a fourth ambient threadlocal
with a re-entrancy hazard "defensive reset" only papers over, and reads
the Var per-element. If the `rt`-in-printer extension is too entangled
with D-164 to land in one cycle, land PrintCtx now and file the
lazy-seq-bounding as debt with the clj-hang pin — but do NOT ship the
per-element-threadlocal shape, and do NOT ship a `*print-length*` that
silently hangs on the exact infinite-seq case it was sold to fix. Fix
decision 3's tag list to include `.map_entry` regardless.

<!-- main-loop note: the chosen snapshot-at-surface shape is precisely
the "do NOT ship per-element-threadlocal" the DA warned against, MINUS
the per-element deref — deref-once-at-surface is neither the per-element
threadlocal the DA rejected nor full PrintCtx. The lazy-seq hang is filed
as debt with the pin, as the DA's fallback allows. -->


## Consequences

- `*print-length*` / `*print-level*` become live; `binding` over them
  truncates as clj does. Default (both nil) is byte-identical to today —
  every existing print test is unaffected.
- The `print_depth` threadlocal + `printLength`/`printLevel` accessors
  are the plumbing the deferred siblings (`*print-meta*` especially) can
  reuse.
- `*print-length*` truncation order for unordered collections
  (`hash-set`, `hash-map` > 8 keys) follows cljw's hash order, not clj's
  — an extension of the existing AD-001. Such cases are kept OUT of the
  parity corpus (deterministic-order cases only: vector / list / range /
  array-map ≤ 8 keys / sorted).
- Deferred siblings tracked as a debt row (D-NNN) so the family is not
  silently considered "done".

## Affected files

- `src/lang/clj/clojure/core.clj` — two `^:dynamic` defs.
- `src/runtime/print.zig` — cached Var pointers, `initPrintLimitVars`,
  `printLength`/`printLevel`/`print_depth`, centralised level check in
  `printValue`, length guard in each collection loop.
- `src/lang/bootstrap.zig` — resolve + cache the two vars post-load.
- `test/e2e/` + `test/diff/clj_corpus/print_control.txt` — coverage.
- `.dev/debt.yaml` — deferred-siblings row.
