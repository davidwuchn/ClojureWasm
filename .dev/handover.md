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

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 rows 5.0 / 5.1 / 5.2 / 5.3 / 5.4 / 5.5 `[x]`.
  5.5 closed at 5b978e8 (4 micro-commits 5.5.a → 5.5.d: ArrayMap
  surface complete with 8 ops). 11 rows remain (5.6–5.16).
  PersistentHashMap shipped on ArrayMap path (≤ 8 entries); HAMT
  body deferred to D-045 follow-up. D13 / D14 named hamt_map_node /
  hash_collision_map_node per ADR-0027 amendment 5. Reader-literal
  `{...}` hook deferred to analyzer follow-up.
- **Branch**: `cw-from-scratch`. HEAD = 5b978e8.
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.7 / 5.6 PersistentHashSet (HashMap-backed)

Land `runtime/collection/set.zig`: HashSet backed by HashMap
(key = element, value = `:cw/present` sentinel per ROADMAP row 5.6).
Day-1: `conj` / `disj` / `contains?` / `count` / `seq`. `#{...}`
reader literal hook deferred to analyzer follow-up.

Since 5.5's HAMT body is deferred (D-045), 5.6 lands on top of
ArrayMap-only — ≤ 8 entries via ArrayMap-backed set. The HAMT
expansion path co-lands when D-045 is taken.

**Step 0 reading**: clojure JVM `PersistentHashSet.java` (thin
wrapper over PersistentHashMap with `:cw/present` sentinel); cw
v0 collections.zig PersistentHashSet (if present); 5.5
implementation patterns from `runtime/collection/map.zig`.

**Step 0 survey target**: not needed for 5.6 — the JVM pattern
(HashMap wrapper with sentinel value) is well-known and 5.5's
implementation already establishes the GC integration. Direct
implementation likely fits in 2-3 micro-commits.

**Open hazards**: (a) `:cw/present` sentinel needs a stable
keyword pointer — must be interned via Runtime.keywords at first
use or via a Layer-0 const; (b) 5.5 deferred HAMT means 5.6
inherits the same limit (≤ 8 entries); (c) set equality semantics
match clojure (order-independent) which the wrapper inherits.

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
