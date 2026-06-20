# ADR-0156: Bundle official Clojure stdlib eagerly; contrib for completeness

- **Status**: Accepted (2026-06-20)
- **Deciders**: autonomous loop + user directive (2026-06-20 chat)
- **Supersedes / relates**: ADR-0035 (embedded resolver), ADR-0056 (AOT
  bootstrap cache), D-452 (eager non-core libs in the blob), D-475 (the
  spec.alpha port), D-477 (the latent baseline-binding gap this surfaced).

## Context

The clojure.spec.alpha port (D-475) reached functional clj-parity on a
`-cp` classpath dev harness. Promoting it for real means bundling it. This
forced a standing decision the project had not made explicitly: **which
Clojure namespaces ship inside the `cljw` binary, and are they loaded
eagerly at startup or lazily on require?**

Today all 22 non-core bundled `clojure.*` libs are **eager** — AOT-compiled
into the startup bytecode blob (cache_gen → `loadCoreAot` replay). Cold-start
is ~0ms because the blob is replayed bytecode, not re-parsed. The concern: a
stdlib + contrib *sweep campaign* (the 2026-06-20 user directive — port every
official stdlib ns + verify against every contrib lib for completeness / bug
audit) would add many libs; if all go eager, the blob + binary grow
cumulatively.

Two facts frame the choice:

- **Official stdlib** (everything in `clojure/src/clj/clojure/` — ships in
  `clojure.jar`, no external deps) is part of "the language". A user expects
  `clojure.set` / `clojure.spec.alpha` present without a dependency step.
- **contrib** (`org.clojure/core.async`, `data.json`, `math.combinatorics`,
  … — separate Maven artifacts, `deps.edn`-required upstream) is NOT part of
  `clojure.jar`. cljw already bundles a few (data.json/csv, tools.cli) for
  convenience, but contrib need not be in the startup binary.

## Decision

1. **Official Clojure standard-library namespaces are eager-bundled** into
   the `cljw` binary (the existing `FILES` AOT mechanism). `clojure.spec.alpha`
   + `clojure.spec.gen.alpha` are added now (FILES[24]/[25], gen before alpha).
2. **contrib libraries are used for completeness/bug-audit verification**
   (clj-diff sweep against the cloned `org.clojure/*` repos under
   `~/Documents/OSS/`); they need NOT be eager-bundled, but the require path
   should stay easy (the embedded resolver + a filesystem resolver over the
   clones). Bundling a high-demand contrib lib (as with data.json) remains
   acceptable, not required.
3. **Accept the startup-time + binary-size increase for simplicity now**
   (measured: cold-start stayed ~0ms after spec — per-lib AOT replay is
   negligible). Keep the bundled-lib list **data-driven** (`FILES` +
   `lookupEmbeddedFile`) so the future eager→lazy switch is a local change.
4. The spec source is upstream spec.alpha with **5 no-JVM adaptations**
   (Spec-class→protocol-var; fn-sym→nil; RT/checkSpecAsserts→atom;
   bytes?-gen-builtin dropped; the top-level `(set! *warn-on-reflection* true)`
   dropped — a cljw no-op that would also trip the eager-load baseline-binding
   gap, D-477). EPL variant-① attribution per `clj_attribution.md`.
5. A build-time diagnostic landed in `buildBootstrapEnvelope`: an AOT eval
   error now prints `[AOT-FAIL] <file> form #N` (was a bare `ValueError`),
   so the campaign's future bootstrap traps are locatable.

This is the user's directed choice (chat, 2026-06-20): "起動時間/バイナリ
サイズの増加は許容してシンプルに進める、ただし将来の切り替えやすさは意識".

## Alternatives considered (Devil's-advocate fork, verbatim)

**Leading caveat:** The cleanest finished form (lazy/on-demand stdlib AOT
blobs) is *partially* in tension with the user's directive ("stdlib SHOULD be
in the binary; proceed simply"). That directive is project law, so a
pure-lazy stdlib violates it. But "in the binary" ≠ "eagerly *loaded* at
startup" — a blob can ship in the binary yet replay on first reference. Alts
2 and 3 exploit that gap without violating the directive.

**1. SMALLEST-DIFF — eager-bundle spec, but split policy from mechanism.**
Bundle spec as proposed, but do NOT inscribe "all clojure.jar namespaces are
eager" as a standing policy ADR yet; record it as an observation. *Better:*
avoids a Reservation-as-bias smell — the policy is asserted from one data
point (spec, ~0ms); gen.alpha pulls test.check-style generators; future eager
stdlib members may not be ~0ms (F-003: defer structural policy to its owner).
*Costs:* the "easy mental model" the user wanted is left less crisp.

**2. FINISHED-FORM-CLEAN — ship-in-binary, replay-on-first-require (lazy-AOT)
for the whole bundled set.** Every bundled lib's AOT blob lives in the binary
(satisfies "in the binary"), but `loadCoreAot` replays only true-core eagerly;
spec and peers replay on first `require`/reference. *Better:* satisfies F-002
directly — the data-driven eager→lazy switch the ADR *promises as future work*
IS the finished form, so do it now rather than bank debt; keeps cold-start
structurally flat regardless of how many libs accrete; the ~0ms claim stops
being per-lib luck. *Costs/breaks:* needs a require-time blob-replay path that
doesn't exist yet; first-require latency moves off cold-start onto first-use
(must verify spec's macro-heavy load stays sub-perceptible); larger diff (not
a valid objection per F-002).

**3. WILDCARD — vendor spec verbatim; move the no-JVM adaptations into the
runtime, not the .clj.** Bundle unmodified upstream spec.alpha; implement
Spec-class→protocol, fn-sym→nil, checkSpecAsserts as host shims so the .clj is
byte-identical to clojure.jar. *Better:* maximal F-011 parity + trivial future
upstream resync (re-vendor, no re-patch); the adaptations become reusable host
primitives other stdlib libs will also need. *Costs:* upfront runtime shim
work; risk the shims under-cover spec's reflection assumptions; over-engineered
if no second consumer materializes.

**DA recommendation:** Alt 2 (finished-form-clean). 

**Loop's decision within the F-NNN + user-directive envelope:** the user
explicitly chose the eager default for simplicity *now*, with the eager→lazy
switch kept easy for later. The user directive is project law above the
cycle-budget concern, so Alt 2 is recorded as **the finished form the future
switch (D-477 / a later lazy-AOT ADR) will realize**, not adopted this cycle.
Alt 1's "don't over-inscribe policy" point is mooted because the user
*declared* the stdlib-eager policy (not a one-data-point inference). Alt 3's
runtime-shim resync benefit is noted for the campaign but deferred (the 5
in-.clj adaptations are small and documented in the file header).

## Consequences

- spec.alpha/gen.alpha load from the bundle with no `-cp`; clj-verified
  surface (corpus `test/diff/clj_corpus/spec.txt`, 16 cases). Residual diffs
  are the accepted `rt/`-qualification family (`rt/int?` vs `clojure.core/int?`
  in printed pred forms) — derive from ADR-0033/AD-038.
- Binary grows by spec's bytecode; cold-start unchanged (~0ms).
- The stdlib-sweep campaign now has a clear rule: stdlib → eager FILES entry;
  contrib → verify + optional bundle.
- D-477 records the latent eager-load baseline-binding gap (a future bundled
  lib with a meaningful top-level config-var `set!`).
- When the eager blob grows enough to matter, Alt 2 (lazy-AOT) is the
  pre-decided finished form.

## Affected files

- `src/lang/bootstrap.zig` — FILES[24]/[25] + lookupEmbeddedFile entries.
- `src/lang/clj/clojure/spec/alpha.clj`, `…/spec/gen/alpha.clj` — bundled.
- `src/app/builder.zig` — AOT-fail diagnostic.
- `test/diff/clj_corpus/spec.txt` — corpus lock.
- `.dev/debt.yaml` — D-477.
