# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: continue the **ADR-0148 fastest-script campaign**
  (`.dev/.perf_campaign_active` SET). **4 of 9 targets CLOSED** (cljw fastest-script):
  string_ops + bigint_factorial + ratio_sum + nested_update. **NEXT = the GC-arch
  generational/nursery ADR** (gc_alloc_rate ~1.33× + gc_large_heap ~1.25× — the biggest
  remaining gap, 2 targets; F-006, own DA fork). Start with a CLEAN profiling foundation
  (instrument GC counters — ReleaseSafe is symbol-stripped so `sample` only shows
  malloc-churn). Tractable secondary lever (measured): intrinsify `seq?` (the map-`:keys`
  destructure guard, ~5.5 ms/100k — see § Next). THEN the original front: VM-perf **D-386**
  dispatch → superinstructions → **D-133** ARM64 JIT (sieve/destructure are dispatch-bound).
  Method: measure-first (ReleaseSafe only; 5 campaign hypotheses already refuted by
  measurement — ADR-0148); experiment-and-revert (reverted commits MAY stay in log; never
  leave `main` red; diff oracle + corpus 3181 stay green; ≥10 runs). D-453 (Alt C
  op_load_class) deferred.
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

This session (git log = SSOT): **D-452 cold-start AOT** (Part A = ADR-0034 am5
`type_descriptor` wire tag 0x10, serialized-by-name + import-blind `resolveDescriptorByKey`,
DA-fork Alt B; Part B = `buildBootstrapEnvelope` AOT-caches the whole bootstrap, cold start
8.0→6.1 ms, **string_ops CLOSED**) + **O-047** (no-clone BigInt arith result via
`wrapArithCell` move/collapse — **bigint_factorial CLOSED**, cljw 20.2 ms fastest-script).
Earlier cycle 1 = O-037…O-046 (ratio_sum + nested_update CLOSED). All diff-oracle + corpus
3181 + smoke green. **6 hypotheses refuted by measurement** (ADR-0148): GC-arch
bump-allocator, closure-call cost, call-site-cache, fusion-always-wins, bignum-compute-bound
(was the result CLONE — O-047), cold-start-Debug-ghost (was 6 ms not 0.48 s). D-453 (Alt C
op_load_class) deferred. SAFETY: `clj` → `clojure -J-Xmx2g`; measure ReleaseSafe only.

**Next (self-select):** post-D-452 + O-047 re-measure DONE (ReleaseSafe, this session).
**4 of 9 CLOSED** (cljw fastest-script): string_ops (cold-start AOT), bigint_factorial
(O-047 no-clone bignum result), ratio_sum (O-046), nested_update (O-033). Remaining gaps
(quiet machine): **gc_alloc_rate ~1.33× + gc_large_heap ~1.25× = the GC pair (BIGGEST,
2 targets)** · sieve ~1.23× + destructure ~1.13× (dispatch-bound → D-386) · json_parse
~1.20× (vs CPython C-json, near floor).

**NEXT BIG LEVER = GC ALLOC-OVERHEAD (gc_alloc_rate + gc_large_heap).** ⚠️ PREMISE
CORRECTED 2026-06-16: **auto-collect is OFF** (gc_heap.zig:280, agent.zig) — cljw NEVER
collects mid-run, so gc_alloc_rate's 200k 4-elem vectors are pure ALLOCATION throughput
(every alloc → `infra.rawAlloc`/malloc since `free_pools` stays empty without a sweep) +
per-alloc bookkeeping (`allocations.append` grows to ~400k, `gc_mutex` lock/unlock,
safepoint+ceiling checks). **A *generational* GC does NOT help this** (nothing is collected
— generational only pays off when you sweep). The real lever is per-alloc COST: a slab/
arena/bump heap (but "GC-arch bump-allocator" is on the REFUTED list — re-investigate WHY
with per-alloc instrumentation: is malloc actually dominant, or is it `allocations.append`/
the mutex/the vector construction?) and/or dropping the uncontended single-thread `gc_mutex`
+ the always-append tracking. Needs the instrumentation FIRST (ReleaseSafe is stripped →
`sample` only shows `main+offset`+malloc; add alloc/collect counters). **Tractable secondary lever** (measured this
session): map `:keys` destructure emits `(if (seq? mm) (apply hash-map mm) mm)` per iter —
the seq? guard costs ~5.5 ms over 100k (d_noguard 33.4 vs d_guard 38.9). Intrinsify `seq?`
(O-043 op_get/op_nth pattern, F-011-safe: same semantics, faster dispatch) → partial
destructure win. Then the original front **D-386 dispatch → D-133 JIT** (sieve/destructure
are dispatch-bound). Lever analysis: `private/notes/9.2.S-ratio-bigint-alloc-levers.md`.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** → **ADR-0142** (§9 gap-area) → **ROADMAP
§9.0** → the regex unit: **ADR-0147** + ADR-0031 + the audit note + the 48-golden
corpus + `ezi-gex`. memory `perf-beat-python-every-bench` + `perf-campaign-roadmap-9-2-s`
+ `direct-explore-fork-mechanical`. clj oracle = `clojure -J-Xmx2g -M -e` (timeout 60).
