# ADR-0100 — The `'` arithmetic operators (`+'` `-'` `*'` `inc'` `dec'`) auto-promote, matching JVM Clojure (D-260)

- **Status**: Proposed → Accepted (2026-06-06)
- **Driven by**: D-260 — found during the CFP campaign that cljw's `'` operators
  raise `integer_overflow` on Long overflow, the exact inverse of JVM Clojure.
- **Relates to**: F-005 (numeric tower = JVM-surface; non-prime `+`/`*` already
  auto-promote), F-011 (behavioural equivalence on the observable surface), F-002.

## Context

In JVM Clojure the **`'`-suffixed** operators are the **auto-promoting** family:
`+'` `-'` `*'` `inc'` `dec'` promote `Long`→`BigInt` on overflow and **never
throw**. The non-prime `+` `*` `-` `inc` `dec` are the **throwing** ones
(`(* 1000000000000 1000000000000)` → `ArithmeticException: long overflow`).
Verified against the clj 1.12 oracle:

```
clj (*' 1000000000000 1000000000000) => 1000000000000000000000000N   ; promotes
clj (+' 9223372036854775807 1)       => 9223372036854775808N         ; promotes
clj (* 1000000000000 1000000000000)  => ArithmeticException "long overflow"
```

cljw has this **inverted**. Per F-005, cljw's **non-prime** `+`/`*`/`-` auto-promote
(an intentional, documented divergence from JVM's throwing non-prime ops). But
cljw's `'` ops were implemented as **strict** — `plusStrict`/`minusStrict`/
`starStrict`/`incStrict`/`decStrict` in `src/lang/primitive/math.zig`, routed
through `promote.addStrict`/`subStrict`/`mulStrict`, which raise `integer_overflow`
— with a docstring falsely claiming "Mirrors JVM Clojure's `+'`". So
`(*' 1e12 1e12)` **throws** in cljw but promotes in JVM. (D-260's first read
"`+'` works" was a false positive: its input `9223372036854775807` exceeds cljw's
i48 fixnum range and is already a BigInt, so no fixnum overflow occurred to raise
on.) There is **no AD-NNN or ADR** recording an intentional strict-`'` divergence;
the inversion rests solely on the wrong docstring.

## Decision

**Make `+'` `-'` `*'` `inc'` `dec'` auto-promote — route them through the same
promoting path the non-prime ops use — and delete the strict family entirely.**

1. Re-point the `'` registrations in `math.zig` to the promoting fns (`plus`/
   `minus`/`star`/`inc`/`dec`).
2. **Delete** `plusStrict`/`minusStrict`/`starStrict`/`incStrict`/`decStrict`
   (math.zig) **and** `addStrict`/`subStrict`/`mulStrict` (`promote.zig`) **and
   their unit tests** — the DA verified these have zero callers outside the
   registration table and their own pin tests, so deletion is clean and avoids a
   dead-code island the `no_unused` gate would flag.
3. Fix the docstrings to state the truth: in cljw the `'` ops are the
   auto-promoting family, **behaviourally identical to the non-prime ops**,
   because cljw's non-prime ops also promote (F-005). JVM splits throwing-`*` vs
   promoting-`*'`; cljw collapses the throw side into promote, so both spellings
   legitimately converge on one promoting semantics.
4. Land `test/diff/clj_corpus/numeric_prime_ops.txt` (per `clj_diff_sweep.md`
   Discipline 1) asserting the `'` ops promote, so the parity claim is mechanically
   re-checkable and a regression flips the gate red.

This is a **bug→fix** (F-011), not an accepted divergence: no project invariant
licenses diverging on `'`-op promotion.

## Alternatives considered

The mandatory Devil's-advocate subagent (fresh context, F-005/011/002 pasted)
produced the following, reflected verbatim:

> **No alternative below requires violating an F-NNN. The finished-form-clean
> option (Alt-2) is fully inside the envelope.** F-005 already mandates that
> cljw's integer ops auto-promote Long→BigInt; F-011 mandates the user-observable
> surface match clj 1.12, where `*'` promotes. So "make `'` ops promote" satisfies
> both invariants simultaneously — there is no tension to resolve.
>
> I verified the blast radius before drafting: the `plusStrict`/`minusStrict`/
> `starStrict`/`incStrict`/`decStrict` registrations and the `addStrict`/
> `subStrict`/`mulStrict` promote.zig helpers have **zero callers** outside
> `math.zig`'s registration table and promote.zig's own unit tests. The strict
> family is a closed, dead-end surface.
>
> **Alt-1 — Smallest-diff: re-point the 5 registrations to the promoting fns.**
> Change only the registration table; leave the strict fns physically in the tree
> (unreferenced by the registry, still referenced by their own tests). Fix the
> false docstrings. (a) Better: minimal diff; the 5 prime ops immediately stop
> throwing; promote.zig `*Strict` unit tests keep passing untouched; reversible.
> (b) Breaks: leaves five dead Zig functions + three dead helpers reachable only
> from their own pin tests — a self-justifying dead-code island. The `no_unused`
> lint gate (ADR-0003) will likely flag the unreferenced math.zig `plusStrict`/etc
> as unused, so this "smallest" diff probably **does not even compile-pass the
> gate** without deleting them. This is the **Smallest-diff bias smell**. (c)
> Envelope: in-envelope behaviourally, but conflicts with the no_unused gate and
> F-002 finished-form spirit — in-envelope-but-smelly.
>
> **Alt-2 — Finished-form-clean: delete the strict family entirely, route `'`
> ops through the promoting path, add a corpus pin (= the draft, sharpened).**
> Delete the strict fns from math.zig AND promote.zig AND their unit tests.
> Register the `'` ops against the promoting fns. Fix docstrings to state the
> convergence. Add `test/diff/clj_corpus/numeric_prime_ops.txt`. (a) Better: the
> draft only names the math.zig fns; this also deletes the promote.zig `*Strict`
> helpers + tests, otherwise the strict semantics survive as a second dead island
> kept alive only by its own pin tests. Removes the entire strict surface so no
> future reader wonders "why are there two families and which is the contract."
> The corpus pin makes the parity claim mechanically re-checkable (anti-D-177).
> (b) Breaks: largest diff (deletes ~8 functions + tests). Removes cljw's *only*
> overflow-detecting path — after this, no cljw operator throws on overflow. Per
> F-002, diff size is explicitly not a constraint. (c) Envelope: fully in-envelope
> and closest to finished form.
>
> **Alt-3 — Wildcard: keep `'` strict, re-found it as cljw's deliberate
> overflow-detecting family and record AD-NNN.** Since cljw's non-prime ops
> promote (F-005), cljw has no throwing operator; Alt-3 repurposes `'` as that
> missing strict family with an AD. (a) Better: gives users who want overflow
> detection an operator; zero deletion. (b) Breaks — decisively: it **breaks
> F-011 head-on.** `'` is a decade-old spelling meaning "auto-promote" to every
> Clojure programmer; portable `.clj` uses `*'`/`+'` precisely because they want
> BigInt promotion (e.g. `(reduce *' (range 1 30))`). Under Alt-3 that throws
> where JVM produces a BigInt — exactly the divergence F-011 forbids, and
> `accepted_divergences.md` bars accepting it: an AD needs a *project invariant*
> as `derives_from`, and "we'd like a strict op so let's hijack a JVM-meaningful
> name" is convenience, not invariant. An AD here would be a lie dressed as a
> contract. On the sub-question — should cljw offer a strict op at all? Possibly,
> but it must NOT steal the `'` spelling; mint a new non-colliding name in its own
> ADR. (c) Envelope: **out of envelope — violates F-011.** Recording it as AD-NNN
> does not rescue it (no invariant to cite). This is the leading finding.
>
> **RECOMMENDATION — Alt-2 (the draft, sharpened to also delete the promote.zig
> `*Strict` layer + its tests).** F-011 is decisive and points one way: clj
> `(*' …)` promotes, cljw must match — only Alt-1/Alt-2 deliver that, Alt-3 is
> rejected because it breaks F-011 and the AD escape hatch is unavailable. F-005
> makes Alt-2 coherent: cljw collapsed the throw side into promote, so both
> spellings legitimately converge on one promoting semantics. F-002 breaks the
> Alt-1/Alt-2 tie toward Alt-2: Alt-1 leaves a dead island the no_unused gate
> rejects and a finished-form owner would delete — "Alt-2 is a bigger diff" is not
> a valid reason to downgrade. Sharpening: also delete the promote.zig
> `addStrict`/`subStrict`/`mulStrict` + their tests (verified no other callers).
> Note for Consequences: after Alt-2 cljw has no integer operator that throws on
> overflow; a future overflow-detecting op is a separate ADR minting a new non-`'`
> name.

**Adopted: Alt-2**, with the sharpening (delete the promote.zig strict layer +
tests). Alt-3 is the salvageable-idea source (a future strict op under a new
name) but is rejected here as F-011-violating.

## Consequences

- **Positive**: `(*' …)`, `(+' …)`, `(-' …)`, `(inc' …)`, `(dec' …)` now match
  clj 1.12 (auto-promote, never throw) — an F-011 fix in the CFP-showcased numeric
  tower. The strict family is gone, so cljw has exactly one integer-arithmetic
  semantics (promote) under both spellings.
- **Consequence to record**: after this, **no cljw integer operator throws on
  overflow** — every integer op promotes (the correct joint consequence of F-005
  + ADR-0100). If the project later decides users need overflow detection, that is
  a *separate* ADR minting a new, non-`'` name; it must not reopen ADR-0100 or
  re-strict the `'` ops.
- **Discharges**: D-260.

## Affected files

- `src/lang/primitive/math.zig` — delete the 5 `*Strict` fns; re-point the `'`
  registrations to the promoting fns; fix docstrings.
- `src/runtime/numeric/promote.zig` — delete `addStrict`/`subStrict`/`mulStrict`
  + their unit tests.
- `test/diff/clj_corpus/numeric_prime_ops.txt` — new parity corpus.
- `.dev/debt.yaml` — D-260 discharged.
