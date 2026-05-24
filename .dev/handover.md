# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 6 files to read (cold-start order)

1. `.dev/handover.md` (this file) — current state + active task.
2. `CLAUDE.md` § Project spirit + § Autonomous Workflow (Step 0 → 7)
   + § The only stop (single condition: user explicit stop) +
   § Smell triggers are interrupts, not stops.
3. `.dev/project_facts.md` — user-declared invariants F-001..F-008
   (treat as project law; never amend without user direction).
4. `.dev/principle.md` — Bad Smell catalogue (16 entries) +
   Structural imagination phase + Devil's-advocate subagent
   mandate at depth ≥ 2 (F-NNN envelope).
5. `.dev/structure_plan.md` — anticipated directory tree
   Phase 5-20 (decree entries vs imagination entries).
6. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9; take the
   first `[ ]` row. At a Phase entry, load each ADR (incl.
   Revision history) / D-NNN row / F-NNN listed in the §9.<N>
   placeholder's Entry ADRs / Entry debts / Entry facts lines.

## Current state

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 rows 5.0 / 5.1 / 5.2 / 5.3 / 5.4 / 5.5 / 5.6 `[x]`.
  5.6 closed at 9553840 (single commit, 5 day-1 ops on HashMap-
  backed wrapper). 10 rows remain (5.7–5.16). Collection family
  trio (Vector / HashMap-ArrayMap / HashSet) all shipping; HAMT
  body still D-045.
- **Branch**: `cw-from-scratch`. HEAD = 9553840.
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.8 / 5.7 LazySeq `force()` + thunk realisation

Activate `runtime/lazy_seq.zig` (4.24 skeleton): `force()` walks
the thunk and caches the realised Seq into `seq_cache`. `seq` /
`first` / `rest` / `next` understand `.lazy_seq` Values. Test:
`(reduce + (range 1e6))` without OOM (chunked realisation through
GC). Per ADR-0009 amendment + 5.1 input bullet #2 the mutex shape
decision happens here.

**Step 0 reading**: ADR-0009 amendment 2 (double-checked locking);
`phase5-5.1-survey.md` Block A (cw v0 `io_default.zig` rationale,
verbatim) + survey bullets 1 / 2 / 4 (root walker + mutex + thunk
shape); `phase5-skeleton-audit.md` §"`src/runtime/lazy_seq.zig`"
(skeleton has `std.atomic.Mutex` field — Zig-0.16 gap noted).

**Mutex decision (5.7 owns)**: choose between (a) no lock per cw v0
single-thread (Phase 5 OK, Phase 15 revisit); (b) std.Io.Mutex via
io_default pattern (matches survey Block A); (c) std.atomic.Value
busy-spin (lock-free). Per F-002 + Phase 5 single-thread reality,
(a) likely lands at 5.7 with explicit "Phase 15 STM activation
re-evaluates" debt row.

**Open hazards**: (a) `seq_cache` Value-typed slot pre-existing
as `std.atomic.Value(?*SeqOpaque)` — atomic state survives even
under choice (a); GC root walker must trace whatever pointer the
atomic carries (5.1 input bullet #1); (b) `thunk: *const fn` is
NOT a Value-encoded fn — it's a Zig fn pointer; ctx is *anyopaque
which the GC trace cannot blindly walk per 5.1 input #1 —
finished form may need ctx tagging or per-LazySeq trace fn
registration; (c) `(reduce + (range 1e6))` exit smoke needs
chunked realisation NOT to OOM — auto-trigger collect may finally
become necessary here (defer-or-trigger decision lives in 5.7).

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md) (rows D-005 through
D-043). Step 0.5 debt sweep walks them at resume; pay attention
to D-008 / D-014a / D-014b / D-017 / D-030 (other Phase-5-target
rows that 5.2-5.16 will land), D-040 (Phase 7 MethodEntry
naming — do not touch in Phase 5), D-043 (anonymous slot
reserves for Phase 7 entry to revisit).

## Guardrail refresh history (condensed)

User-directed guardrail evolution 2026-05-23 / -24:

- Wave 1-2 (2026-05-23): project spirit (finished-form wins),
  Bad Smell catalogue grew Smallest-diff / Reservation-as-bias /
  Progress-pressure smells, Structural imagination phase, and
  ten D-027..D-036 structural-foresight debts for Phase 5-20.
- Wave 3 (2026-05-23): root-cause hardening after the long-context
  research (`private/notes/llm_long_context_research.md`) —
  `.dev/project_facts.md` (F-NNN, project law),
  `scripts/check_smell_audit.sh` PreToolUse hook.
- Wave 4-5 (2026-05-24): F-004 NaN-box 64-slot / F-005 numeric
  tower / F-006 GC strategy / F-007 chapter cadence dormant /
  F-008 zwasm v2 spec review; `.dev/structure_plan.md` Phase 5-20
  tree.
- Wave 6 (2026-05-24): F-NNN hardening — preamble = project law,
  5-level priority chain, Devil's-advocate F-NNN envelope ban,
  `scripts/check_facts_immutable.sh` PreToolUse hook. Silent
  default-shift smell added to principle.md.
- Wave 7 (2026-05-24): stop-list narrowed to "user explicit stop"
  only; smell triggers are interrupts (in-flight surgery),
  build/test failures are Active-task items, Phase / region /
  task / commit boundaries roll into the next unit of work.
