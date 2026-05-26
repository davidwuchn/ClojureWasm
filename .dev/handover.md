# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.0 boundary
  review chain — invoke `audit_scaffolding` skill on the triad's
  6 commits. Triage block-severity inline; advisory → debt rows.
  If clean, flip row 7.0 to [x] in
  [`.dev/ROADMAP.md`](ROADMAP.md) §9.9 and proceed to §9.9 row 7.2
  (multimethod / `defmulti` / `defmethod` / `prefer-method` /
  `derive`) Step 0. Direct skip 7.0 → 7.2 is OK if audit returns
  clean.
- **Forbidden this session**: (a) re-deriving Phase 7 entry triad
  — it is complete (T1 ADR-0036 + T2 ADR-0037 + T3 ADR-0035 D9
  second amendment all landed and pushed, HEAD `d0a018a`).
  (b) any commit that adds a VM compile arm body of the form
  `return error.NotImplemented` without an adjacent
  `// VM-DEFER:` marker — `check_dual_backend_parity.sh` will
  block the push. (c) re-introducing the evalInNs / op_in_ns
  auto-refer block (T3 removed it per ADR-0035 D9 second
  amendment).

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell catalogue; new "Dual-backend
drift" smell from T1) → `.dev/ROADMAP.md` §9.9 →
`feature_deps.yaml` → `.dev/debt.md` (Step 0.5 sweep). Phase 7
entry triad history (archival):
`.dev/archive/phase7_entry_prereq_triad.md` + ADRs 0035 / 0036 /
0037.

## Current state

- **Phase**: Phase 7 IN-PROGRESS — §9.9 row 7.1 [x] (dispatch
  ABI). **Phase 7 entry prereq triad COMPLETE** (T1 + T2 + T3).
  Active = row 7.0 boundary review chain → row 7.2 multimethod.
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 42/42 + OrbStack Ubuntu x86_64 41/41 green at
  HEAD `d0a018a`.
- **VM-DEFER markers**: 4 active sites at HEAD (3 deftype-family
  in `vm/compiler.zig` + 1 require_libspec in `compileRequire`;
  ns_filter discharged by T3 via `op_ns_with_refer_clojure`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.0 + row 7.2

Row 7.0 = Phase 6 → 7 boundary review chain follow-ups. T1
absorbed the bench sweep + Phase tracker portion mechanically;
remaining work is `audit_scaffolding` execution (CLAUDE.md
§ Phase boundary review chain) on the triad's 6 commits. Close
row 7.0 [x] if no block-severity findings; otherwise land inline
surgery per principle.md Bad Smell sensor.

Row 7.2 = next implementation: multimethod dispatch +
TypeDescriptor hierarchies. Entry ADR: ADR-0008 (Phase 7.1
amendment 1 landed the dispatch ABI; 7.2 uses it).

## Open questions / blockers

None testable from inside the loop. ADR-0035 D2 second amendment
(`require` migration to runtime fn) unblocked by T2 + T3; may
land in a follow-up cycle outside §9.9 row sequence; not blocking
the next active task.

## Guardrail refresh history (condensed)

Waves 1-16 (2026-05-23..26): F-NNN + Bad Smell + ADR-0029..0035 +
provisional-marker mechanisation + handover_framing hook. Phase 6
close: ADR-0035 + clojure.walk/set/string Pattern A + §9.8
bookkeeping. Phase 7 open: §9.9 16-row table + 7.1 dispatch ABI.
Phase 7 entry prereq triad (2026-05-26, 6 commits + 3 per-task
notes): T1 ADR-0036 dual-backend parity contract + rule + hook +
11 diff cases + 5 VM-DEFER markers; T2 ADR-0037 Symbol heap Value
(F-004 Group A slot 1) + SymbolInterner; T3 ADR-0035 D9 second
amendment widening `(:refer-clojure)` + opcode
`op_ns_with_refer_clojure` + naked `(in-ns)`. New Bad Smell
"Dual-backend drift" per T1. Three Devil's-advocate forks
embedded verbatim into their ADRs. D-073 (e) discharged.

## Stopped — user requested

User instruction (2026-05-26): 「T3まで済んだら、 次のクリア
セッションでcontinueできる状態に配線・参照チェーンがうまく
なっているか確認して、 ストップしてください（ユーザー介入）」.
Resume at §9.9 row 7.0 → row 7.2 per Active task above.
