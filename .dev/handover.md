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
  rrb-vector/algo.*→ForkJoin/Future). So self-select from, in value order: (a) a
  **core clj-diff bug sweep** (`scripts/clj_diff_sweep.sh` — the ongoing "未発見の実バグ
  監査"; AVOID multi-line printers [exceptions w/ traces] + clj-uncompilable exprs
  [`Math/gcd`] which break the line-diff harness; the core is mature so yield is low but
  real), or (b) a **deferred deep item** if a clean approach emerges (D-482 seq-laziness
  counted?, D-479 Class/forName, D-480 Serializable marker). Policy unchanged: **official
  stdlib → eager bundle; contrib → verify (require-on-demand)**.

- **Forbidden this session**: speculative JIT integration before zwasm's API stabilises
  (read `.dev/zwasm_capabilities.md` — JIT row BUILDING, not adoptable). `git push
  --force*`. Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for a probe (ADR-0133 — ReleaseSafe).
  A reader-macro / syntax-quote NS-qualification MUST stay `rt/`, not `clojure.core/`
  (AD-038/AD-049).

## Last landed (git log = SSOT; all pushed)

**The stdlib/contrib sweep campaign (2026-06-21): bundled spec.alpha/gen/core.specs.alpha
+ datafy + test.junit; ~16 GENERIC clj-parity fixes surfaced + a GC-lifetime fix.**
- **Bundled** (eager, ADR-0156): spec.alpha/gen.alpha (FILES[24/25]) + core.specs.alpha[26]
  + datafy[27] + test.junit[28]. `math.combinatorics` verified.
- **Generic fixes**: `&`-destructure seq-walk · MapEntry-as-IFn · MultiFn read-surface ·
  `->` non-list step · **definterface** (retired the last analyzer wedge → defprotocol) ·
  13 **instance? markers** (Counted/MapEquivalence/Comparable/IHashEq/IReduceInit/
  ITransient* …) · **extend-protocol to host types** (Namespace/IRef/Throwable/Class,
  D-478) · `ns-imports` · core.protocols Datafiable/Navigable defaults · clojure.test
  `:begin/:end-test-var`+`:end-test-ns` events + `file-position` · `seq-to-map-for-
  destructuring` (1.11) · `fn-sym` name recovery.
- **D-481 GC fix**: `Runtime.deinit` now finalizes the GC heap BEFORE freeing descriptors
  (host_instance finaliser reads `inst.descriptor`); unblocked datafy.
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
