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
  lazy-realization; 4 real bugs FIXED + AD-050/AD-007). The **stack-overflow robustness
  arc is COMPLETE** (ADR-0157, reshaped by a Devil's-advocate fork): 2b (catchable own-Kind
  StackOverflowError) + 2a (self-calibrating native-stack guard at `vm.eval` entry: threadlocal
  stack-base anchor + 6 MiB byte-budget) + D-486 (route the flattened-recursion overflow
  through the shared `else |err|` arm). Every overflow path — re-entry AND direct recursion —
  now raises a graceful, CATCHABLE StackOverflowError (clj parity). D-485/D-486 discharged;
  gate green 390/0 (through 2a). **First commit on resume = D-487** (a measured quick win:
  `zig build test` runs Debug and its RUN dominates the smoke at ~114s warm — the F-012 diff
  oracle on a Debug interpreter; try `-Doptimize=ReleaseSafe`, which keeps safety checks but
  may cut the smoke ~6min→~1-2min — ADR-level, validate all tests pass first). Then self-select
  deferred deep items (D-482 seq-laziness, D-479 Class/forName, D-480 Serializable) or resume
  the contrib bug-audit. Open follow-up: ADR-0157 Alt 3 (trampoline) = forward debt; 2a budget
  could read the real RLIMIT_STACK instead of a fixed 6 MiB (per-task note). Policy unchanged:
  **official stdlib → eager bundle; contrib → verify**.

- **Forbidden this session**: speculative JIT integration before zwasm's API stabilises
  (read `.dev/zwasm_capabilities.md` — JIT row BUILDING, not adoptable). `git push
  --force*`. Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for a probe (ADR-0133 — ReleaseSafe).
  A reader-macro / syntax-quote NS-qualification MUST stay `rt/`, not `clojure.core/`
  (AD-038/AD-049).

## Stopped — user requested

User instruction (2026-06-21): "きりが良くなったタイミングで、次のクリアセッションから
continue できるように、配線・参照チェーンを監査し、停止してください。また、問題なければ、
ローカルの `.zig-cache` と zwasm_from_scratch 側の `.zig-cache` を削除してください" (+ a
follow-up audit of whether the smoke slowness was a Debug-build fallback → confirmed: the
shipped/e2e binary is ReleaseSafe; the cost is the Debug `zig build test` RUN, now D-487).
Wiring audit done (clean: all e2e registered, debt IDs resolve, ADR↔debt cross-refs intact).
Both `.zig-cache`s deleted at the clean stop. Resume per the Resume contract above (D-487).

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
