# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: continue the **ADR-0148 fastest-script campaign**
  (`.dev/.perf_campaign_active` SET). Cycle 1 DONE (9 targets ≤1.25×, 2 CLOSED <1.0×).
  **D-452 cold-start AOT DONE** 2026-06-16 (Part A serializer = ADR-0034 am5
  `type_descriptor` tag; Part B = full-bootstrap AOT `buildBootstrapEnvelope`): cold
  start **8.0→6.1 ms** back-to-back ReleaseSafe. **NEXT = RE-MEASURE the 9 targets**
  (`bench/compare_langs.sh`, ReleaseSafe, ≥10 runs) — the ~1.9 ms cold-start drop most
  helps the cold-start-floor benches (sieve 1.13× / string_ops 1.04×); some may now CLOSE.
  THEN drain residual per-target highest-ROI first: bigint_factorial 1.25× (deep bignum) ·
  destructure 1.23× (dispatch). THEN the original front: VM-perf **D-386** dispatch →
  superinstructions → **D-133** ARM64 JIT. Method: cljw deep-dive + measure-first (5
  campaign hypotheses already refuted by measurement — ADR-0148); experiment-and-revert
  (reverted commits MAY stay in log; never leave `main` red; diff oracle + corpus 3181
  stay green; ≥10 runs, ReleaseSafe only). D-453 (Alt C op_load_class) deferred.
  - regex arc DONE (ADR-0147); **D-448** nested-empty-quant capture deferred; **D-449**
    lazy-DFA reserved. **D-451** = Ratio canonical-invariant guard (ADR-0149).
  - **JIT (D-133)** re-sequenced LAST (ADR-0145). **D-244 #4** capstone below.

- **Validation infra / D-244 #4 gap**: `CLJW_GC_TORTURE_ALLOC=N` validates MID-ALLOC
  rooting; the O-032/O-033 producers are SAFEPOINT-torture-validated (the primary
  hazard) but ALLOC-torture is BLOCKED on a pre-existing fabrication-rooting bug
  (op_vector_literal/set/map folds + the `vector` builtin build a partial collection
  in an unrooted Zig local → mid-alloc collect sweeps it). `fromSlice` does NOT
  sidestep it (tried+reverted). FIX = wire `gc_self_guard` (GcHeap.pin/unpin exist;
  per-site set/clear unwired) — an own-session GC-infra capstone;
  `private/notes/9.2.S-d244-4-alloc-torture-finding.md`. LESSON: diff oracle is
  necessary but NOT sufficient; clj corpus + torture + direct probe are the backstops.

- **Forbidden**: `git push --force*`; bare `zig build test` WITHOUT `-Dwasm` (false
  fails — memory `zig_build_test_needs_dwasm`); bare `zig build` for scripted/probe
  (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Last landed (git log = SSOT; all pushed)

ADR-0148 fastest-script campaign, **cycle 1 COMPLETE = 10 wins (O-037…O-046)**. ALL 9
targets crushed from their multi-× gaps to ≤1.25× (2 CLOSED outright). Standing vs
fastest-script: ratio_sum **0.91× CLOSED** (was 3.15×) · nested_update **0.89× CLOSED** ·
string_ops 1.04× · json_parse 1.13× · sieve 1.13× · gc_alloc_rate 1.15× · gc_large_heap
1.16× · destructure 1.23× · bigint_factorial 1.25×. Levers: O-037/38 ratio zero-copy+arena
· O-039 alias BigInt · O-040 op_vector_literal fromSlice · O-041 json bulk-build · O-042
str int fast-path · O-043 op_get/op_nth intrinsics · O-044 op_nth2 · O-045 fusion gate ·
**O-046 small-ratio inline-i64 (ADR-0149: canonical two-tier Ratio; ratio_sum 81→32 ms)**.
All diff-oracle + corpus 3181 + smoke green. **5 hypotheses refuted by measurement**
(ADR-0148): GC-arch bump-allocator, closure-call cost (~3ns), call-site-cache,
fusion-always-wins, [bignum-compute-bound — was alloc]. D-451 guards the Ratio canonical
invariant. SAFETY: `clj` → `clojure -J-Xmx2g` (harness `clj` is rlwrap-broken on this host);
measure ReleaseSafe only.

**Next (self-select):** D-452 cold-start AOT is DONE (cold start 8.0→6.1 ms; the highest
cross-target lever). Residuals are 1.04–1.25×. **RE-MEASURE first** — the cold-start drop
should lift the cold-start-floor benches (sieve / string_ops); re-run `bench/compare_langs.sh`
and record which targets CLOSED before picking the next lever. Then per-target:
bigint_factorial 1.25× (deep bignum) · destructure 1.23× (dispatch). Then the original
front: **D-386 dispatch → D-133 JIT**. Lever analysis:
`private/notes/9.2.S-ratio-bigint-alloc-levers.md`.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** → **ADR-0142** (§9 gap-area) → **ROADMAP
§9.0** → the regex unit: **ADR-0147** + ADR-0031 + the audit note + the 48-golden
corpus + `ezi-gex`. memory `perf-beat-python-every-bench` + `perf-campaign-roadmap-9-2-s`
+ `direct-explore-fork-mechanical`. clj oracle = `clojure -J-Xmx2g -M -e` (timeout 60).
