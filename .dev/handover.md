# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `33ca37ec` (P0 batch + ADR-0050 + D-121 unified
  InteropCallNode landed; see `git log` for exact HEAD).
- **First commit on resume MUST be**: P1 item #2 = **D-122 row-
  assignment for D-102 Ref→TVal ring rewrite** — open row 14.x
  in `.dev/ROADMAP.md` §9.16 + sequence vs D-100(a-e), then
  implement D-102 (~150 LOC: TVal struct + history ring + lock
  placeholder).
- **Forbidden this session**: pulling v0.1.0 release tag (row
  14.14) forward without D-122 + D-100(a)/(b)/(e) landed.
  Re-opening any of rows 14.5-14.11 or D-121/D-125/D-128/D-129
  (Discharged this session).

## Active priority (D-121 discharged via ADR-0050)

P0 (D-125 / D-128 / D-129) + P1 #1 D-121 Discharged this session.
D-121 landed via ADR-0050 unified `InteropCallNode` (depth-3
surgery; cycle-budget defer rejected per the new Cycle-budget
defer smell in `.dev/principle.md`). 3 retired Node variants +
2 governance smells minted + 86/86 gate. P1 #2 leads.

**P1 remaining — v0.1.0 release blockers (must land before row
14.14 tag)**:
1. **D-122** open D-102 (Ref→TVal ring rewrite) as concrete row
   14.x in §9.16, then implement D-102 (~150 LOC).
2. **D-100 cluster** remainder: (a) BytecodeChunk constants pool
   (~300 LOC, foundation), (b) `cljw build` CLI (~200 LOC), (e)
   `cljw-formats/0.1.0.edn` archive lock (~80 LOC). Block on (a)
   first.
3. **D-130** VM lowering of `interop_call_node` `.static_method`
   (the D-121 follow-on — only a release blocker if v0.1.0
   promises VM-mode parity for Java statics; TreeWalk works).
4. **D-123** snapshot sequencing in §9.16: enumerate row 14.14a
   `v0.1.0 snapshot lock-points` (bench/history + cljw-formats
   archive) before row 14.14 tag.
5. **D-124** compat_tiers.yaml sync-check script + audit; row
   14.13 polish bundle item.
6. **D-126 + D-127** clojure.core forgotten Tier A cluster
   (concat/mapcat/get-in/assoc-in/update-in + pr-str/prn/print);
   row 14.13.

**P2 — structural; non-blocking but should land before Phase 15**:
- DA-mandatory depth boundary clarification (principle.md +
  CLAUDE.md align).
- Step 0 Survey batch exemption (multi-row sequential context
  share guideline).
- F-002 vs F-003 decision tree.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` → `.dev/principle.md`
→ `.claude/rules/orphan_prevention.md` → ROADMAP §9.16 →
debt.md (Active incl. D-121..D-127).

## Current state

Phase 14 v0.1.0 IN-PROGRESS. Mac gate 86/86; ubuntunote re-
verify at next Phase boundary per ADR-0049. ADR-0050 minted
this resume (unified InteropCallNode). 23 debts minted across
session (D-111..D-130); 8 Discharged (D-014b / D-066 / D-098 /
D-099 / D-121 / D-125 / D-128 / D-129).
