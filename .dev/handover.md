# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **reassess + self-select the next high-value
  direction** — "reassess" means *choose among the real remaining clusters*, NOT
  "work is nearly done". SATURATED, do not re-grind: clj-parity single-expr +
  transducer sweeps (0 real bugs) and the java.time LOCAL family (Instant/Duration/
  LocalDateTime/LocalDate/LocalTime, all clj-verified); high-use libs
  (clojure.string/set/walk/zip, transducers) are corpus-locked. What REMAINS is
  **70 active debt rows** in real clusters (the campaign that closed was narrow) —
  weigh per F-002/F-015:
  - **Security (gap area II — the largest near-untouched actionable block, ~10
    rows)**: D-338/339/341/342/343/346/347/348/349/353 — wasm host-import allowlist,
    FS-jail code-loading scope, slowloris, eval-free deploy build, capability gating,
    `wasm/run` stdout buffering.
  - **Perf (D-450 fastest-script target, ADR-0148 — UNMET; `.perf_campaign_active`
    is SET)**: only risky/fenced levers left — D-386(a) inline stepOnce (UAF-class),
    JIT D-133 user-fenced.
  - **clj-parity PARTIAL residuals (mostly niche)**: D-458 cl-format V/#, D-431
    Throwable, D-446 multidim array, D-462 ZonedDateTime (tz-DB-blocked), D-463
    clojure.test per-var events, D-410 java.text.
  - **Concurrency (gap area I)**: D-258 agent-race flake (recurring),
    D-239/245/255/442 PARTIAL.
  This is a genuine campaign-boundary reassessment, not a queue-pop — but the
  remaining work is substantial, not thin.

- **Forbidden this session**: JIT integration (D-133 — user-fenced 2026-06-16; plan
  in `private/notes/9.2.S-d133-jit-survey.md § INTEGRATION`). `git push --force*`.
  Bare `zig build test` WITHOUT `-Dwasm` (false fails — memory
  `zig_build_test_needs_dwasm`). Bare `zig build` for scripted/probe (ADR-0133 —
  ReleaseSafe). A reader-macro NS-qualification MUST use `rt/` (the only core ns
  resolvable in the core.clj-less diff fixture), NOT `clojure.core/` (AD-038 lesson).

## Last landed (git log = SSOT; all pushed)

**clj-parity + java.time campaign** (this session): D-463 clojure.test report-format
fidelity (`*test-out*`, `FAIL in (...)`, actual form, `Testing <ns>`; AD-041). Then
the **D-462 java.time campaign** — all five LOCAL types (Instant/Duration/
LocalDateTime/LocalDate/LocalTime) wired as `.typed_instance` values (NO new NaN-box
tag): statics + readers + ISO `(str)` + value-`=`, `(compare)`/`(sort)`, comparison
predicates, full date/time arithmetic (civil clamp + midnight carry), DayOfWeek/Month
enums, cross-type `Duration/between` + `.plus/.minus(Duration)`. All clj-verified
(negatives / pre-1970 / 1900-non-leap / ns-precision edges). Transducer differential
corpus added (0 bugs). ZonedDateTime DEFERRED (tz-DB). AD-042/043.

**This campaign's OWN residuals** (niche/blocked; the global remaining-work picture
is the cluster list in the Resume contract above, NOT this paragraph): D-462
remaining are all NICHE on-demand —
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

