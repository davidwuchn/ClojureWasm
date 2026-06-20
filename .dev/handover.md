# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: resume the **F-011 clj-diff probe sweep** on
  the next un-probed common surface (the session's value engine — IO/file ops
  (slurp/spit/with-open/line-seq) is the next untested area; then exception
  data-shapes, var/binding deep). Probe top-level for def-forms (the harness
  `(prn …)`-wraps → false cascades on defrecord/defprotocol; verify each DIFF
  INDIVIDUALLY — memory `clj_diff_sweep_methodology`). Fix any real gap at the
  finished form; classify every DIFF (bug→fix / accepted→AD / defer→debt). **clj-parity
  is now comprehensively saturated**: 8 probe areas this session, the last 5 found
  ZERO new fixable bugs (only documented AD-001/002/007/009/019/021 + ADR-0122/0033
  divergences). So expect mostly accepted/low-value finds; if a surface is clean, the
  remaining substantive work is the deep residuals (below) — all deep/low-value/
  barriered. Don't surrender-frame the thinning; keep probing + draining residuals.

- **Remaining clusters (all BARRIERED or niche — the high-value unblocked work is
  drained)**:
  - **Security (gap II, ~10 rows)**: ALL barriered — D-339 slowloris (Phase-15
    cancellable Io, F-003); D-347/349 wasm/run fuel+capture (zwasm-side, F-001);
    D-338 host-import allowlist (reservation); D-346/353 (no live threat / use case).
    Don't force (F-001/F-003).
  - **Perf (gap III, D-450, ADR-0148, PAUSED)**: only fenced levers — D-386(a)
    inline stepOnce (UAF-class), JIT D-133 user-fenced.
  - **clj-parity residuals (niche/deep)**: D-446 multidim aget (deep CHAIN —
    needs Long/TYPE + to-array-2d + multidim make-array + variadic aget; no-JVM
    design Qs), D-410 java.text grapheme (needs UCD GraphemeBreakProperty data-gen),
    D-470 format `%t` date directives (~40 sub-conversions, low-value), D-462
    ZonedDateTime (tz-DB, **user/ADR-owned — NOT autonomous**), D-463 per-var events,
    D-431 Throwable str/pr, D-468/D-433 (closed/low). java.time arithmetic COMPLETE.
  - **Concurrency (gap I)**: D-258 agent-race flake (deep multi-thread STW race,
    D-244 #4), D-239/245/255 PARTIAL.

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16; plan
  in `private/notes/9.2.S-d133-jit-survey.md § INTEGRATION`). `git push --force*`.
  Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for scripted/probe (ADR-0133 —
  ReleaseSafe). A reader-macro NS-qualification MUST use `rt/` (the only core ns
  resolvable in the core.clj-less diff fixture), NOT `clojure.core/` (AD-038 lesson).

## Last landed (git log = SSOT; all pushed)

**This session (~10 units, all clj-oracle-verified, full gate 377/0 green throughout):**
- **D-466 + sub**: `(instance? java.util.Map/List/Set/Collection/SortedMap/Sorted/
  Navigable/Iterable host)` — NEW comptime-const `host_supertypes` TypeDescriptor
  field (mirrors `static_fields`, NOT freed by deinit — the protocol_impls overload
  crashed cache_gen) consulted by class_name.matchUserType; 4 Sorted/Navigable
  interfaces registered (FQCN_MAP + interface_membership empty-tag entries).
- **D-413**: diff_test `Fixture.init` returned BY VALUE after `Env.init(&f.rt)` →
  dangling `env.rt` (non-deterministic abort on unresolved-symbol host-class lookup).
  Fixed init-in-place (out-pointer); swept 3 sibling fixtures (vm/evaluator/regex).
- **D-468 + AD-047**: host java.util collections print BY CONTENT (`[1 2]`/`#{1 2}`/
  `{:a 1}`) via a `print_content` descriptor hook + print.zig deepRealize; str stays
  Clojure-form (AD-047, not JVM Object.toString). Closes the java.util family.
- **D-469**: extend-type/-protocol GROUPED multi-arity `(g ([x] b1) ([x y] b2))` via
  an expandGroupedArities normalize pre-pass reusing the D-279 multi-arity-fn* path.
- **D-462**: LocalDate.atStartOfDay/atTime (→ LocalDateTime) — a verify-sweep proved
  the rest of java.time arithmetic was already done (stale claim). **AD-048**: record
  str = content form. **D-470 filed**: format `%t` family (low-value, deferred).
- **6 clj-diff probe areas** (numeric/seq/string, reader/namespace, transducers,
  math/bit/array, edn/walk/sorted, format) — all clj-faithful modulo documented ADs.

## Perf campaign (PAUSED behind the active flag; not the current task)

`.dev/.perf_campaign_active` is SET but the loop is in the quality sweep, not perf.
If the user re-opens perf: the only remaining accessible lever is D-386(a) (inline
`stepOnce` SP-marshalling, a risky UAF-class cycle — fresh focus + the
`CLJW_GC_TORTURE_ALLOC` safety net); JIT D-133 is user-fenced. Full perf state:
ADR-0148 + `private/notes/9.2.S-perf-remeasure-2026-06-17.md`.

## Cold-start reading order (resume)

handover → `.dev/project_facts.md` (F-002 / F-010 / F-011) → ROADMAP §9.0 (gap
areas I/II/III) → `.dev/accepted_divergences.yaml` (AD-001…048) → `.dev/debt.yaml`
(clj-parity comprehensively saturated; remaining residuals deep/barriered per the
cluster list above). memory `clj_diff_sweep_methodology` (harness def-form trap +
verify-each-DIFF) + `verify_actual_pattern_not_proxy` (stale debt claims: D-462/D-216
were re-verified against the clj oracle, not trusted) + `direct-explore-fork-mechanical`.

