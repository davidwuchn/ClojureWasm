# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: `701b19a` (see `git log` for stale-drift; HEAD line
  refreshes only on Active-task-identifier change per the
  ≤ 2 / session cap).
- **First commit on resume MUST be**: pick ONE of:
  - (a) ADR-0031 cycle 2 = lazy DFA skeleton in
    `runtime/regex/dfa.zig` + `exec.zig` dispatcher (per D-051).
    First cell = 32-state cached subset-construction table +
    NFA-fallback on overflow. Owner MUST also read D-056 — if
    honey/sql compat tier stays, the dispatcher signature must
    accommodate lookahead in cycle 4.
  - (b) D-054 (amended) cycle-3 first port = create
    `test/e2e/regex/phase6_captures.sh` (failing) sourced from
    cw v0's `/Users/shota.508/Documents/MyProducts/ClojureWasm/test/upstream/clojure/test_clojure/regex.clj`
    (the cw lineage SSOT — re-derive in Zig idiom per
    `no_copy_from_v1.md`, do NOT verbatim copy). **NOT** the
    JVM upstream — `find ~/Documents/OSS/clojure -name 'regex*'`
    returns zero hits; the 228-line upstream file does not
    exist. See D-054 amended row + the deep dive at
    `private/notes/cw_v0_regex_indirect_coverage.md` §6.
  - (c) Phase 6 next row = 6.9 `clojure.string` (uses cycle-1
    regex foundation — `re-find` / `re-matches` now green; needs
    bootstrap multi-clj load decision first). Owner: cycle-1
    regex covers basic str/replace + split; if tests touch
    lookahead `(?=...)` the work pulls forward into ADR-0031
    cycle 4 — surface as a debt before sinking time in.
  User picks the branch on resume; default (per finished-form
  bias) is (c) since cycle 1 unblocks Phase 6 forward motion.
- **Forbidden this session**: (a) re-opening `core.zig` / `math.zig`
  primitive cluster (6.16 still closed). (b) handover HEAD-pointer
  churn — refresh only when Active-task-identifier changes.
  (c) acting on the **original** (pre-2026-05-25-amendment)
  D-054 plan that referenced a non-existent JVM upstream
  `regex.clj` — read the amended D-054 + deep-dive note first.

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell + Devil's-advocate mandate)
→ `.dev/structure_plan.md` → `.dev/ROADMAP.md` §9.8.

## Current state

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 now 9/16 `[x]`
  (6.1-6.4, 6.5.a, 6.6 **[NEW — cycle 1 end-to-end]**, 6.7,
  6.8, 6.16). Remaining: 6.0 (boundary review), 6.5.b (TZ data
  — defer), 6.9-6.12 (clojure.string/set/walk/zip — needs
  bootstrap multi-clj load), 6.13 (yaml sweep ~34 entries),
  6.14 (exit smoke), 6.15 (phase flip).
- **Branch**: `cw-from-scratch`. HEAD `701b19a` — ADR-0031
  Alt 2 cycle 1 complete (parser + Pike VM + char classes +
  escapes + anchors + Regex Value + primitives + reader
  literal `#"..."`). 6 cycle-1 commits + 1 silent-skip
  surgery + D-053 clock port pushed this session.
- **Gate**: Mac 18/18 + OrbStack Ubuntu x86_64 17/17 green.
  `zig build test` 573/573. `scripts/check_test_reach.sh
  --gate` active.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — pick one of the 3 Resume-contract branches

The session that just ended closed §9.8 row 6.6 (ADR-0031
cycle 1) end-to-end. The Resume contract above lists the 3
defensible next branches; default is (c) Phase 6 forward
motion via row 6.9 `clojure.string`. Cycles 2-5 (D-051) are
ready any time; cycle-3 corpus port (D-054) is also queued.

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md (D-005, D-014a/b, D-017, D-040, D-043, D-048..D-052,
**D-054 new**). D-053 discharged at `7a9e990`.

## Guardrail refresh history (condensed)

Waves 1-11: spirit + Bad Smell + F-NNN + stop-list + ADR-0029
F-009 + ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted
(Alt 2) + 6.16 cluster (48 fns). **Wave 12 (2026-05-25)**:
silent-test-skip surgery → `scripts/check_test_reach.sh` gate
+ `zig_tips.md` "Test discovery via @import" section + clock
API port (D-053) discharged.

## Stopped — user requested

User instruction (2026-05-25): 「ここで、サイクル終端まで達し
コミットしたら、停止していてください」 = stop at the next cycle
end + commit. ADR-0031 cycle 1 closed end-to-end (commit
`701b19a`); test gate green on both Mac + Linux; per-task
note written at `private/notes/phase6-6.6-cycle1c.md` (incl.
extended-challenge Alt hypothesis / Next experiment /
Explicit blocker). Resume at one of the 3 branches in
Resume contract above.
