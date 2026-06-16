# ADR-0150 — Fabrication no-collect region (D-244 #4 alloc-torture rooting)

- **Status**: **ACCEPTED 2026-06-16.** (Briefly REJECTED earlier the same day on a
  premise error — see Revision history.) A bounded no-collect **fabrication region**
  brackets each multi-alloc collection BUILDER so a mid-builder stop-the-world
  collect is DEFERRED — closing the D-244 #4 alloc-torture corruption. Correct under
  F-006 (non-moving mark-sweep). Implemented as `GcHeap.enterFabrication` /
  `exitFabrication` + a threadlocal `fabrication_depth` gating the alloc-torture (and
  the future ADR-0028 alloc-driven auto-collect) in `gc_heap.zig`.
- **Deciders**: autonomous loop + two Devil's-advocate forks (general-purpose, fresh
  context, F-006/F-002/F-011 envelope).
- **Supersedes / relates**: ADR-0028 (mark-sweep GC + the alloc-driven auto-collect
  trigger), F-006 (non-moving GC strategy), ADR-0090 (D-244 = the multi-thread
  safepoint mechanism), D-244 #4, D-386 sub-step 2 (the op_top register hoist whose
  alloc-torture validation this unblocks).

## Context

`CLJW_GC_TORTURE_ALLOC=1` forces a stop-the-world mark-sweep collect inside EVERY
`gc.alloc` — the strictest rooting validation (catches an object unrooted across a
mid-alloc collect). It was BLOCKED: any multi-alloc collection builder corrupted
under it. Confirmed live (ReleaseSafe):

- `[1 2 3 4 5]` → `[1 nil nil nil nil]` (silent corruption)
- `(conj [1 2 3] 4)` → `@memcpy arguments alias` panic — **a single conj**, so the
  bug is at the BUILDER level, not just the op_*_literal fabrication ops
- `(conj #{1 2} 3)` / `(hash-map :a 1 :b 2)` / `(vector 1 2 3)` / `(list 1 2 3)` →
  OOB / overflow / corruption

Cause: a builder (`conj` → `alloc(TailNode)` then `alloc(Vector)`; HAMT `assoc` →
leaf + interior nodes; `fromSlice` → a whole `level_nodes: []*HamtNode` tower;
the `list` builtin's `acc = consHeap(rt, x, acc)` cons-fold) holds an intermediate
NODE — a `*TailNode`/`*HamtNode`/`*Cons`, NOT a `Value` — in an unrooted Zig local
across the next alloc. A per-alloc collect sweeps it.

**Not reachable in normal operation today**: auto-collect is OFF (gc_heap.zig:280);
collects fire only at safepoints / eval-reentry, never mid-pure-Zig-builder. It is a
torture-tool artifact today + a latent hazard once ADR-0028's **alloc-driven**
auto-collect (a `bytes_since_last_gc > threshold` check inside `gc.alloc`) is wired.

## Decision

**A narrowest-span no-collect region per builder.** A threadlocal
`fabrication_depth: u32`; each multi-alloc collection builder brackets its body with
`enterFabrication()` / `defer exitFabrication()`. The per-alloc collect (the torture
block in `gc.alloc`, and ADR-0028's future auto-collect) skips when `depth > 0`.

- **Whole-body bracket, not first-alloc-out.** Deferring the builder's *first* alloc
  too is what makes a Zig-caller fold loop safe: in `op_set_literal` / the transient
  HAMT-promote loop / the `consHeap` fold, the partial accumulator is held in a Zig
  local with **no alloc between builder calls**, so a whole-body bracket removes every
  synchronous collect point and the partial is never exposed. (The existing
  `gc_self_guard` `?Value` slot — ADR-0090 #3b-step2b — stays as the inert
  publication infra for the FUTURE worker/safepoint trigger, a different path not
  exercised by the synchronous alloc-torture. It is kept, not retired.)
- **Covers all call sites + nests correctly** (a builder calling a wrapped builder
  balances). The **alloc-torture is the completeness guard**: a builder that forgets
  the wrap still trips it → self-enforcing regression test.
- **Cost**: 2 threadlocal increments per builder (no lock). Always-on (the region
  must be live in production once ADR-0028 auto-collect lands), so the array-map /
  small-map single-alloc fast paths pay it too — measured negligible vs the alloc.

**Scope**: this fixes the SYNCHRONOUS builder window (no eval reentry). The
complementary class — a collect during an eval-REENTRANT lazy-seq realization /
reduce that sweeps the accumulator (e.g. `(into {} (map f (range N)))`, which under
alloc-torture yields a wrong count) — is the `gc_self_guard` / EvalFrame
reentrant-rooting scope (the D-251/ADR-0094 family). It is tracked as **D-244 #4b**,
a distinct and larger effort, NOT closed here.

**Correct under F-006 (non-moving mark-sweep)**: a collect suppressed across a
BOUNDED builder runs harmlessly just after (nothing relocates; the result is rooted
on the operand stack by then). **No regression vs today** — today no collect fires
mid-builder anyway (folds already pile up until the next safepoint); the region
preserves that and extends it to the future alloc-driven auto-collect case.

**Forward debt** (barriered on the nearer trigger, not the distal moving GC): when a
MOVING/concurrent GC — or any collect that must run mid-builder and RELOCATE — is
committed, the region must be replaced with published precise roots (a node-level
guard). A non-moving alloc-driven auto-collect (ADR-0028) does NOT require this:
deferring a bounded builder's collect is a legitimate brief critical section, not a
correctness mask. Row: D-244 #4 forward.

## Why the "never suppress" stance does NOT forbid this (the reversal)

This ADR was briefly rejected on the belief that a no-collect region contradicts an
already-decided "publish a precise root, do NOT disable the collector" stance. Read
directly, that belief was wrong:

- **ADR-0090's D-244 decision text** (lines 389-435) decides the **multi-thread
  safepoint** mechanism. Its "self-guard not a guard-list" language (410-413) rejects
  a per-site guard-LIST for partial **VALUES** in favour of a single `gc_self_guard`
  slot — it is about the `op_*_literal` accumulator (a *Value*), and says **nothing**
  about the raw `*TailNode`/`*HamtNode`/`*Cons` allocated INSIDE one builder. ADR-0090
  also explicitly defers concurrent/incremental mark to ROADMAP §89.2 under F-006.
- The "Refuses cw v0's `suppressCollection` escape hatch" line lives in
  `root_set.zig` (the `gc_self_guard` docstring) — a **code comment** on the
  partial-Value slot, loop-amendable, not ADR-0090 decision text and not an F-NNN.
- A bounded no-collect region for a **pure-Zig builder** (no user code, no
  eval-reentry) is **not** cw v0's un-scoped `suppressCollection` (which could wrap
  arbitrary eval-reentry — the real F-006 hazard). The region never blinds a
  safepoint / back-edge collect (`depth` is 0 there). Same verb, different hazard
  class.

The code comment is amended in the same change to record this distinction (still
refused: un-scoped suppression that could wrap eval-reentry; introduced: the bounded
pure-Zig-builder region).

## Alternatives considered (Devil's-advocate forks, fresh context — verbatim)

### Fork 1 (design) — recommended Alt A, the no-collect region

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
> wiring that rots silently. *Risks*: makes alloc-torture skip mid-fold collects — but
> only the mid-pure-Zig-fold collect F-006 forbids; it does NOT blind any
> safepoint/eval-reentry collect (depth is 0 there). Residual risk is purely forward (a
> moving GC), mitigated by a forward-note + debt row. *Diagnostic value*: preserved for
> every hazard real under F-006; declines only the non-hazard — the rule's sanctioned case.
>
> **Alt B (root every intermediate: partial Value via gc_self_guard + a NEW node-level
> guard)** — *Better*: also correct under a future moving/concurrent GC. *Breaks/gold-
> plating*: pervasive — `fromSlice` holds a whole `level_nodes: []*HamtNode` slice across
> the level loop (a scalar guard cannot root it → a second mini-root-set); `conj` has up
> to 4 unrooted-node windows; every future builder must remember to wire it or silently
> reintroduce the bug. The ENTIRE payoff is correctness against a GC the project has NOT
> committed to (F-006) — Reservation-as-bias compounded by gold-plating. Under non-moving
> mark-sweep it buys nothing A does not, at many times the surface.
>
> **Alt C (single-alloc builder + publish the one internal node)** — *Fatal, verified in
> code*: `fromSlice` does NOT have one internal node; it holds the whole tower. Publishing
> "the one TailNode" leaves the tower unrooted → torture moves the corruption from the tail
> to the tree. To fix C you rebuild Alt B's tower guard → C is either incorrect or Alt B in
> disguise.
>
> **Recommendation: Alt A.** Finished-form for the COMMITTED architecture. Alt B is right
> ONLY if F-006 flips to a moving GC — at which point B's node-guard is subsumed by the
> moving GC's own barrier/handle machinery, so B is not even the right shape for that
> future.

### Fork 2 (reversal-check) — steelmanned Alt B, then confirmed the reversal

> **Steelman of Alt B**: a GC's value is *one* invariant — "every live object is reachable
> from a precise root, always." A `suppressCollection`-shaped hatch creates two contracts
> ("rooted" OR "inside a suppress window") that every future collect-trigger must check;
> cw v0 deliberately refused exactly this. Under that lens Alt A is functionally identical
> today but a *worse finished form*.
>
> **Why the steelman does NOT survive F-006**: (1) the precise-root surface is ALREADY a
> union of bespoke mechanisms (permanent_roots, eval_frame chain, binding heads, ns_vars,
> macro_root_slot, AND gc_self_guard — itself an exception to the operand-stack model); a
> bounded pure-Zig critical section is no more a "second contract" than macro_root_slot
> already is. (2) A bounded region over pure-Zig builders that cannot reenter eval is NOT
> v0's un-scoped hatch (which could wrap eval-reentry — the real hazard); same verb,
> different hazard class. (3) "Right shape for a moving GC" cuts AGAINST B: a moving GC
> supplies its own root-fixup machinery, so B's hand-rolled node-guard array would be
> ripped out — B is speculative infra mis-shaped for the future it targets
> (Reservation-as-bias).
>
> **Stance verdict**: ADR-0090's decision TEXT does not forbid Alt A for builder-internal
> nodes; the "never suppress" line is a code-comment preference (root_set.zig:150),
> loop-amendable. **Reversing the rejection is sound, not the opposite premise error**,
> provided: (a) justify on finished-form grounds, not diff size; (b) amend the code
> comment to distinguish the still-refused un-scoped suppression from the introduced
> bounded region; (c) keep the forward (moving-GC) debt row.
>
> **Recommendation: Alt C (hybrid)** — keep the landed `gc_self_guard` for the op-loop
> partial-Value window, add the bounded region for the builder-internal raw-node window;
> collapse to pure Alt A only if gc_self_guard proves subsumed (verify, don't assume).

**Implementation finding (post-Fork-2)**: verified that under the SYNCHRONOUS
alloc-torture the whole-body region subsumes the op-loop partial-Value window (no
alloc between builder calls in the in-VM folds), so the synchronous fix is pure Alt A
and `gc_self_guard` stays inert future infra (kept). The reentrant partial-Value
window (lazy-realization/reduce) is the genuinely-different D-244 #4b scope.

## Consequences

- `CLJW_GC_TORTURE_ALLOC` validates all SYNCHRONOUS collection-building code again
  (16 builder probes in `test/e2e/phase16_gc_torture.sh`) → unblocks D-386 sub-step 2
  (op_top register hoist) validation for synchronous builders.
- A real latent UAF/corruption (reachable once alloc-driven auto-collect lands) is
  closed for the synchronous builder class.
- Per-builder cost: 2 threadlocal increments (no lock). Always-on; measured negligible.
- The eval-reentrant lazy-realization/reduce rooting under alloc-torture remains open
  as **D-244 #4b** (a wrong-count, not a panic — see the `(into {} (map f …))` probe).

## Affected files

- `src/runtime/gc/gc_heap.zig` — `fabrication_depth` threadlocal +
  `enterFabrication`/`exitFabrication` + the alloc-torture gate (+ the future
  auto-collect note).
- `src/runtime/collection/{vector,map,set,list}.zig` (+ `transient/*`) — wrap each
  multi-alloc builder (`vector.conj`/`fromSlice`/`assoc`/`pop`; `map.assoc`/`dissoc`;
  `set.conj`/`disj`; `list.consHeap`; transient `toPersistent`/`fromSet`). `map.assoc`'s
  array-map fast path + `map.fromLiteralPairs` are single-alloc → not bracketed.
- `src/runtime/gc/root_set.zig` — amend the `gc_self_guard` docstring's "never
  suppress" line to scope it to un-scoped eval-reentry suppression.
- `test/e2e/phase16_gc_torture.sh` — the 16 alloc-torture builder probes.
- `.dev/debt.yaml` — D-244 #4 discharged (synchronous builders) + the D-244 #4b
  (reentrant realization) follow-on + the forward (moving-GC) row.

## Revision history

- 2026-06-16 issued + **REJECTED same day**, then **REVERSED to ACCEPTED same day**.
  The design (Alt A no-collect region) was DA-forked (Fork 1, recommended Alt A). It
  was then rejected on the belief that Alt A contradicts ADR-0090's "never suppress,
  publish precise root" stance. A reversal-check (Fork 2, steelmanning Alt B) +
  reading ADR-0090's decision text directly found that belief rested on **over-reading
  root_set.zig:150's code comment as binding ADR text** — ADR-0090 decides the
  multi-thread safepoint and rejects a per-site guard-LIST for partial VALUES; it says
  nothing about builder-internal raw nodes and defers concurrent GC to §89.2. Under
  F-006 the no-collect region is the finished form; Alt B is gold-plating for an
  uncommitted moving GC. Reversed and implemented. Design notes:
  `private/notes/9.2.S-d244-4-design.md` (rejected-Alt-A record) +
  `private/notes/9.2.S-d244-4-decision.md` (the reversal).
