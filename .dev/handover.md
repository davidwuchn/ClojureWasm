# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (HEAD refreshes only on Active-task-
  identifier change).
- **First commit on resume MUST be**: open **Phase 6.16.c** —
  clojure.walk 10 vars (`prewalk` / `postwalk` / `keywordize-keys`
  / `stringify-keys` / `prewalk-replace` / `postwalk-replace` /
  `prewalk-demo` / `postwalk-demo` Pattern A landing + `walk` B2
  leaf preserved + `macroexpand-all` `^:unsupported` declare-only).
  v5 §9.1; ROADMAP §9.8 row 6.16.c. Survey via general-purpose
  subagent first (output `private/notes/phase6-6.16.c-survey.md`).
- **Forbidden this session**: (a) `__zig-` namespace prefix path.
  (b) `clojure.X.impl/` sub-ns path. (c) `cljw build --source/
  --debug/--aot` flag path. (d) mixing human + EDN in single
  stderr stream. (e) ABI-level bytecode format commitment.
  (f) introducing new PROVISIONAL markers without same-commit
  yaml + debt.md sync (the hook will physically block — see
  `.claude/rules/provisional_marker.md`).

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell + Devil's-advocate mandate) →
**`private/notes/clj_vs_zig_split_proposal_v5.md` (placement /
build / error 確定計画 SSOT)** → `.claude/rules/provisional_marker.md`
(marker lifecycle + SSOT triad) → `feature_deps.yaml` (5 provisional
entries / 5 marker sites — post-ADR-0035 discharge) →
`.dev/structure_plan.md` → `.dev/ROADMAP.md` §9.8.

## Current state

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8. 6.16.b cluster
  complete: a/b/c.1-c.7/d 全 10 commits landed for ADR-0035
  (require + ns + per-file SourceContext + D-058/D-063/D-071
  closures + 11 PROVISIONAL marker discharge).
  **Active task = Phase 6.16.c** (clojure.walk Pattern A).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md` (1593 lines).
- **Gate**: Mac 37/37 + OrbStack Ubuntu x86_64 36/36 green at
  a762ca9.
- **Provisional markers**: 5 markers / 5 entries remaining in
  `feature_deps.yaml` after sub-cycle d discharge (D-070 join,
  D-074 map-invert, D-075 project + rename, D-076 rename-keys,
  D-077 catch_class_table). Hook live + wired.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 6.16.c (clojure.walk Pattern A)

clojure.walk 10 vars landing in 1 cycle per v5 §9.1: keep current
`walk` Zig leaf (B2 placement), add 8 Pattern A defns (`prewalk` /
`postwalk` / `keywordize-keys` / `stringify-keys` / `prewalk-
replace` / `postwalk-replace` / `prewalk-demo` / `postwalk-demo`),
add `macroexpand-all` declare-only `^:unsupported` marker (Phase
7 macro completion follow-up). e2e `clojure_walk_full.sh`. ADR-0035
`(ns clojure.walk (:refer-clojure))` head + `(require ...)` are
now available for the .clj defns.

## Open questions / blockers

None testable from inside the loop. Step 0.5 sweep walks
debt.md remaining open rows; ADR-0035 cluster closed sub-cycle d.

## Guardrail refresh history (condensed)

Waves 1-14 (2026-05-23..25): spirit + Bad Smell + F-NNN +
ADR-0029..0034 + v5 plan + ROADMAP §9.8 + debt D-062..D-073.
Wave 15-16 (2026-05-26): provisional-marker mechanisation +
16-marker retrofit + hook_lib.sh + watch_findings.md +
framework_completion + 3 Bad Smell + audit E2 expansion.
Phase 6.16.b-4 (2026-05-26, 10 commits 9dc3a8e..a762ca9):
ADR-0035 issuance + D-058/D-063/D-071 closure + 11 PROVISIONAL
marker discharge.
