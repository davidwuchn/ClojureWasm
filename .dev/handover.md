# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **reassess + self-select the next high-value
  direction** — the clj-parity + java.time campaign is COMPREHENSIVELY COMPLETE
  (D-462): all 5 local temporal types (Instant/Duration/LocalDateTime/LocalDate/
  LocalTime) have construct/display/parse/convert/compare/sort/full-arithmetic +
  DayOfWeek/Month enums + cross-type `Duration/between` + `.plus/.minus(Duration)`,
  all clj-verified. The single-expr AND transducer sweeps are SATURATED (0 real
  bugs); the high-use libs (clojure.string/set/walk/zip, transducers) are already
  corpus-locked. So do NOT reflexively grind the niche java.time residuals
  (`DayOfWeek/MONDAY` static fields, ZonedDateTime tz-DB-blocked, `compareTo`-as-
  method AD-043 — all low-value on-demand per D-462). Instead WEIGH: (a) a fresh
  clj-parity surface not yet probed (if any high-use one remains); (b) a gap area
  (§9.0) entry — I concurrency-hardening (incl. the dormant D-258/D-244#4 GC-torture
  agent race, hard/flaky), II Wasm-edge-native (D-006 Pod FFI, future), III VM-perf
  (no clean lever — D-180 done, D-386a UAF-risky, JIT D-133 user-fenced). Self-select
  per F-002/F-015; the readily-actionable high-value work is genuinely thin, so this
  is a real reassessment, not a queue-pop.

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16; plan
  in `private/notes/9.2.S-d133-jit-survey.md § INTEGRATION`). `git push --force*`.
  Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for scripted/probe (ADR-0133 —
  ReleaseSafe). A reader-macro NS-qualification MUST use `rt/` (the only core ns
  resolvable in the core.clj-less diff fixture), NOT `clojure.core/` (AD-038 lesson).

## Last landed (git log = SSOT; all pushed)

**clj-parity + java.time campaign** (this session): D-463 clojure.test report-format
fidelity (`*test-out*`, `FAIL in (test-name)`, `(not (= 1 2))` actual, context line,
`Testing <ns>`; AD-041 source-line/stacktrace). Then a comprehensive **D-462 java.time
campaign** — all five local types wired as `.typed_instance` values (timestamp.zig
model; NO new NaN-box tag): **Instant, Duration, LocalDateTime, LocalDate, LocalTime**
— statics (of/now/parse/ofEpoch*) + readers + `(str)` ISO-grounded + value-`=`, all
verified vs clj (negatives / pre-1970 / 1900-non-leap / ns-precision edges). Plus:
print via a `temporal_print` enum; shared civil + ISO format/parse helpers in
instant.zig; `(compare …)`/`(sort …)` work (compare.zig temporal arm, AD-043 sign-vs-
magnitude); comparison predicates (isBefore/isAfter/isEqual + Duration isZero/
isNegative/negated/abs); LocalDate full date-math (plus/minus days/weeks/months/years
with civil clamp + isLeapYear/lengthOfMonth); LocalDateTime time-unit arithmetic
(plus/minus days/weeks/hours/minutes/seconds/nanos with midnight carry). AD-042
(bare-toString vs `#object[…]`). `*_value.zig` in the `wrap:` slot (G3). Gate-hygiene
fix (impl_extras→wrap; stale phase14_format `%d`). ZonedDateTime DEFERRED (tz-DB).
THEN landed: cross-type `Duration/between` + Instant/LDT `.plus/.minus(Duration)`;
`(compare …)`/`(sort …)` for temporals (AD-043 sign-vs-magnitude); DayOfWeek/Month
enums + getDayOfWeek/getMonth/getDayOfYear; LDT calendar arithmetic (plusMonths/Years,
civil helpers consolidated into instant.zig); transducer differential corpus (0 bugs).

**Open residuals** (`.dev/debt.yaml`): D-462 remaining are all NICHE on-demand —
`DayOfWeek/MONDAY` static-field access, ZonedDateTime (tz-DB-blocked), `compareTo`-as-
method (AD-043 magnitude); D-463 per-var lifecycle events (custom-reporter-only);
D-258/D-244#4 dormant GC-torture agent race (load-flaky, gap area I); D-460 (sorted
coll as map key); D-461 (require semantics — F-003 owner); D-446 (multidim arrays).

## Perf campaign (PAUSED behind the active flag; not the current task)

`.dev/.perf_campaign_active` is SET but the loop is in the quality sweep, not perf.
If the user re-opens perf: the only remaining accessible lever is D-386(a) (inline
`stepOnce` SP-marshalling, a risky UAF-class cycle — fresh focus + the
`CLJW_GC_TORTURE_ALLOC` safety net); JIT D-133 is user-fenced. Full perf state:
ADR-0148 + `private/notes/9.2.S-perf-remeasure-2026-06-17.md`.

## Cold-start reading order (resume)

handover → `.dev/project_facts.md` (F-002 / F-010 / F-011) → ROADMAP §9.0 (gap
areas I/II/III) → `.dev/accepted_divergences.yaml` (AD-001…043) → `.dev/debt.yaml`
(D-462 java.time residuals niche; D-460/D-461/D-446 blocked/deferred). memory
`direct-explore-fork-mechanical` + `clj_diff_sweep_methodology`.

## Stopped — user requested

User instruction (2026-06-19): 「いまのきりが良くなったら、クリアセッションから
continue できる配線と参照チェーン監査して停止して。」 (At a clean point, ensure the
clean-session `/continue` wiring + run the reference-chain audit, then stop.) Done:
LocalDateTime calendar arithmetic landed at the clean point (`d1b6f7b6`); reference-
chain audit CLEAN (check_debt_id_refs ok, AD gate 42 in-sync, feature_keyword exit 0,
zone_check clean, handover framing clean, all 12 phase15_java_time_* e2e registered);
full gate green (resume-readiness). Resume: self-select the next direction per the
Resume contract above (the clj-parity/java.time campaign is comprehensively complete;
this is a genuine reassessment, not a queue-pop).

