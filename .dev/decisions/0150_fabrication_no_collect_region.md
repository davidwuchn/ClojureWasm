# ADR-0150 — Fabrication no-collect region (D-244 #4 alloc-torture rooting)

- **Status**: **REJECTED 2026-06-16 — contradicts the already-DECIDED ADR-0090 (D-244 =
  Alt B, "publish a precise root, do NOT disable the collector").** This ADR is kept as a
  RECORD of why the no-collect-region (suppressCollection) approach was explored + rejected,
  so a future session does not re-propose it. The DA fork recommended Alt A but did not
  weight the committed stance; digging into the D-244 row (debt.yaml:1770) found D-244 was
  DECIDED 2026-06-04 as **Alt B via ADR-0090 + DA-fork**, and the `gc_self_guard` mechanism
  ALREADY LANDED (#3b-step2b). The remaining D-244 #4 work (#4b-future-ii) explicitly lists
  "the Q1 gc_self_guard set/clear sites" — **wiring gc_self_guard at the fabrication/builder
  sites IS the decided fix**. Alt A IS the `suppressCollection` escape hatch ADR-0090
  refused. **The correct path = execute ADR-0090's Alt B** (see § Correct path below).

## Correct path (ADR-0090 Alt B — the decided approach)

Wire `gc_self_guard` (the landed single-`?Value` slot, root_set.zig:155) to publish the
in-flight partial at each fabrication/builder site, per ADR-0090. **Open question this
ADR's investigation surfaced**: ADR-0090's "a SINGLE slot suffices" claim assumes the
unrooted window is at the op-LOOP level (the partial accumulator across `conj`/`assoc`
calls, which ARE on `stack[0..sp]`). But the confirmed `(conj [1 2 3] 4)` corruption — a
SINGLE conj, no loop — shows an unrooted window INSIDE the builder: `conj` allocs a
`*TailNode` (NOT a Value), then a Vector; a collect between them sweeps the TailNode, which
a partial-Value `gc_self_guard` does not root. So executing Alt B must resolve: does
publishing the partial Value at the builder ENTRY suffice (if conj re-derives the tail from
the rooted partial each call), or does the builder-internal node-alloc need its own
publication (a node-level extension of the precise-root mechanism)? This is the genuine D-244
#4 design question — resolve it WITHIN ADR-0090's publish-precise-root stance, NOT by
suppressing the collector.

## Why Alt A (no-collect region) was REJECTED — discovered post-DA

`root_set.zig:138-154` (the `gc_self_guard` docstring) shows the codebase already has a
**designed, committed fix for THIS exact bug** + an explicit design stance:

> "The fabrication loop sets this slot to the partial before each alloc and clears it
> after the result lands on the stack. A SINGLE slot suffices … **Refuses cw v0's
> `suppressCollection` escape hatch (publish a precise root, do not disable the
> collector)**. The fabrication-site set/clear wiring lands with #4."

Alt A (a no-collect region) **IS** the `suppressCollection` escape hatch the codebase
deliberately refused. So Alt A contradicts a committed invariant — and the DA fork cited
line 152 but did not weight it as binding (it judged Alt B "gold-plating vs an uncommitted
moving GC", missing that the stance is committed INDEPENDENT of moving GC — it is a
"don't disable the collector" principle refusing a v0 escape hatch).

**BUT** — the codebase's own designed mechanism is ALSO incomplete: `gc_self_guard` is a
single `?Value` slot set to the *partial accumulator*; it roots the partial VECTOR but NOT
the in-flight internal NODE (`*TailNode`/`*HamtNode`, not a Value) that `conj`/`assoc`
allocate INTERNALLY. The confirmed `(conj [1 2 3] 4)` corruption (a SINGLE conj, no
fabrication loop) proves the unrooted window is INSIDE the builder, which the "single slot
at the op-loop level" model does not cover. So the codebase's intended fix, as documented,
would not fix the standalone-conj case either.

**Resolution needed (next focused session)**: re-run the Devil's-advocate fork with the
`root_set.zig:150` "never suppress, publish precise root" stance as an EXPLICIT BINDING
constraint, and resolve the three-way tension:
  (a) extend the precise-root mechanism to internal nodes (Alt B + a node-level guard —
      stance-aligned, "the hard part"); OR
  (b) amend the stance to permit a BOUNDED no-collect region for pure-Zig builders (Alt A
      + a documented stance amendment with rationale — is the v0-escape-hatch refusal still
      load-bearing for a non-moving GC?); OR
  (c) a hybrid (publish the partial Value via gc_self_guard AND a minimal node-guard only
      for the builder-internal window).
Check whether the "never suppress" stance is backed by an ADR / F-NNN (more binding) or is
a code-comment preference (loop-amendable with rationale) before choosing.
- **Deciders**: autonomous loop + Devil's-advocate fork (general-purpose, fresh
  context, F-006/F-002/F-011 envelope).
- **Supersedes / relates**: ADR-0028 (mark-sweep GC + the alloc-driven auto-collect
  trigger), F-006 (non-moving GC strategy), D-244 #4, D-386 sub-step 2 (the op_top
  register hoist whose alloc-torture validation this unblocks).

## Context

`CLJW_GC_TORTURE_ALLOC=1` forces a stop-the-world mark-sweep collect inside EVERY
`gc.alloc` — the strictest rooting validation (catches an object unrooted across a
mid-alloc collect). It is BLOCKED: any multi-alloc collection builder corrupts under
it. Confirmed live (ReleaseSafe):

- `[1 2 3 4 5]` → `[1 nil nil nil nil]` (silent corruption)
- `(conj [1 2 3] 4)` → `@memcpy arguments alias` panic — **a single conj**, so the
  bug is at the BUILDER level, not just the op_*_literal fabrication ops
- `(conj #{1 2} 3)` / `(hash-map :a 1 :b 2)` / `(vector 1 2 3)` → OOB / overflow panics

Cause: a builder (`conj` → `alloc(TailNode)` then `alloc(Vector)`; HAMT `assoc` →
leaf + interior nodes; `fromSlice` → a whole `level_nodes: []*HamtNode` tower) holds
an intermediate NODE — a `*TailNode`/`*HamtNode`, NOT a `Value` — in an unrooted Zig
local across the next alloc. A per-alloc collect sweeps it.

**Not reachable in normal operation today**: auto-collect is OFF (gc_heap.zig:280);
collects fire only at safepoints / eval-reentry, never mid-pure-Zig-builder. It is a
torture-tool artifact today + a latent hazard once ADR-0028's **alloc-driven**
auto-collect (a `bytes_since_last_gc > threshold` check inside `gc.alloc`) is wired.
A prior `fromSlice` swap was tried + reverted (it MOVED the bug — its own node tower
is unrooted).

## Decision

**Alt A — a narrowest-span no-collect region per builder.** A threadlocal
`gc_fabrication_depth: u32`; each multi-alloc collection builder brackets its internal
alloc sequence with `enterFabrication()` / `defer exitFabrication()`. The per-alloc
collect (the torture block in `gc_heap.alloc`, and ADR-0028's future auto-collect)
skips when `depth > 0`.

- **Narrowest span**: only one builder's internal multi-alloc — never wrapping a path
  that can reenter eval (collection builders are pure Zig; no user code runs inside, so
  no reentrant collect — the only REAL F-006 hazard — is ever suppressed). `depth` is 0
  at every safepoint / eval-reentry, so the torture tool's real hazard class stays fully
  exercised.
- **Covers all call sites** (op_*_literal, the vector/hash-map builtins, bare
  `conj`/`assoc`) + **nests correctly** (a builder calling a wrapped builder balances).
- **The alloc-torture is the completeness guard**: a builder that forgets the wrap still
  trips it → self-enforcing regression test (so per-site rot is caught, not silent).

**Correct under F-006 (non-moving mark-sweep)**: a collect suppressed across a BOUNDED
builder runs harmlessly just after (nothing relocates; the result is rooted on the
operand stack by then). **No regression vs today** — today no collect fires mid-builder
anyway (folds already pile up until the next safepoint); the region preserves that and
extends it to the future alloc-driven auto-collect case. Cost = 2 threadlocal increments
per builder (no lock), vs Alt B's per-node heap-touch.

**Forward debt** (barriered, not on the distal moving GC but on the nearer trigger): when
a MOVING/concurrent GC — or any collect that must run mid-builder and RELOCATE — is
committed, the region must be replaced with published precise roots (Alt B's node-level
guard). A non-moving alloc-driven auto-collect (ADR-0028) does NOT require this: deferring
a bounded builder's collect is a legitimate brief critical section, not a correctness mask.

## Alternatives considered (Devil's-advocate fork, fresh context — verbatim)

> **Shared premise**: under F-006 (non-moving mark-sweep) a mid-fold collect changes
> nothing semantically — objects don't move; the only corruption is sweeping an
> unrooted partial. In normal operation `gc.alloc` never auto-collects (gc_heap.zig:280),
> so the corruption is unreachable in production today — a torture artifact + a latent
> hazard for a future mid-alloc-collecting GC (which F-006 does not commit to).
>
> **Alt A (no-collect fabrication region)** — a threadlocal depth counter; fabrication
> brackets its fold; the collect skips when >0. *Better*: structurally complete with the
> smallest correct surface — covers the partial AND every internal node regardless of how
> many allocs a builder does; no node-guard infra, no per-alloc overhead, no per-builder
> wiring that rots silently (it does not care how `fromSlice`'s level tower is shaped).
> *Risks*: makes alloc-torture skip mid-fold collects — but only the mid-pure-Zig-fold
> collect F-006 forbids; it does NOT blind any safepoint/eval-reentry collect (depth is 0
> there). Residual risk is purely forward (a moving GC), mitigated by a forward-note +
> debt row. *Diagnostic value*: preserved for every hazard real under F-006; declines only
> the non-hazard — the rule's sanctioned case.
>
> **Alt B (root every intermediate: partial Value via gc_self_guard + a NEW node-level
> guard)** — *Better*: also correct under a future moving/concurrent GC (publishes precise
> roots, the discipline root_set.zig:152 endorses). *Breaks/gold-plating*: pervasive +
> load-bearing — `fromSlice` holds a whole `level_nodes: []*HamtNode` slice across the
> level loop (a scalar guard cannot root it → effectively a second mini-root-set); `conj`
> has up to 4 unrooted-node windows; every future builder must remember to wire it or
> silently reintroduce the bug. The ENTIRE payoff is correctness against a GC the project
> has NOT committed to (F-006) — Reservation-as-bias compounded by gold-plating. Under
> non-moving mark-sweep it buys nothing A does not, at many times the surface + a per-node
> heap-touch on the hot path.
>
> **Alt C (single-alloc builder + publish the one internal node)** — *Better*: keeps the
> single-alloc perf win. *Fatal, verified in code*: the premise is FALSE — `fromSlice`
> does NOT have one internal node; it allocates `leaf_count` leaves then interior nodes
> level-by-level, holding them in `level_nodes` across each `alloc(HamtNode)`. Publishing
> "the one TailNode" leaves the whole tower unrooted → torture moves the corruption from
> the tail to the tree (the silent `[1 nil nil]` the 2026-06-15 revert already saw). To
> fix C you rebuild Alt B's tower guard → C is either incorrect (one slot) or Alt B in
> disguise. Its single-alloc perf goal is ORTHOGONAL — pursue it separately, riding inside
> A's region.
>
> **Recommendation: Alt A.** Finished-form for the COMMITTED architecture. The corruption
> it suppresses is, under non-moving mark-sweep, a non-event. It roots the partial AND every
> internal node by construction, needs no node-level guard, adds no per-node hot-path
> overhead, and does not rot when a new builder lands. Alt B is right ONLY if F-006 flips to
> a moving GC — at which point B's node-guard is subsumed by the moving GC's own
> barrier/handle machinery, so B is not even the right shape for that future. Alt C is
> rejected on a verified factual error.
>
> **Conditions on A**: (1) narrowest span — only the pure-Zig builder, errdefer-restored,
> never wrapping eval-reentry; (2) a forward-note marker + debt row barriered on "a
> mid-alloc-collecting RELOCATING GC lands"; (3) keep alloc-torture's edge for every other
> `gc.alloc` site. Caveat: ADR-0028 auto-collect is alloc-driven — if it lands as a
> NON-relocating collect, A's deferral is still correct (bounded builder; runs just after);
> only a RELOCATING collect would force B.

## Consequences

- `CLJW_GC_TORTURE_ALLOC` validates all collection-building code again → unblocks D-386
  sub-step 2 (op_top register hoist) validation + restores the alloc-torture's value for
  every future perf producer (the O-032/O-033 producers re-validate under it).
- A real latent UAF/corruption (reachable once alloc-driven auto-collect lands) is closed.
- Per-builder cost: 2 threadlocal increments (no lock). Negligible on the hot path.
- The implementation is a builder-level sweep, validated by the torture probe set
  converging to zero panics (the self-enforcing completeness guard).

## Affected files (implementation unit, immediately following)

- `src/runtime/gc/root_set.zig` — `gc_fabrication_depth` threadlocal.
- `src/runtime/gc/gc_heap.zig` — gate the alloc torture block + a note at the future
  auto-collect site; `enterFabrication`/`exitFabrication` helpers.
- `src/runtime/collection/{vector,set,map}.zig` (+ sorted variants) — wrap each
  multi-alloc builder.
- `.dev/debt.yaml` — re-open D-244 #4 as the sweep unit + the forward (moving-GC) row.

## Revision history

- 2026-06-16 issued + **REJECTED same day**. Explored the no-collect-region (Alt A) fix for
  D-244 #4 with a Devil's-advocate fork (general-purpose, fresh context, F-006/F-002/F-011
  envelope, 3 alternatives verbatim; the DA recommended Alt A). Bug confirmed live + scoped
  to the builder level (a SINGLE `(conj [1 2 3] 4)` corrupts under `CLJW_GC_TORTURE_ALLOC`).
  **Post-DA, found Alt A contradicts ADR-0090's already-DECIDED D-244 Alt B** ("publish a
  precise root, do not disable the collector" — the `suppressCollection` escape hatch the
  codebase deliberately refused; the `gc_self_guard` slot for it already landed at
  #3b-step2b). REJECTED; the correct path is wiring `gc_self_guard` per ADR-0090 (§ Correct
  path) + resolving the builder-internal-node question. The DA fork's miss (not weighting the
  committed stance) is itself recorded as the lesson. Design note:
  `private/notes/9.2.S-d244-4-design.md`.
