# ADR-0067 — `eduction` as a re-iterable `deftype`, not an alias for `sequence`

- **Status**: Proposed → Accepted (2026-06-01)
- **Discharges**: D-160 (the `eduction` residual; `sequence` landed earlier the same day)
- **Related**: ADR-0066 (deftype macro), ADR-0036 (`.claude/rules/dual_backend_parity.md`),
  F-002 (finished form wins), F-011 (behavioural equivalence to Clojure JVM),
  D-189 (first/rest Seqable→seq coercion, surfaced here), the `sequence` push→pull
  bridge (`-tx-seq-pump`, core.clj)

## Context

`(eduction xform* coll)` returns a value that is both **reducible** (each
`reduce` re-runs the transducer pipeline) and **seqable** (a lazy view).
cljw's `sequence` (the push→pull lazy bridge) already exists. The open
question: implement `eduction` as a thin alias over `sequence`, or as its
own type?

Facts (verified in-repo): cljw's `reduce` (`higher_order.zig:177`) routes a
receiver carrying an `IReduce -reduce` MethodEntry through it
(receiver-first: `(-reduce coll f)` / `(-reduce coll f init)`); `seq`
(`sequence.zig:195`) routes through `Seqable -seq`. `deftype` protocol
bodies + variadic protocol-method params (`[this f & more]`) both work.
So a `deftype` extending `IReduce` + `Seqable` is dispatchable.

## Decision

Implement `eduction` as a `deftype Eduction [xform coll]` extending
`IReduce` (`-reduce`→`transduce`, variadic to serve both the 2-arg and
`into`'s 3-arg call) and `Seqable` (`-seq`→`sequence`). `(completing f)`
wraps the reducing fn so an arbitrary `f` (e.g. `conj`, which has no 1-arg
completion arity) works through the transducer protocol.

This makes eduction **re-iterable** — the JVM contract — and **distinct
from `sequence`**: a counter xform reduced twice over the same eduction
fires 6 times (cljw + clj), where a cached-lazy-seq alias would fire 3.

## Consequences

- eduction is a genuine reducible (no seq allocation on the reduce path)
  and a lazy seqable (via the `sequence` bridge) — F-011 faithful.
- First live consumer of the `IReduce -reduce` **and** `Seqable -seq`
  deftype slow paths together; the `-reduce` variadic widens the
  IReduce-declared `[c f]` to cover `(-reduce c f init)`.
- `first`/`rest` applied **directly** to an Eduction raise (cljw's
  first/rest dispatch `ISeq -first`/`-rest` without a Seqable→seq
  coercion fallback). `(seq e)` / `(into [] e)` / `(map f e)` all work.
  The direct-coercion gap is **D-189** (broader than eduction).
- No new Zig primitive, no new analyzer Node — pure `.clj` over existing
  machinery; both backends agree (e2e on the real binary; the diff
  Fixture loads no core.clj so eduction is verified there via `--compare`
  + the shared dispatch path, not a diff case).

## Alternatives considered (Devil's-advocate output, verbatim summary)

A `general-purpose` Devil's-advocate fork (fresh context, F-002/F-011/F-009
constraints) produced three shapes:

- **Alt 1 — smallest-diff (closure):** `(def eduction (fn* [& a] (sequence
  (apply comp (butlast a)) (last a))))`. One line, rides the landed bridge.
  **Breaks:** NOT re-iterable — `sequence` caches (the `-tx-seq-pump`
  volatile realizes once), so a second `reduce` replays the cache, not the
  xform; a side-effecting `(eduction (map prn) …)` prints once vs JVM's
  every-reduce. Observationally **identical to `sequence`** → redundant-alias
  smell (Smallest-diff bias, principle.md). Real F-011 divergence.
- **Alt 2 — finished-form-clean (deftype):** `deftype Eduction` + IReduce +
  Seqable (the chosen shape). Re-iterable, distinct from `sequence`, no seq
  alloc on reduce. Cost: first consumer of both slow paths; `-reduce` must
  be variadic for the collapsed-IReduce 3-arg `init` call.
- **Alt 3 — wildcard (reducible-only deftype):** IReduce but no Seqable;
  `(seq e)` raises. **Breaks:** JVM eduction IS seqable; withholding `-seq`
  is a gratuitous F-011 gap when `sequence` gives the seq view for free.

DA recommendation: **Alt 2** — the unique shape that is both re-iterable
(F-011) and not a `sequence` alias (F-002). Explicitly NOT downgraded to
Alt 1 on diff/LOC grounds (that is the Cycle-budget defer smell; F-002 says
size is not a constraint). The DA flagged a prerequisite — multi-arity
protocol-method bodies are unsupported — resolved by a **variadic**
`-reduce` `[this f & more]` (confirmed working), so no PROVISIONAL was
needed. The main loop adopts Alt 2.
