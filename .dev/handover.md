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

- **Phase**: **Phase 5 IN-PROGRESS** — §9.7 rows 5.0–5.8 `[x]`.
  5.8 closed at 6fe11c6 (5.8.a struct shapes for ChunkBuffer +
  ChunkedCons; 5.8.b range/lazy-seq integration deferred). 8 rows
  remain (5.9–5.16). list.zig rename deferred per F-003 (no
  behaviour win). ChunkedCons + ChunkBuffer trace fns registered.
- **Branch**: `cw-from-scratch`. HEAD = 6fe11c6.
- **Gate**: Mac 13/13 + OrbStack Ubuntu x86_64 12/12 green.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.7.10 / 5.9 BigInt / Ratio / BigDecimal arithmetic (F-005)

Activate per F-005 + ADR-0017 + the 5.3.d.9 deferred BigInt
migration. **Owns the BigInt extern-struct restructure** (Managed
has non-extern fields — needs `*Managed` wrapper). New types:
- `runtime/numeric/big_int.zig` (already exists, activate)
- `runtime/numeric/ratio.zig` (new) — `BigInt × BigInt` simplified
  on construction
- `runtime/numeric/big_decimal.zig` (new) — `(BigInt unscaled,
  i32 scale)`
- `runtime/numeric/promote.zig` (new) — Long ↔ BigInt promotion
  paths per `+` / `-` / `*` / `/`

`compare` / `+` / `-` / `*` / `/` extended to handle the wider
tower. F-005 anchors: JVM-surface compat (user-observable), Zig-
stdlib-affine internal (`std.math.big.int.Managed` for limbs).

**Step 0 reading**: F-005 verbatim; ADR-0017 (3-layer alloc +
infra_alloc for limbs); cw v0 `runtime/collections.zig` BigInt/
Ratio/BigDecimal; clojure JVM Numbers.java (numeric tower
dispatch).

**Step 0 survey target** (`general-purpose` subagent): cw v0
numeric tower + clojure JVM Numbers.

**Open hazards**: (a) Managed wrapping — `*Managed` pointer to
infra_alloc-managed storage; finaliser must `Managed.deinit`
before sweep rawFrees BigInt wrapper; (b) Ratio simplification
(gcd) at construction; (c) auto-promotion paths in `+ - * /` —
F-005 says user-observable JVM-exact; (d) 5.10 is the next row
(promotion auto-trigger paths) — 5.9 lands arithmetic, 5.10
lands the auto-promotion dispatch.
chunked seqs via the new types — 5.8 lands the data shape, range
implementation may need a co-commit or separate row.

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
