# ADR-0113 — Deferred unsupported `clojure.lang.*` host-class references

- **Status**: Proposed → Accepted
- **Date**: 2026-06-07
- **Discharges**: unblocks integrant (Stage 1.3 verified_projects, 9th proof);
  partially relieves the standing "clojure.lang.Compiler/Reflector/RT deferred"
  blocker class (schema / clip / data.avl park there).
- **Cross-refs**: ADR-0059 (no-JVM class hierarchy), F-002 (finished-form),
  F-011 (behavioural equivalence), F-013 (definition-derived); AD-022 (the
  recorded divergence); the no-op-stub discipline (`provisional_marker.md`
  — explicit runtime error OK, silent no-op forbidden).

## Context

Many real Clojure libraries fail to **load** on cljw not because their core
needs unsupported interop, but because a **peripheral** function's body names a
JVM-internal class cljw does not implement (`clojure.lang.RT`,
`clojure.lang.Compiler`, `clojure.lang.Reflector`). cljw's analyzer resolves
these eagerly at definition time, so

```clojure
(defn- resources [path]
  (let [cl (clojure.lang.RT/baseLoader)]          ; <- analysis-time name_error
    (enumeration-seq (.getResources cl path))))
```

raises `namespace_unknown` while *defining* `resources`, blocking the WHOLE
namespace — even though `resources` is on an optional code path (classpath
resource loading) the library's core never touches.

Concrete driver: **weavejester/integrant** (a popular DI/lifecycle lib) parks
ONLY on `(clojure.lang.RT/baseLoader)` inside its optional `load-hierarchy`
helper. Its core (`init`/`halt!`/multimethods/refs) is pure. (cljw already
tolerates `(catch java.io.FileNotFoundException _)` — unknown catch classes
never match, which is correct.)

## Decision

When the analyzer reaches a qualified reference `Ns/member` whose `Ns` is an
unresolved class with the unambiguous JVM-internal prefix **`clojure.lang.`** or
**`clojure.asm.`**, instead of raising `namespace_unknown` at analysis, rewrite
it to a loud runtime call `(rt/__unsupported-host-ref "Ns/member")` that raises
`feature_not_supported` when **evaluated**. The enclosing fn DEFINES, the
namespace LOADS, and the reference errors only if the unsupported path is
actually invoked.

- **One interception point** (`analyzeSymbol`'s `namespace_unknown` branch)
  covers BOTH call-head `(clojure.lang.RT/baseLoader …)` and value position
  `clojure.lang.Compiler/CHAR_MAP` — both flow through `analyzeSymbol`.
- **Representation = rewrite to an existing raising builtin**, NOT a new
  analyzer Node. A pure "raise at eval" needs no bespoke node; reusing the call
  path is dual-backend-correct by construction (no parity arms to keep in sync)
  and a builtin call is itself a clean future-Wasm lowering point. (This is the
  one place the main loop diverged from the Devil's-advocate's "dedicated node"
  preference — see Alternatives; the DA's substantive point, *coverage of both
  positions*, is fully taken.)
- **Strict prefix allowlist** `clojure.lang.` / `clojure.asm.` is the
  discriminator: these are provably non-values under ADR-0059 and never a user
  alias typo, so the deferral cannot mask a typo (a bare `(myalias/foo …)` stays
  a loud `namespace_unknown`). `java.*` is intentionally EXCLUDED — those may be
  real host surfaces cljw should implement (e.g. `java.net.URI`), so they stay
  loud and the gap stays visible.

Sibling additions this cycle (same integrant driver, same loud-stub philosophy):
`enumeration-seq` / `iterator-seq` ship as explicit `feature_not_supported`
stubs (clojure.core fns over `java.util.Enumeration`/`Iterator` host types cljw
has no model for); `defmethod` now accepts an empty body (`(defmethod m dv
[params])` → nil, clj parity); `defmulti` now skips + **attaches** an optional
docstring/attr-map before the dispatch fn (was mistaken for the dispatch fn →
"Cannot call value of type 'string'").

The divergence (a `clojure.lang.*` ref that JVM would resolve now raises at
call time) is recorded as **AD-022**.

## Consequences

- A class of libraries whose core is pure but whose periphery touches
  `clojure.lang.*` internals can now LOAD and run their core (integrant proven;
  schema/clip relieved of their `clojure.lang.*` blocker, though they may have
  further gaps).
- An unsupported `clojure.lang.*` reference fails at CALL time, not load time —
  a louder, later, but still explicit error (never a silent no-op). Consistent
  with the no-op-stub discipline (transient-stub category).
- Typos stay loud: only the strict JVM-internal prefixes defer.

## Alternatives considered

Devil's-advocate fork (fresh context, F-NNN-constrained), verbatim:

> **1. Smallest-diff** — Keep the narrow rewrite but make the discriminator
> *purely* "unresolved class-shaped head" and skip even the prefix gate; rewrite
> ANY unresolved `Foo.Bar/method` call-head to the raising builtin.
> - **Better**: zero allowlist maintenance; integrant AND any future lib parking
>   on an unimplemented host method loads immediately.
> - **Breaks**: exactly the F-011 / "no silent lies" hazard. A user typo
>   `(my.ns/hlper x)` now silently DEFINES and only errors when called — masking
>   a real load-time bug. The prefix gate exists precisely to keep typos loud.
>   Rejecting.
>
> **2. Finished-form-clean** — A dedicated `UnsupportedHostRef` analyzer node
> carrying `(class, member, position)`, emitted for BOTH call-position and
> value-position (`clojure.lang.Compiler/CHAR_MAP`) unresolved
> `clojure.lang.*`/`clojure.asm.*` refs, with dual-backend arms that raise
> `feature_not_supported` on evaluation.
> - **Better**: call-position-only WILL re-park the same class of libs (schema on
>   `CHAR_MAP`); a node covering value-position closes the category instead of
>   opening a sequel ADR. A real node gives the future Wasm backend a clean
>   lowering point and a single audit site; the payload makes the error precise.
> - **Breaks/risks**: bigger — new Node kind, two eval arms, value-position
>   semantics. Risk of over-generalizing position handling cljw has no other use
>   for yet.
>
> **3. Wildcard** — Don't touch the analyzer; add a bootstrap shim namespace
> providing `clojure.lang.RT`/`Reflector`/`Compiler` as cljw-level stub vars
> whose members raise.
> - **Better**: pure-Clojure, no Zig analyzer change, trivially extensible.
> - **Breaks**: `clojure.lang.*` are CLASSES not namespaces; faking them as
>   resolvable namespaces lies about cljw's structure (violates ADR-0059), and a
>   member cljw later DOES implement now collides with a stub. Worst masking
>   surface. Rejecting.
>
> **Recommendation**: Take **Alt 2 (dedicated node, both positions)** despite the
> larger diff — F-002 says size is not a constraint and call-position-only is a
> false economy that guarantees a sequel ADR. Keep the strict `clojure.lang.`/
> `clojure.asm.` allowlist — these are provably non-values under ADR-0059, never
> a user typo, so the masking concern that kills Alt 1 does NOT apply. Record the
> JVM-divergence as an AD-NNN per F-011.

**Main-loop resolution**: Adopt Alt 2's **coverage** (both call- and
value-position) and its **strict prefix allowlist** + AD record — those are the
substantive, finished-form points. Decline Alt 2's **dedicated-node
representation** in favour of rewrite-to-raising-builtin: for a behaviour that is
purely "raise at eval", a new Node adds four dual-backend arms (TreeWalk + VM
compile + VM dispatch + diff case) to maintain for ZERO added capability over a
builtin call, and the parity surface is itself a risk
(`dual_backend_parity.md`). A builtin call IS a clean Wasm lowering point. This
is a representation choice on engineering-surface grounds, not a cycle-budget
downgrade (the coverage — the thing F-002 protects — is fully taken).
