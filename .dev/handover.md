# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: continue the **ADR-0148 fastest-script campaign**
  (`.dev/.perf_campaign_active` SET) at **D-386 (VM dispatch → superinstructions → JIT)**.
  **4 of 9 targets CLOSED** (cljw fastest-script): string_ops + bigint_factorial + ratio_sum
  + nested_update. Per ADR-0148 §"Measurement update" the GC pair (gc_alloc_rate ~1.33× +
  gc_large_heap ~1.25×) + sieve + destructure ALL converge on dispatch (NOT a generational
  GC — de-prioritised). Extend the superinstruction set (O-029..O-031 added arith +
  local_const/locals) to more hot sequences; D-133 ARM64 JIT re-sequenced LAST (ADR-0145).
  **D-386 substep 2 (op_top hoist) synchronous alloc-torture validation is now UNBLOCKED**
  (D-244 #4 landed — see Last landed). **CONCRETE ENTRY (Step 0 done this session): the
  flattened closure-call per-call overhead.** gc_large_heap = ~200K closure invocations
  (`(into [] (map …))` + `(reduce …)`), baseline 34.1 ms (≤29.7 ms = fastest-script vs
  Babashka, ~22 ns/call to cut). Lever (a) = lazy-rebuild the per-call error-trace push
  (`flattenPush`/ADR-0119 — the real headroom, DEEP: needs error-trace-fidelity e2e); lever
  (b) `bindCallFrame` already O-015-optimised (low headroom). Full orientation + baselines +
  method: `private/notes/9.2.S-d386-flatten-path-orientation.md`. (destructure map-`:keys`
  `(if (seq? mm) …)` sub-lever = LOW ROI, defer.) json_parse ~1.20× near floor. Method:
  measure-first (ReleaseSafe only);
  experiment-and-revert (reverted commits MAY stay in log; never leave `main` red; diff
  oracle + corpus 3181 stay green; ≥10 runs). D-453 (Alt C op_load_class) deferred.
  - regex arc DONE (ADR-0147); **D-448** nested-empty-quant capture deferred; **D-449**
    lazy-DFA reserved. **D-451** = Ratio canonical-invariant guard (ADR-0149).
  - **D-244 #4b** (eval-reentrant lazy-realization/reduce rooting under alloc-torture —
    `(into {} (map f (range N)))` → wrong count) is an OPEN follow-on (the gc_self_guard
    set/clear sites); NOT a production bug (auto-collect OFF). Independent of op_top hoist.

- **CAUTION — alloc-torture is CPU-brutal**: `CLJW_GC_TORTURE_ALLOC=1` forces a full STW
  collect on EVERY `gc.alloc`. Keep probes TINY/EAGER (≤~70 elems, no lazy-seq realization),
  ONE at a time with `timeout`, NEVER batch large ranges (froze the host 2026-06-16).

- **Forbidden**: `git push --force*`; bare `zig build test` WITHOUT `-Dwasm` (false
  fails — memory `zig_build_test_needs_dwasm`); bare `zig build` for scripted/probe
  (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Last landed (git log = SSOT; all pushed)

This session: **D-244 #4 synchronous-builder GC alloc-torture rooting** (ADR-0150,
REVERSED from same-day REJECTED). Bounded fabrication no-collect region —
`GcHeap.enterFabrication`/`exitFabrication` + `fabrication_depth` gates the per-alloc
torture (+ future ADR-0028 auto-collect); each multi-alloc builder brackets its body
(vector/map/set/list + transient finalize). 16 builder probes green under
`CLJW_GC_TORTURE_ALLOC=1`. 2 DA forks (the 2nd steelmanned Alt B + confirmed the
reversal — ADR-0090's text decides the multi-thread safepoint, not builder-internal
raw-node rooting; the "never suppress" line was a root_set.zig code comment). #4b
(reentrant lazy-realization rooting) scoped out as a follow-on.

Prior (git log = SSOT): **D-452 cold-start AOT** (Part A = ADR-0034 am5
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
(O-047), ratio_sum (O-046), nested_update (O-033). Remaining: gc_alloc_rate ~1.33× +
gc_large_heap ~1.25× + sieve ~1.23× + destructure ~1.13× (ALL dispatch/construction-bound
→ D-386, per ADR-0148 §"Measurement update": the GC pair is ~0.5% malloc, NOT generational
— de-prioritised; gc_large_heap residual = ~200k closure calls) · json_parse ~1.20× (vs
CPython C-json, near floor — low priority). See the first-commit bullet for the D-386 path
+ the seq?-guard sub-lever. Lever analysis: `private/notes/9.2.S-ratio-bigint-alloc-levers.md`.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** → **ADR-0142** (§9 gap-area) → **ROADMAP
§9.0** → the regex unit: **ADR-0147** + ADR-0031 + the audit note + the 48-golden
corpus + `ezi-gex`. memory `perf-beat-python-every-bench` + `perf-campaign-roadmap-9-2-s`
+ `direct-explore-fork-mechanical`. clj oracle = `clojure -J-Xmx2g -M -e` (timeout 60).

## Stopped — user requested

User instruction (2026-06-16): "次のclearセッションからcontinueできるか、配線・参照
チェーンを監査し、停止してください。". Audited the resume reference-chain: tree clean +
`main...origin/main` (all pushed); `check_debt_id_refs` ok (all cited D-NNN/ADR resolve);
`.dev/.perf_campaign_active` SET; ADR-0150 = ACCEPTED; both referenced private notes exist
(`9.2.S-d244-4-decision`, `9.2.S-d386-flatten-path-orientation`). **D-244 #4 landed+pushed
this session** (`da075c4a`). Resume per the first-commit bullet: **D-386, the flattened
closure-call per-call overhead** (Step 0 done — orientation note has the lever candidates +
baselines; lever (a) error-trace-push lazy-rebuild = the real headroom). The next `/continue`
deletes this section and resumes the loop.
