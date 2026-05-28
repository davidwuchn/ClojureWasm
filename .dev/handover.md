# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `23423532` (D-125/128/129 P0 batch landed; see
  `git log` for exact HEAD).
- **First commit on resume MUST be**: P1 item #1 = **D-121 Phase 7
  Java static method dispatch infra** (`(Class/method)` analyzer
  arm + Node + TreeWalk + VM + e2e for `(java.util.UUID/randomUUID)`).
- **Forbidden this session**: pulling v0.1.0 release tag (row
  14.14) forward without D-121/D-122 + D-100(a)/(b)/(e) landed.
  Re-opening any of rows 14.5-14.10 or D-100(c)/(d) (Discharged).

## Active priority (P0 batch discharged 2026-05-28 session resume)

P0 (D-125 / D-128 / D-129) Discharged this resume: per-task note
batch landed; orphan-prevention rule extracted; handover hook
gained trim-Edit exemption. P1 now leads.

**P1 — v0.1.0 release blockers (must land before row 14.14 tag)**:
1. **D-121** Phase 7 Java static method dispatch infra (~250 LOC,
   analyzer arm + Node + TreeWalk + VM compile + e2e). 15 Java
   surfaces (UUID/System/File/…) currently dead via `(Class/method)`
   call. **Real release blocker** not currently in §9.16 row table.
2. **D-122** open D-102 (Ref→TVal ring rewrite) as concrete row
   14.x in §9.16, then implement D-102 (~150 LOC).
3. **D-100 cluster** remainder: (a) BytecodeChunk constants pool
   (~300 LOC, foundation), (b) `cljw build` CLI (~200 LOC), (e)
   `cljw-formats/0.1.0.edn` archive lock (~80 LOC). Block on (a)
   first.
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

Phase 14 v0.1.0 IN-PROGRESS. Mac gate 85/85; ubuntunote 84/84
last verified ADR-0049 2026-05-28. 8 rows closed in 2026-05-28
session (14.5-14.10) + 14.11 partial + 14.13 partial; 2 ADRs
minted (0048 / 0049); 22 debts minted across that session +
resume (D-111..D-129); 7 Discharged
(D-014b / D-066 / D-098 / D-099 / D-125 / D-128 / D-129).
