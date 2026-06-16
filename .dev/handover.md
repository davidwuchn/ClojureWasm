# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **perf campaign (D-450 / ADR-0148),
  GC-allocation-throughput front**. RE-MEASURED 2026-06-17 (fresh, ReleaseSafe,
  10-run, canonical `compare_langs.sh` — see
  `private/notes/9.2.S-perf-remeasure-2026-06-17.md`): the 2026-06-16 baseline is
  STALE (pre-O-037..O-042). Current truth: **ratio_sum (was 3.15×) + nested_update
  are now WON (0.95× / 0.84×)**; the other 7 sit at 1.10–1.29× — biggest
  gc_alloc_rate 1.29× · json_parse 1.28× · string_ops 1.25× · bigint 1.20× ·
  gc_large_heap 1.18×. The localized construction levers (O-040/041/042) are MINED
  (the json `.alloc_if_needed` experiment measured INSIDE noise → reverted, NOT
  committed). Diagnosis: the big gaps share ONE root cause — **cljw allocation
  throughput** (malloc-per-object; the gc_heap free-pool only refills on a COLLECT,
  auto-collect OFF → short-lived-object benches malloc every object, no reuse). So
  the next lever is a **nursery / pre-warmed free-list over the non-moving heap**
  (F-006), lifting gc_alloc_rate + gc_large_heap + json_parse + string_ops at once —
  a major unit: survey JVM/GraalVM nursery + bump-alloc techniques, ADR + DA fork,
  implement, re-measure gc_alloc_rate. Regenerate `cross-lang-latest.yaml` (stale).
  DEFERRED: D-446 arity residual (Micro-coverage-grind smell); D-456 defprotocol
  return (1-line, trivial). Compute-bound residuals (sieve/destructure/bigint
  dispatch) → D-386.

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16;
  the ARM64 codegen substrate is DONE + execution-verified, but the coupled
  recognizer+codegen+trigger+marshalling+oracle build is GATED behind an
  explicit user greenlight; plan in `private/notes/9.2.S-d133-jit-survey.md
  § INTEGRATION`). `git push --force*`. Bare `zig build test` WITHOUT `-Dwasm`
  (false fails — memory `zig_build_test_needs_dwasm`). Bare `zig build` for
  scripted/probe (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Last landed (git log = SSOT; all pushed)

**Records arc complete** (D-086 / ADR-0154 + follow-ons): `TypedInstance` gained a
trailing `extmap: Value` slot (the `meta`-field twin, ADR-0112) holding
non-declared keys on a defrecord. assoc/dissoc/get/contains?/keys/vals/count/seq/
print/`=`/hash + `map->R` (via a native `rt/__map->record` primitive — bootstrap-
safe, NOT core.clj `reduce-kv`) all route declared-then-extmap; the partition
lives once in `TypeDescriptor.fieldSlotByName` (DA-fork Alt 2). `conj`/`into` onto
a record assocs into extmap (+ fixed a latent `-editable?` bug: records are `map?`
but not IEditableCollection, so `into` wrongly took the transient path). **AD-035**
records the lone clj divergence (record prints simple `#R{…}`, not `#user.R{…}` —
the AD-003 simple-name policy). clj-diff verified faithful across
assoc/dissoc/get/keys/vals/count/seq/merge/select-keys/find/update/reduce-kv.

## Cold-start reading order (resume)

handover → `.dev/project_facts.md` (F-002/F-006/F-015) → ADR-0148 (perf campaign
goal + landed O-037..O-040 + the 9-target table + conversion-group next-front) →
`.dev/perf_campaign_essence.md` (exploration modes + experiment-revert) → D-450
row in `.dev/debt.yaml` → `bench/README.md` (measured scoreboard). Perf measured
ReleaseFast/ReleaseSafe only (memory `perf-measure-release` /
`verify-against-releasesafe-binary`); each optimization gets its own ADR + DA
fork. memory `direct-explore-fork-mechanical` + `perf-beat-python-every-bench`.
