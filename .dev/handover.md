# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: `a46a241` (see `git log` for stale-drift; HEAD line
  refreshes only on Active-task-identifier change per the
  ≤ 2 / session cap).
- **First commit on resume MUST be**: ADR-0031 Alt 2 cycle 1
  parser extension — recursive-descent refactor that adds
  alternation `|` and the `*`/`+`/`?` quantifiers as the next
  pair, so `Inst.split` / `Inst.jmp` join the IR and `tryMatchAt`
  is replaced by the proper Pike-VM thread-list driver in
  `runtime/regex/match.zig`. Acceptance: `(re-find #"a|b" "xby")`
  → `{start=1, end=2}` and `(re-find #"a*" "aaa")` → `{start=0,
  end=3}` green at the Zig unit-test layer.
- **Forbidden this session**: (a) expanding `core.zig` /
  `math.zig` primitive cluster — 6.16 is closed at 48 fns; only
  re-open if a downstream caller (6.9 clojure.string etc.)
  genuinely needs a primitive that is absent. (b) handover
  HEAD-pointer churn — leave the field stale and refresh only
  when the Active-task identifier itself changes. (c) Proposed
  ADR landing across session boundaries (CLAUDE.md
  Proposed→Accepted same-cycle rule).

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell + Devil's-advocate mandate)
→ `.dev/structure_plan.md` → `.dev/ROADMAP.md` §9.8.

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

## Active task — §9.8 row 6.6 (regex impl against ADR-0031)

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
