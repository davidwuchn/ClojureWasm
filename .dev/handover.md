# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **perf campaign (D-450 / ADR-0148),
  conversion-group front**. The campaign is active (landed O-037/O-038 ratio_sum
  3.15×→2.45×, O-039 bigint 1.49×→1.29×, O-040 gc_alloc_rate 2.81×→1.36×).
  ADR-0148's own next-front: "mine the conversion group (**destructure** 1.72× /
  **json_parse** 1.59× / **string_ops** 1.35×) for localized O-040-style alloc-
  cutting levers, then D-386 dispatch." **MEASURE FIRST** (`bash bench/...` /
  scripts/perf.sh, ReleaseFast, ≥10 runs — the 2026-06-16 ratios have shifted)
  to pick the true highest-ROI target NOW, read its ADR-0148 row direction, fork
  a DA per the standing per-optimization rule, implement one localized lever,
  re-measure, keep diff-oracle + corpus green. The D-446 arity mid/under residual
  is DEFERRED — a low-signal sweep that would displace the differentiator (the
  Micro-coverage-grind smell, clj_diff_sweep Discipline 2); leave it a tracked
  floor row. (Also trivially takeable anytime: D-456 defprotocol-return = `P` not
  `#'user/m`, a 1-line `expandDefprotocol` final-form fix.)

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
