# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `adad9aa5` + the debt batch (D-121..D-129 minted
  2026-05-28 from session-end audit). See `git log` for exact HEAD.
- **First commit on resume MUST be**: take a P0 item from the
  forced-priority list below (NOT the normal §9.16 row 14.11 D-100
  cluster — the audit found block-dependent gaps that wedge ahead).
- **Forbidden this session**: pulling v0.1.0 release tag (row
  14.14) forward without D-121/D-122 + D-100(a)/(b)/(e) landed.
  Re-opening any of rows 14.5-14.10 or D-100(c)/(d) (Discharged).

## Next-session forced priority (audit 2026-05-28)

Session-end audit (user-directed, transcript intact) identified
gaps the autonomous loop missed. These are **block-dependent on
each other** and must land before normal §9.16 row 14.11 D-100
(a)/(b)/(e) work to avoid silent gap at v0.1.0 tag.

**P0 — first 1-2 cycles after `/continue`** (cheap; unblocks
context loss + future orphan / hook issues):
1. **D-125** per-task note batch catch-up (5 notes: 14.9 /
   14.11(c) / 14.11(d) / 14.13 D-066 / ADR-0049). Hot context is
   lost but git log + commit msgs of `ba5b9d99..adad9aa5` carry
   facts. Write to `private/notes/phase14-task14_N.md`. ~30 min.
2. **D-128** orphan-prevention rule extract (`.claude/rules/orphan_prevention.md`)
   + CLAUDE.md cross-ref. ~50 lines. Prevents next REPL-pipe
   incident.
3. **D-129** handover hook trim-Edit exemption (script + rule).
   ~30 LOC. Prevents next 30-min hook-block cycle.

**P1 — v0.1.0 release blocker (must land before row 14.14 tag)**:
4. **D-121** Phase 7 Java static method dispatch infra (~250 LOC,
   analyzer arm + Node + 2 backends + e2e). `(Class/method)`
   syntax is currently all-raise; 15 surfaces (UUID/System/File/…)
   are dead via Java-style call. **Real release blocker** not
   currently in §9.16 row table.
5. **D-122** open D-102 (Ref→TVal ring rewrite) as concrete row
   14.x in §9.16 (Phase 14 entry blocker but never row-assigned).
   Then implement D-102 itself (~150 LOC).
6. **D-100 cluster** remainder: (a) BytecodeChunk constants pool
   (~300 LOC, foundation), (b) `cljw build` CLI (~200 LOC), (e)
   `cljw-formats/0.1.0.edn` archive lock (~80 LOC). Block on (a)
   first.
7. **D-123** snapshot sequencing in §9.16: enumerate row 14.14a
   `v0.1.0 snapshot lock-points` (bench/history + cljw-formats
   archive) before row 14.14 tag.
8. **D-124** compat_tiers.yaml sync-check script + audit; row
   14.13 polish bundle item.
9. **D-126 + D-127** clojure.core forgotten Tier A cluster
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
→ ADR-0049 (gate migration) → ROADMAP §9.16 → debt.md (Active
incl. D-121..D-129).

## Current state

Phase 14 v0.1.0 IN-PROGRESS. Mac gate 85/85; ubuntunote 84/84
(verified ADR-0049 2026-05-28). 8 rows closed this session
(14.5-14.10) + 14.11 partial + 14.13 partial; 2 ADRs minted
(0048 / 0049); 19 debts minted (D-111..D-129); 4 Discharged
(D-014b / D-098 / D-099 / D-066).

## Stopped — user requested

User instruction (2026-05-28): "render-error を commit + push
してから停止 (autonomous loop 再開は次 session)". Then user-
directed audit added the P0/P1 forced-priority list above.
Resume at P0 → P1 sequence when `/continue` next fires.
