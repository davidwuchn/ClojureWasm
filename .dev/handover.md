# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **continue the clj-parity differential-
  fidelity sweep** (the post-M F-010/F-011 quality loop). Run the next fresh-surface
  `clj_diff_sweep` (exception/ex-data + clojure.math + bit-ops + char are prepped in
  `private/arity_sweep/exc_math_exprs.txt`), then disposition EVERY DIFF — bug→fix
  (clj-oracle-grounded, with a corpus + e2e) OR accepted→AD-NNN (derives_from + pin)
  per `.claude/rules/accepted_divergences.md`. Each fresh surface yields ~1 real bug
  + a few accepted divergences. Surfaces DONE this campaign: arity envelopes,
  exception catchability, exception specific-class, print fidelity, reader hygiene.
  NOT-yet-swept: exception round-trip, math, bit, char, multimethod, transient,
  sort/compare (regex has D-447 known gaps — skip).

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16; plan
  in `private/notes/9.2.S-d133-jit-survey.md § INTEGRATION`). `git push --force*`.
  Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for scripted/probe (ADR-0133 —
  ReleaseSafe). A reader-macro NS-qualification MUST use `rt/` (the only core ns
  resolvable in the core.clj-less diff fixture), NOT `clojure.core/` (AD-038 lesson).

## Last landed (git log = SSOT; all pushed)

**clj-parity differential-fidelity campaign** (post-M F-010/F-011 quality loop, this
session, 11 commits): D-446 arity-envelope sweep (n-ary map/mapv/mapcat/list*,
bit-and-not, resolve 2-arg, typed array ctors 2-arg + AD-036); then a broad
exception/print/reader fidelity arc — deref/conversion/ns arg-type errors made
CATCHABLE (were uncatchable `feature_not_supported`); subvec/peek/pop/replace/
requiring-resolve/io ex-info → clj's specific class (IndexOutOfBounds / IllegalState
/ ClassCast / IllegalArgument); a bare chunked_cons now prints its elements (was
`#<chunked_cons>`); `@x` reader NS-qualified (`rt/deref`) to fix a local-`deref`
capture bug. Accepted divergences recorded: AD-036 (array 2-arg uniform fill),
AD-037 (`(str lazy_seq)` → elements vs clj identity hash), AD-038 (`@` → `rt/deref`
vs clojure.core), AD-039 (`#()` deterministic `%1` vs gensym). Value-parity verified
clean (multiple sweeps, 0 non-AD diffs).

**Open residuals** (`.dev/debt.yaml`): D-446 (multidim aget/aset/aset-* variadic — a
distinct rare feature behind a perf-vs-F-009 barrier); D-459 (exception-CLASS
precision for seq-of-non-seqable / assoc-vec-OOB / into-bad-entry → cljw CCE where
clj gives IAE/IndexOOB; the `seq` path has wide blast radius — not rushed).

## Perf campaign (PAUSED behind the active flag; not the current task)

`.dev/.perf_campaign_active` is SET but the loop is in the quality sweep, not perf.
If the user re-opens perf: the only remaining accessible lever is D-386(a) (inline
`stepOnce` SP-marshalling, a risky UAF-class cycle — fresh focus + the
`CLJW_GC_TORTURE_ALLOC` safety net); JIT D-133 is user-fenced. Full perf state:
ADR-0148 + `private/notes/9.2.S-perf-remeasure-2026-06-17.md`.

## Cold-start reading order (resume)

handover → `.dev/project_facts.md` (F-002 / F-010 / F-011) →
`.claude/rules/clj_diff_sweep.md` + `accepted_divergences.md` (the sweep + AD
discipline) → `.dev/accepted_divergences.yaml` (AD-001…039) → `.dev/debt.yaml`
D-446 / D-459. memory `clj_diff_sweep_methodology` + `direct-explore-fork-mechanical`.
