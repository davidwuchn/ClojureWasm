# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 6 files to read (cold-start order)

1. `.dev/handover.md` (this file) — current state + active task.
2. `CLAUDE.md` § Project spirit + § Autonomous Workflow (Step 0 → 7)
   + § The only stop (single condition: user explicit stop) +
   § Smell triggers are interrupts, not stops.
3. `.dev/project_facts.md` — user-declared invariants F-001..F-008
   (treat as project law; never amend without user direction).
4. `.dev/principle.md` — Bad Smell catalogue (16 entries) +
   Structural imagination phase + Devil's-advocate subagent
   mandate at depth ≥ 2 (F-NNN envelope).
5. `.dev/structure_plan.md` — anticipated directory tree
   Phase 5-20 (decree entries vs imagination entries).
6. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9; take the
   first `[ ]` row. At a Phase entry, load each ADR (incl.
   Revision history) / D-NNN row / F-NNN listed in the §9.<N>
   placeholder's Entry ADRs / Entry debts / Entry facts lines.

## Current state

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 rows 5.0–5.8 `[x]`,
  5.9.a `[x]`. ADR-0029 cluster (2026-05-24) `[x]` (6 commits
  58d8cc0..53dd7f2 + Commit 6 handover sweep). 5.9.b/c/d + 5.10-5.16
  remain.
- **Branch**: `cw-from-scratch`. HEAD = 53dd7f2 (Commit 6 will
  advance this).
- **Gate**: Mac 15/15 + OrbStack Ubuntu x86_64 14/14 green at
  53dd7f2 (added 2 new steps: surface_marker, feature_keyword).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## ADR-0029 cluster summary (landed 2026-05-24)

User-directed structural session landed the Java InterOp /
cljw-original surface layout + feature-implementation neutrality
invariant before Phase 6 starts adding host classes.

- ADR-0029 Accepted (supersedes ADR-0011)
- F-009 added to project_facts.md
- runtime/host/ retired; runtime/java/ holds _host_api.zig
- runtime/error/{info,catalog,print}.zig and
  runtime/io/{interface[,default-Phase5+]}.zig consolidation
- G1/G2/G3 gate scripts wired into test/run_all.sh
- See `.dev/decisions/0029_runtime_java_cljw_layout.md` + F-009.

## Active task after cluster — §9.7.10 / 5.9.b Ratio

ADR-0029 cluster 完了後、5.9.b (Ratio extern struct +
gcd-on-construction) から再開。5.9.a (7e2ef17) は BigInt extern +
`*Managed` wrapper + finaliser + `allocFromI64` / `allocFromManaged`
を land 済。続けて 5.9.c (BigDecimal)、5.9.d (arithmetic) を順次。

**Step 0**: F-005 verbatim; ADR-0017; cw v0 collections.zig
Ratio/BigDecimal; clojure JVM Numbers.java. Fork `general-purpose`
survey subagent per `private/notes/phase5-5.9.md` Next experiment.

**Process discipline**: Step 5 — always verify BOTH gates' exit
codes explicitly (`echo "exit=$?"` + `grep "failed:[[:space:]]+0"`)
before commit.

**Open hazards**: (a) Ratio `(*Managed, *Managed)` + gcd via
`std.math.big.int.gcd` (verify Linux platform soundness post-D-047);
(b) auto-promotion paths land at 5.10 (separate row).

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md). Step 0.5 debt sweep
walks them at resume. Phase-5-target rows: D-008 / D-014a / D-014b
/ D-017 / D-030. Phase 7+: D-040 (MethodEntry naming), D-043
(anonymous slot reserves).

## Guardrail refresh history (condensed)

- Wave 1-7 (2026-05-23..24): project spirit, Bad Smell catalogue,
  Structural imagination phase, F-NNN/project_facts hardening,
  Devil's-advocate F-NNN envelope ban, stop-list narrowed to
  "user explicit stop" only.
- Wave 8 (2026-05-24): ADR-0029 + F-009 (Java InterOp / cljw
  surface layout + feature-implementation neutrality, supersedes
  ADR-0011). See `.dev/decisions/0029_*.md`.
