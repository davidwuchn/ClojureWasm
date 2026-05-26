# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.2 Step 0 —
  general-purpose survey of multimethod dispatch + TypeDescriptor
  hierarchies (`defmulti` / `defmethod` / `prefer-method` /
  `derive` / `isa?` / `make-hierarchy`). Read JVM Clojure at
  `~/Documents/OSS/clojure/src/clj/clojure/core.clj` (multimethod
  defs) + `clojure/lang/MultiFn.java` + cw v0 multimethod path,
  cite ROADMAP principles before adopting any v0 idiom, note ≥ 1
  DIVERGENCE. Output to `private/notes/phase7-7.2-survey.md`.
  Then Step 0.6 re-laying against F-NNN + ROADMAP §9.9 row 7.2
  scope; Step 1 plan picks smallest failing diff_test case.
- **Forbidden this session**: (a) re-deriving Phase 7 entry triad
  — it is complete (T1 ADR-0036 + T2 ADR-0037 + T3 ADR-0035 D9
  second amendment all landed and pushed). (b) any commit that
  adds a VM compile arm body of the form `return error.NotImplemented`
  without an adjacent `// VM-DEFER:` marker —
  `check_dual_backend_parity.sh` will block the push. (c) re-
  introducing the evalInNs / op_in_ns auto-refer block (T3
  removed it per ADR-0035 D9 second amendment). (d) using
  `TypeDescriptor.lookupMethod` directly from new code — go
  through the 7.1 `dispatch(rt, cs, receiver, protocol, method,
  args)` ABI.

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell catalogue incl. "Dual-backend
drift") → `.dev/ROADMAP.md` §9.9 → ADR-0008 (multimethod entry
ADR) → `feature_deps.yaml` → `.dev/debt.md` (Step 0.5 sweep).
Phase 7 entry triad history (archival):
`.dev/archive/phase7_entry_prereq_triad.md` + ADRs 0035 / 0036 /
0037.

## Current state

- **Phase**: Phase 7 IN-PROGRESS — §9.9 rows 7.0 [x] (boundary
  review chain clean) + 7.1 [x] (`8d4841c`, dispatch ABI). Active
  = row 7.2 multimethod.
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 42/42 + OrbStack Ubuntu x86_64 41/41 green at the
  Phase-6→7 boundary close commit.
- **VM-DEFER markers**: 4 active sites (3 deftype-family in
  `vm/compiler.zig` + 1 `require_libspec` in `compileRequire`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.2

Row 7.2 = multimethod dispatch + TypeDescriptor hierarchies
(`defmulti` / `defmethod` / `prefer-method` / `derive` / `isa?` /
`make-hierarchy`). Entry ADR: ADR-0008. Builds on the 7.1 dispatch
ABI; reuses CallSite cache for monomorphic hot paths. Cross-
backend coverage lives in the differential layer per ADR-0036
(diff_test cases land alongside the TreeWalk + VM arms).

D-014c is the §9.9 row 7.2 owner row in `.dev/debt.md`. Step 0.6
re-laying must check F-NNN coverage — multimethod hierarchies
touch TypeDescriptor (F-004 outside Group A core slot path; no
finished-form conflict expected) but not NaN-box layout itself.

## Open questions / blockers

None testable from inside the loop. ADR-0035 D2 second amendment
(`require` migration to runtime fn) unblocked by T2 + T3; may
land in a follow-up cycle outside §9.9 row sequence; not blocking
row 7.2.

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
embedded verbatim into their ADRs. D-073 (e) discharged. Phase
6→7 boundary review chain (audit-2026-05-26) clean — 0 block,
4 soon stale-phase-ref drift cleaned inline (depth 1).
