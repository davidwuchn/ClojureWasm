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

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 8/16 `[x]`
  (6.1-6.4, 6.5.a, 6.7, 6.8, 6.16). Remaining: 6.5.b (TZ
  data — defer), 6.6 (regex, engine-choice ADR), 6.9-6.12
  (clojure.string/set/walk/zip — needs bootstrap multi-clj
  load), 6.13 (yaml sweep ~34 entries), 6.14 (exit smoke),
  6.15 (phase flip).
- **Branch**: `cw-from-scratch`. HEAD ≈ b5df7db (ADR-0031
  cycle 1 skeleton set landed: compile.zig + match.zig +
  Pattern.zig surface + lang/primitive/regex.zig peer; all
  raise NotImplemented per `no_op_stub_forbidden`).
- **Gate**: Mac 16/16 + OrbStack Ubuntu x86_64 15/15 green.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Phase 5 closing (2026-05-24)

ADR-0029 cluster (Java + cljw surface layout, F-009) + ADR-0030
(defrecord/reify → Phase 7) + 5.9-5.16 landings (numeric tower,
TypeDescriptor, deftype skeleton, exit smoke). Boundary review
chain absorbed audit_scaffolding findings (handover, CLAUDE.md
F-009 enumeration, 3 rules' paths frontmatter, compat_tiers
sync header). D-032 Discharged.

Phase 6.1 (analyzer.zig split per D-030, deferred 5.13) landed
2026-05-24 in 5 commits (1ac8198..149371f); D-030 discharged.

## Active task — §9.8 next: 6.6 (regex ADR) or 6.13 (yaml sweep)

Phase 6 progressed 8/16. Row 6.16 cluster expanded into a
broad Tier A surface (46 fns across `core.zig` predicates +
`math.zig` sign / parity / mod / bit / shift / strict
arithmetic). The cluster is at a Progress-pressure smell
boundary — further single-primitive expansion is cheaper than
the exit-criterion deliverable. The next session should pivot
away from primitive accretion and take 6.6 directly.

**Recommended next**: ADR-0031 Alt 2 cycle 1 parser + AST
emit. The four skeletons (compile.zig / match.zig /
Pattern.zig / primitive/regex.zig) are all wired and gate-
green; each currently raises NotImplemented per
`no_op_stub_forbidden`. Next commit fills compile.zig parser:
recursive-descent on the regex source → `Node` AST → IR `Inst`
slice; then match.zig Pike-VM step loop; then primitive/regex.zig
registers `re-find` + `re-matches` against `Program`, with the
Phase 6.6 exit smoke `(re-find #"\d+" "abc123")` → `"123"`
as the cycle-1 acceptance test.

Cycle 2-5 remain queued (lazy DFA + capture groups + `(?i)` +
`PatternSyntaxException`-aligned errors); see D-051. The Alt 3
intern-cache promotion lives in D-052 as a Phase 10+ recall.

compat_tiers.yaml entry for `java.util.regex.Pattern` (new
schema: `keyword: regex` + `files:` listing all four file
paths) lands in the same commit as the cycle-1 first-green so
G2 / G3 gates start validating immediately.

Alternative parallel-track: 6.13 yaml sweep — mechanical bulk
diff over ~34 legacy entries to ADR-0029 D5 schema. Low risk,
G3 gate validates each row.

**Open hazards**: (a) 6.6 regex ADR depth 2-3 (Devil's-advocate
fork mandatory). (b) 6.5.b TZ data multi-MB embed — defer.
(c) 6.9 bootstrap.zig multi-clj-load extension (load order if
clojure.string top-level depends on clojure.core fns).

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md (D-005, D-014a/b, D-017, D-040, D-043, D-048..D-052).

## Guardrail refresh history (condensed)

Waves 1-10: spirit + Bad Smell + F-NNN hardening + stop-list +
ADR-0029 F-009 + ADR-0030 + 6.1 analyzer split. Wave 11:
ADR-0031 Accepted (Alt 2) + 6.16 cluster (48 fns).
