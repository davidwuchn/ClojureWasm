# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (HEAD refreshes only on Active-task-
  identifier change).
- **First commit on resume MUST be**: **read
  [`.dev/phase7_entry_prereq_triad.md`](phase7_entry_prereq_triad.md)
  in full, then execute T1 → T2 → T3** in that order before
  starting any §9.9 row past 7.1. T1 = VM backend parity catch-up
  + ADR-0036 + dual-backend-parity rule + hook. T2 = Symbol heap
  Value impl (F-004 Group A slot 1) + ADR-0037. T3 = ADR-0035 D9
  second amendment ((:refer-clojure) semantic widening). The
  triad doc carries paste-ready Survey + Devil's-advocate briefs
  for each item; do not re-derive them. Devil's-advocate fork is
  mandatory at depth ≥ 2 for each of T1 / T2 / T3 (each requires
  a new ADR or an Accepted-ADR amendment).
- **Forbidden this session**: (a) `__zig-` namespace prefix path.
  (b) `clojure.X.impl/` sub-ns path. (c) `cljw build --source/
  --debug/--aot` flag path. (d) mixing human + EDN in single
  stderr stream. (e) ABI-level bytecode format commitment.
  (f) introducing new PROVISIONAL markers without same-commit
  yaml + debt.md sync (hook physically blocks). (g) skipping the
  triad ordering — T1 before T2 before T3 (re-ordering creates
  downstream retrofit cost; rationale in the triad doc).
  (h) starting Phase 7.2+ rows before the triad lands.

## Cold-start reading order

handover (this file) → **[`.dev/phase7_entry_prereq_triad.md`](phase7_entry_prereq_triad.md)
(operational driver — read fully before T1)** → CLAUDE.md (§ Project
spirit + § Autonomous Workflow + § The only stop) →
`.dev/project_facts.md` (F-001..F-009; T2 directly implements F-004
slot 1) → `.dev/principle.md` (Bad Smell + Devil's-advocate mandate)
→ `private/notes/clj_vs_zig_split_proposal_v5.md` →
`.claude/rules/provisional_marker.md` (T1's `VM-DEFER:` marker
mirrors PROVISIONAL: shape) → `feature_deps.yaml` → `.dev/debt.md`
(T1 closes / amends D-073) → `.dev/structure_plan.md` →
`.dev/ROADMAP.md` §9.9 (Phase 7 task table — triad lands BEFORE
row 7.2).

## Current state

- **Phase**: **Phase 7 IN-PROGRESS** — §9.9 row 7.1 [x] (dispatch
  ABI landed via ADR-0008 amendment 1 + Devil's-advocate fork
  embedded). **Active task = Phase 7 entry prereq triad** (T1 → T2
  → T3 per the operational driver doc). Phase 6 fully closed; §9.8
  all rows resolved or named-deferred.
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 41/41 + OrbStack Ubuntu x86_64 40/40 green at the
  HEAD that includes this handover update.
- **Provisional markers**: 5 entries / 5 marker sites (D-070 join,
  D-074 map-invert, D-075 project + rename, D-076 rename-keys,
  D-077 catch_class_table). T3 may discharge
  `runtime/eval/in_ns_auto_refer` if option (B) lands cleanly.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 7 entry prereq triad

Read `.dev/phase7_entry_prereq_triad.md` BEFORE starting any work.
The doc carries: T1/T2/T3 rationale + ordering proof + paste-ready
Survey briefs (general-purpose subagent input) + paste-ready
Devil's-advocate briefs (depth-2 fork input) + ADR-0036 / ADR-0037
draft skeletons + ADR-0035 D9 second amendment skeleton + cold-start
verification checklist + reference verification table. Total ~600
lines; self-contained for a cold session.

Triad summary (full detail in the driver doc):

- **T1**: VM backend parity catch-up + ADR-0036 + `.claude/rules/
  dual_backend_parity.md` + `scripts/check_dual_backend_parity.sh`
  hook. Retrofit existing RequireNode + NsNode VM gaps in same
  cycle. Estimated 1-2 cycles. Closes / amends D-073.
- **T2**: Symbol heap Value impl in `src/runtime/symbol.zig`
  parallel to keyword.zig. F-004 Group A slot 1. New ADR-0037.
  Unlocks 5 downstream Phase 7 rows (7.3 / 7.4 / 7.5 / 7.7 / 7.8)
  + permits ADR-0035 D2 second amendment (`require` runtime fn
  migration). Estimated 1-2 cycles.
- **T3**: ADR-0035 D9 second amendment — `(:refer-clojure)`
  semantic in cw v1 widens to include rt. Remove evalInNs /
  op_in_ns auto-refer blocks. Estimated 1 cycle.

## Open questions / blockers

None testable from inside the loop. The triad doc lists open
questions per item that the Devil's-advocate fork weighs in on.

## Guardrail refresh history (condensed)

Waves 1-16 (2026-05-23..26): F-NNN + Bad Smell + ADR-0029..0035 +
provisional-marker mechanisation + handover_framing hook. Phase 6
close (2026-05-26, ~33 commits): ADR-0035 (require/ns) + clojure.
walk Pattern A + clojure.string shim/Pattern A + Phase 6 exit
smoke + ROADMAP §9.8 bookkeeping. Phase 7 open: §9.9 16-row table.
Phase 7.1 (dispatch ABI) + Phase 7 entry prereq triad doc landed.
