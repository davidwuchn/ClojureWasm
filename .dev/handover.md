# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (HEAD refreshes only on Active-task-
  identifier change).
- **First commit on resume MUST be**: open **Phase 6.16.d** —
  clojure.string Pattern B2 14 vars shim 化 per v5 §8.1 + §9.2.
  Existing 14 vars (upper-case / lower-case / trim / triml /
  trimr / trim-newline / starts-with? / ends-with? / includes? /
  index-of / last-index-of / reverse / re-quote-replacement)
  rename to `-name` leaf in `lang/primitive/string.zig`, then
  add Layer 3 1-line shim `(def name (fn* [...] (-name-leaf ...)))`
  defns in `lang/clj/clojure/string.clj`. e2e
  `clojure_string_shim.sh`. Survey via general-purpose subagent
  first (output `private/notes/phase6-6.16.d-survey.md`).
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
  + 6.16.c (clojure.walk Pattern A 10/10 vars) landed.
  **Active task = Phase 6.16.d** (clojure.string Pattern B2
  shim 化).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md` (1593 lines).
- **Gate**: Mac 39/39 + OrbStack Ubuntu x86_64 38/38 green at
  8d1957f.
- **Provisional markers**: 5 markers / 5 entries remaining in
  `feature_deps.yaml` (D-070 join, D-074 map-invert, D-075
  project + rename, D-076 rename-keys, D-077 catch_class_table).
- **Chapter cadence**: dormant per ADR-0025 + F-007.
- **New primitives this session** (6.16.c byproducts): `keyword`,
  `name`, `println` in rt's core.zig — generally useful beyond
  walk.

## Active task — Phase 6.16.d (clojure.string Pattern B2 shim)

Existing 14 `clojure.string` Zig vars (upper-case / lower-case /
trim / triml / trimr / trim-newline / starts-with? / ends-with? /
includes? / index-of / last-index-of / reverse /
re-quote-replacement; D-062 cluster) rename their Zig fn to
`-name` (Pattern B2 leaf) + ship a 1-line shim `(def name (fn*
[args] (-name-leaf args)))` in `string.clj`. Surface API stays
identical from the user's side; placement migrates from
Pattern transient_zig → Pattern B2.

## Open questions / blockers

None testable from inside the loop. Step 0.5 sweep walks
remaining debt rows; ADR-0035 cluster closed.

## Guardrail refresh history (condensed)

Waves 1-14 (2026-05-23..25): spirit + Bad Smell + F-NNN +
ADR-0029..0034 + v5 plan + ROADMAP §9.8 + debt D-062..D-073.
Wave 15-16 (2026-05-26): provisional-marker mechanisation +
hook_lib.sh + watch_findings.md + framework_completion + audit
E2 expansion. Phase 6.16.b-4 (10 commits 9dc3a8e..a762ca9):
ADR-0035 issuance + D-058/D-063/D-071 closure + 11 PROVISIONAL
marker discharge. Phase 6.16.c (6 commits 1e5404d..8d1957f):
clojure.walk Pattern A 10 vars + 3 prereq primitives (keyword /
name / println).
