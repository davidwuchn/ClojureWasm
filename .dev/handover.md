# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **continue the java.time wiring arc (D-462)** —
  next type **java.time.LocalDateTime** (date-based: reuse instant.zig
  `daysFromCivil`/`civilFromDays`; candidate payload `[epoch-day, nano-of-day]`;
  needs a proper Step 0 on the representation + a clj oracle). Pattern is
  established: temporal types are `.typed_instance` (timestamp.zig/instant_value.zig
  model), printed via the `temporal_print` enum (type_descriptor.zig), value-`=` via
  an equal.zig arm, value-wrap file in the compat_tiers `wrap:` slot (G3-exempt).
  After LocalDateTime: ZonedDateTime, then LocalDate (no .zig yet). Each: clj-grounded
  e2e → impl (fork the mechanical part once spec'd) → verify vs clj → smoke → commit.
  When java.time is exhausted, self-select the next clj-parity unit (the single-expr
  differential sweep has SATURATED; remaining structural debt: D-460 sorted-coll map
  key, D-461 require-semantics F-003 owner call, D-446 multidim arrays).

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16; plan
  in `private/notes/9.2.S-d133-jit-survey.md § INTEGRATION`). `git push --force*`.
  Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for scripted/probe (ADR-0133 —
  ReleaseSafe). A reader-macro NS-qualification MUST use `rt/` (the only core ns
  resolvable in the core.clj-less diff fixture), NOT `clojure.core/` (AD-038 lesson).

## Last landed (git log = SSOT; all pushed)

**clj-parity + java.time arc** (this session): D-463 clojure.test report-format
fidelity (`*test-out*` re-enabled, `FAIL in (test-name)` via testing-vars-str,
`(not (= 1 2))` actual, context line, `Testing <ns>`; AD-041 for the unreproducible
source-line/JVM-stacktrace; per-var lifecycle events = residual). Then D-462
java.time wiring — **Instant** + **Duration** as `.typed_instance` values
(timestamp.zig model; statics + instance methods + `(str)` = ISO_INSTANT / ISO-8601
`PT…`; value-`=`; verified vs clj incl. gnarly negatives). Folded the print flag into
a `temporal_print` enum. AD-042 generalized (java.time.* bare-toString vs clj
`#object[…]` pr). compat_tiers honesty-corrected (anti-D-177); the `*_value.zig`
files live in the `wrap:` slot (F-009 value-wrap, G3-exempt). Stale-test fix:
phase14_format `%d` message (D-459 had changed it to "expected an integer (Long)…").

**Open residuals** (`.dev/debt.yaml`): D-462 remaining java.time types
(LocalDateTime / ZonedDateTime / LocalDate) + arithmetic methods (plus*/minus*/
between) NOT implemented; D-463 per-var lifecycle events; D-460 (sorted coll as map
key — rt-free keyEqValue); D-461 (require semantics — F-003 owner); D-446 (multidim
arrays).

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
D-446 / D-460. memory `clj_diff_sweep_methodology` + `direct-explore-fork-mechanical`.

