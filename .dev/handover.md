# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 6 files to read (cold-start order)

1. `.dev/handover.md` (this file) — current state + active task.
2. `CLAUDE.md` § Project spirit + § Autonomous Workflow (Step 0 → 7)
   + § The only stop (single condition: user explicit stop) +
   § Smell triggers are interrupts, not stops.
3. `.dev/project_facts.md` — user-declared invariants F-001..F-009
   (treat as project law; never amend without user direction).
4. `.dev/principle.md` — Bad Smell catalogue (16 entries) +
   Structural imagination phase + Devil's-advocate subagent
   mandate at depth ≥ 2 (F-NNN envelope).
5. `.dev/structure_plan.md` — anticipated directory tree
   Phase 5-20 (decree entries vs imagination entries).
6. `.dev/ROADMAP.md` — Phase 6 IN-PROGRESS (§9.8). Take the
   first `[ ]` row. Phase 6 entry ADRs / Entry debts / Entry
   facts in the §9.8 placeholder.

## Current state

- **Phase**: **Phase 6 IN-PROGRESS (opened 2026-05-24)** —
  §9.7 (Phase 5) closed; §9.8 expanded with 15 rows (6.0 →
  6.15). 6.1 = analyzer.zig split (deferred 5.13). Cluster
  work: capability foundations (uuid/clock/random/regex/time/
  file_io), first Java host wave, Clojure stdlib companions.
- **Branch**: `cw-from-scratch`. HEAD advances per boundary
  sync commit on top of b876ee4 (5.13 deferral).
- **Gate**: Mac 16/16 + OrbStack Ubuntu x86_64 15/15 green
  (e2e_phase5_exit added at 5.16).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Phase 5 closing (2026-05-24)

- ADR-0029 cluster: Java + cljw surface layout (supersedes
  ADR-0011), F-009 (feature-implementation neutrality).
- ADR-0030: 5.12.b (defrecord) / 5.12.c (reify) deferred to
  Phase 7 entry. 5.12 narrowed to deftype.
- 5.9.a-d (BigInt/Ratio/BigDecimal extern + arithmetic),
  5.10.a-d (auto-promote + / Ratio + +' family + reader
  literals), 5.11 (TypeDescriptor activation), 5.12.a (deftype +
  ctor + .field, TreeWalk only), 5.13 deferred → Phase 6 entry,
  5.15 phase_at_least_5 flip, 5.16 exit smoke. ADR-0018 a3/a4
  (divide_by_zero, integer_overflow).
- Boundary review chain: audit_scaffolding ran → block items
  (handover stale, F-009 missing from CLAUDE.md preamble, 3
  rules' paths frontmatter still globbing `runtime/host/**`,
  check_compat_tiers_sync.sh header out-of-date) absorbed in
  the same boundary commit. D-032 promoted to Discharged.

## Active task — §9.8.1 analyzer.zig split (D-030, deferred 5.13)

`eval/analyzer.zig` is 1525 lines today (A6 1000-line soft cap
violation). Decompose into
`eval/analyzer/{analyzer (top + dispatch), special_forms
(def/if/do/quote/throw/deftype/ctor/field), bindings (let*/loop*/
fn*), recur, try}.zig`. Behaviour-preserving; the existing test
block stays alongside the function it exercises.

**Step 0**: D-030 verbatim; current analyzer.zig structure
(`grep -nE '^pub fn |^fn ' src/eval/analyzer.zig` lists the
30+ helpers); pull `analyzer/_README.md` template from
`runtime/{error,io}/_README.md` (consolidation precedent).

**Open hazards**: (a) `special_forms.zig` ↔ `bindings.zig`
circular import if both reference each other's analyze*
helpers — break with a tiny `internal.zig` or by inlining the
smaller side. (b) `analyze` mutual recursion across files is
fine in Zig; just avoid forward decls. (c) tests inside
analyzer.zig follow the function — `analyzer.zig` (top)
imports each sub-file so `test { _ = @import(...); }` keeps
discovery whole.

## Open questions / blockers

None testable from inside the loop. Recall: D-005 / D-014a/b /
D-017 (Phase-5-rolled-into-Phase-6 entries are reviewed by Step
0.5 debt sweep), D-040 (MethodEntry naming → Phase 7),
D-043 (anonymous slot reserves → Phase 7 entry), D-048/049/050
(ADR-0029 post-review follow-ups → Phase 6+).

## Guardrail refresh history (condensed)

- Wave 1-7 (2026-05-23..24): project spirit, Bad Smell catalogue,
  Structural imagination phase, F-NNN/project_facts hardening,
  Devil's-advocate F-NNN envelope ban, stop-list narrowed to
  "user explicit stop" only.
- Wave 8 (2026-05-24): ADR-0029 + F-009 (Java InterOp / cljw
  surface layout, supersedes ADR-0011).
- Wave 9 (2026-05-24): ADR-0030 (defrecord + reify → Phase 7);
  Phase 5 closed, Phase 6 opened with §9.8 expanded; boundary
  audit absorbed.
