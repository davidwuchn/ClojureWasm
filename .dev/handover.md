# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 4 files to read (cold-start order)

1. `.dev/handover.md` (this file) — recent landings + guardrail
   refresh log + active task pointer.
2. `CLAUDE.md` § Project spirit (top section, governs all other
   rules) + § Autonomous Workflow (Step 0 → 7).
3. `.dev/principle.md` — Bad Smell catalogue (8 entries incl. new
   Smallest-diff bias / Reservation-as-bias / Progress-pressure)
   + **Structural imagination phase** governing reservation
   tables, directory / file structure, responsibility, dependency.
4. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9, take the
   first `[ ]` row in §9.<N>. At a Phase entry, read the
   placeholder's **Entry ADRs** + **Entry debts** lines and load
   every referenced ADR (incl. all Revision history amendments)
   and `D-NNN` row. (§9.6 row table carries a cleanup-wave smell
   banner — D-028 owns the per-row audit at each owning Phase.)

## Current state

- **Phase**: Phase 4 IN-PROGRESS. §9.6 critical-path closed
  (4.0 / 4.0a / 4.1 / 4.2 / 4.3 / 4.4 / 4.5 / 4.6 / 4.7 / 4.8 /
  4.9 / 4.10 / 4.11 / 4.12 done). Cleanup wave: 4.13–4.24 done
  (status table refreshed 2026-05-23). Remaining §9.6 rows
  (4.25 / 4.26.a-f) — method_table skeleton + error-system
  migration.
- **Branch**: `cw-from-scratch` (long-lived; push free after gate
  green; never push to `main`).
- **Gate**: Mac 12/12 + OrbStack Ubuntu x86_64 11/11 green at
  HEAD. 🔒 fresh OrbStack run due at Phase 4 close.
- **Chapter cadence**: dormant per ADR-0025; existing chapters
  under `docs/ja/archive/`. `private/notes/<task>.md` continues.
- **Unpaired source SHAs**: irrelevant during dormancy. Resumption
  ADR re-engages chapter cadence.

## Guardrail refresh (post-2026-05-23 session)

User-directed correction across two waves:

**Wave 1 — guardrails**:

- **Project spirit** — added to CLAUDE.md top: finished-form
  cleanliness wins, shipping fast / avoiding rework are
  second-tier. Surgical big edits welcome.
- **Bad Smell catalogue** — `principle.md` gained 3 entries:
  **Smallest-diff bias**, **Reservation-as-bias**,
  **Progress-pressure**. P5 reframed as tie-breaker not veto.
- **Structural imagination phase** — `principle.md` new section
  governing reservation tables AND directory / file structure
  AND responsibility separation AND dependency graph. The loop
  imagines Phase 5-20 horizon, records gaps as debt, defers
  decisions to the owning Phase.
- **D-021 retired** — ADR number reservation = smell.
- **ADR-0029 → ADR-0025 renamed** — time-ordered numbering.

**Wave 2 — structural foresight debts (Phase 5-20 imagination
output)**:

- **D-027** — NaN-box layout 第二世代 (Phase 5 entry).
- **D-028** — cleanup-wave row audit, **per owning Phase**.
- **D-029** — `value.zig` split (Phase 5 entry, with D-027).
- **D-030** — `analyzer.zig` split (already above 1000 lines).
- **D-031** — `main.zig` → `src/app/` (Phase 8 entry).
- **D-032** — host `_placeholder.zig` removal procedure (Phase
  5 entry, first host class landing).
- **D-033** — `lang/primitive/` subdir restructure.
- **D-034** — `modules/` top-level (Phase 9 entry).
- **D-035** — 3rd-backend dispatch extraction (Phase 17 entry).
- **D-036** — **zwasm v2 inline-vs-Pod decision (Phase 16
  entry)**. wasm FFI confirmed unavoidable per user direction.
  zwasm v2 carries its own JIT + GC; territorial overlap with
  cw v2 Phase 5 GC + Phase 17 JIT needs Phase-16-entry design.

**Source normalisation executed in this session** (not deferred):

- `build.zig` `-Dwasm=false` option reverted (ADR-0006
  amendment 2).
- `src/runtime/binding_stack.zig` deleted (env.zig is the
  authoritative location for the dynamic-binding stack).

## Active task — §9.6 / 4.25

`src/runtime/dispatch/method_table.zig` — `MethodEntry` struct
(interned symbol + fn ptr) and `CallSite` struct (`last_type` +
`last_method` cache slots) declaration. **But first re-read D-028**
— 4.25 is itself a skeleton-row candidate; consider whether the
smallest-diff landing or "Phase 7 entry: struct + dispatch
together" is the cleaner shape before writing the file.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.25, ADR-0008 (protocol dispatch unify),
  debt D-028 (cleanup-wave audit).
- The new file lives in a `src/runtime/dispatch/` subdirectory
  which does not yet exist — create it.

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-028`). Step 0.5 debt sweep walks them at resume; pay attention
to **D-027 / D-028** which encode the design surgery this
session's guardrail refresh anticipates.
