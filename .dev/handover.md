# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **D-446 arity-parity residual** — the
  mid/under-arity sweep. The 2026-06-16 PARTIAL pass swept the high-signal 0-arg
  boundary (10 cljw↔clj arity divergences aligned: `= < > <= >= distinct?
  every-pred some-fn` now throw at 0-arg; `into`/`conj!` 0/1-arity relaxed) +
  the 22-fn over-arity sample. RESIDUAL (NOT swept): a per-fn MID/UNDER-arity
  diff vs clj (a fn accepting 2 where clj needs 3, or missing a valid
  mid-arity). Methodology = the established probe-and-align: enumerate core.clj
  defns + Zig builtins, diff each arity envelope vs `clojure -J-Xmx2g -M -e`,
  classify bug→fix (align) OR accept→AD-NNN, corpus-pin the probes
  (`test/e2e/phase14_arity_parity.sh` + a corpus). Big-bang-then-closed
  (clj_diff_sweep Discipline 2). If the mid-arity yield proves low, pivot to the
  **perf campaign** (ROADMAP §9.2.S; resume D-180 bulk `persistent!` /
  `vector.fromSlice` — the into/vec bottleneck — + D-386 dispatch; perf is the
  raised differentiator per memory `perf_beat_python_every_bench`).

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

handover → `.dev/project_facts.md` (F-002/F-011/F-015) → ADR-0142 (§9 gap-area
model) → ROADMAP §9.0 + §9.2.S (perf) → the D-446 row in `.dev/debt.yaml` (the
PARTIAL-pass methodology + residual) + `test/e2e/phase14_arity_parity.sh`. clj
oracle = `clojure -J-Xmx2g -M -e` (timeout 60). memory
`direct-explore-fork-mechanical` + `clj-diff-sweep-methodology`.
