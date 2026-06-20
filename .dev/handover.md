# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: each unit's
  smoke-green commit is followed immediately by `git push origin main` (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`, pre-JIT). Per-commit =
  smoke; full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: continue the **stdlib/contrib sweep campaign**
  (user directive 2026-06-20, memory `clj_stdlib_contrib_sweep_campaign` + ADR-0156).
  The **clean frontier is now largely drained**: all cleanly-bundleable official stdlib
  is bundled (spec.alpha/gen/core.specs.alpha, datafy, test.junit + the pre-existing
  set); the remaining stdlib needs host features cljw lacks by design — `clojure.repl`
  `source` (classpath source), `clojure.java.shell` (process exec), `clojure.xml` (SAX),
  `clojure.core.reducers` (ForkJoin, D-473), `clojure.core.server` (sockets). Pure
  contribs are verified (math.combinatorics + the pre-existing `verified_projects/`);
  the rest are host-coupled (core.match→`Class/forName` D-479, tools.reader→host reader,
  rrb-vector/algo.*→ForkJoin/Future). The **core clj-diff bug sweep is now drained**
  (2026-06-21 session: 14 areas byte-identical to clj — metadata/privacy/destructuring/
  namespaced-map/string/numeric/sorted/set/bit-ops/polymorphism/read-print/catch-by-class/
  lazy-realization; 4 real bugs FIXED + AD-050/AD-007). **First commit on resume = D-485**
  (general primitive-reentry depth guard — the highest-value finished-form item, found this
  session): a watch/validator/comparator/reducer that re-enters the evaluator unboundedly
  overflows the NATIVE stack → SIGSEGV (the watch case is already partial-fixed; the GENERAL
  fix = a shared re-entry budget, cleanest as making the VM frame budget GLOBAL across the
  vt.callFn re-entry boundary). ADR-level: needs cap measurement + a Devil's-advocate pass.
  Then drain other deferred deep items (D-482 seq-laziness, D-479 Class/forName, D-480
  Serializable). Policy unchanged: **official stdlib → eager bundle; contrib → verify**.

- **Forbidden this session**: speculative JIT integration before zwasm's API stabilises
  (read `.dev/zwasm_capabilities.md` — JIT row BUILDING, not adoptable). `git push
  --force*`. Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for a probe (ADR-0133 — ReleaseSafe).
  A reader-macro / syntax-quote NS-qualification MUST stay `rt/`, not `clojure.core/`
  (AD-038/AD-049).

## Last landed (git log = SSOT; all pushed)

**Differential bug-sweep (2026-06-21, post-stdlib-campaign): 14 areas confirmed
byte-identical to clj; 4 real generic bugs FIXED + 2 divergences classified.**
- **Fixes**: `defmacro ^:private` now sets the Var private flag (was leaking private
  macros into ns-publics, 8b834d2e) · unary `(- 0.0)` IEEE-negates floats (was +0.0,
  659c6f1d) · transient READS (count/nth/get/contains?) now throw on a consumed
  transient like writes (d011849a) · self-triggering atom watch raises a graceful
  Stack-overflow instead of SIGSEGV (b69d97a9, watch-nesting guard cap 256).
- **Classified**: AD-050 (float-zero divisor → IEEE ±Inf on all cljw `/` paths; clj's
  inline-vs-runtime throw is an unreproducible JVM artifact) · AD-007 extended to cover
  `(class <caught-ex>)` exception-class mapping.
- **D-485 filed** (open): general primitive-reentry native-stack guard — the watch fix
  is the partial; validators/comparators/reducers still unguarded (= resume's 1st task).
- Earlier same-day: stdlib/contrib campaign (spec.alpha/gen/core.specs.alpha + datafy +
  test.junit bundled, ADR-0156; ~16 generic fixes + D-481 GC-lifetime fix) — see git log.
- **ADs/debt**: AD-049 (spec `rt/` form) · D-479 (core.match Class/forName, deferred) ·
  D-482 (cljw eagerly counts cons/take outputs, deferred). builder.zig has an AOT-fail
  `<file> form #N: <msg>` diagnostic. Core clj-diff sweeps (~110 exprs) found ~1 real gap
  — cljw core is mature.

## North star (context, not the immediate task)

cljw's differentiator = **Wasm/edge-native (gap area II) × VM-perf fusion→JIT (gap area III)**.
The embedded **zwasm** runtime is growing a **JIT-backed embedding API** (ADR-0200) — the
cljw pin is still pre-JIT. Adoption is gated on zwasm marking it ready + a user-confirmed
pin bump. Tracker + trigger: `.dev/zwasm_capabilities.md`.

## Cold-start reading order (resume)

handover → memory `clj_stdlib_contrib_sweep_campaign` (the active campaign + policy) →
`.dev/project_facts.md` (F-002 finished-form / F-011 clj-parity) → ADR-0156 (stdlib-eager /
contrib-completeness) → `.dev/debt.yaml` D-477 (latent eager-load baseline-binding gap) →
`private/notes/spec-bundle-promotion.md` (the bundling method + next units). memory
`clj_diff_sweep_methodology` + `verify_actual_pattern_not_proxy`.
