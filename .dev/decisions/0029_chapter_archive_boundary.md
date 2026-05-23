# 0029 — Big-bang chapter regeneration boundary at Phase-4 critical-path close

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude, autonomous-loop self-accept)
- **Tags**: phase-4-exit, documentation, learn_clojurewasm, learn_zig, archive, big-bang

## Context

The `code_learning_doc` skill (`.claude/skills/code_learning_doc/SKILL.md`
L177-197) already establishes a "big-bang regeneration policy" — when
the codebase undergoes a significant design transition, the existing
chapter sequence moves to `docs/ja/archive/learn_clojurewasm_v1_<phase-range>/`
and a new chapter sequence is generated in one batch covering the new
design.

Two facts make Phase 4 critical-path close the natural boundary:

1. **The Phase 1-3 chapter set (0001-0020) covers the pre-VM design.**
   Phase 4 introduces a second backend (VM dispatch loop, compiled
   bytecode, dual-backend driver, differential oracle) and rewrites
   several Phase 1-3 surfaces (Function carries `bytecode: ?*const
   BytecodeChunk`, vtable gains `evalChunk`, callFunction routes
   through it, etc.). Writing Phase-4 chapters as continuations of
   0001-0020 would force readers to absorb two designs in series; a
   regenerated set anchored on the post-VM shape is cleaner.

2. **The Phase 4 cleanup wave (4.13-4.24) accumulated 11 source
   commits without per-task notes.** The autonomous loop prioritised
   forward progress over the chapter cadence. Hot context for those
   commits is lost; retroactive chapter writing from `git log` would
   produce low-quality material (per
   `code_learning_doc/SKILL.md` L173-175: "Writing the chapter at
   the *end* of the phase from `git log` only. By that point the
   why-not's are forgotten.").

The `learn_zig` companion (`docs/ja/learn_zig/`, 30 chapters / 2400
lines) was scoped explicitly as the Phase-1-3 code-reading reader
("ROADMAP / phase progression からは独立した副読本" — see
`docs/ja/learn_zig/README.md` L8-10). Phase 4 introduces a substantial
amount of Zig material (vtable hooks with `*const anyopaque`,
comptime branching on build_options, `std.atomic.Mutex`, `packed
struct(u32)` for gc_and_lock, etc.) that the existing 30 chapters do
not cover. A regeneration boundary aligns both reader sets.

## Decision

Execute the big-bang boundary now (Phase 4 critical-path close at
commit 2868e21):

1. **Archive existing chapters in place.**
   - `docs/ja/learn_clojurewasm/0001-0020 + README.md` →
     `docs/ja/archive/learn_clojurewasm_v1_phase1to3/` (rename
     unchanged).
   - `docs/ja/learn_zig/README.md` →
     `docs/ja/archive/learn_zig_v1/README.md`.

2. **Put the chapter cadence into dormant mode.**
   - `code_learning_doc/SKILL.md` two-cadence rule's per-concept
     chapter half is suspended. The per-task notes half continues
     (`private/notes/<phase>-<task>.md` from hot context — these
     remain load-bearing as Step 7 input).
   - `scripts/check_learning_doc.sh` becomes a no-op gate while
     dormant (returns success without enforcing pairing). The Skill
     and the gate together carry an explicit "dormant" marker so
     re-activation is a one-line edit.
   - CLAUDE.md `code_learning_doc` skill reference updated to note
     dormancy + pointer to this ADR.

3. **Re-resumption conditions.**
   - A future ADR (`ADR-NNNN — Resume chapter sequence at Phase
     <N> entry`) explicitly switches the cadence back on. The
     trigger is at the project owner's discretion; the most natural
     candidates are Phase 4 closure (4.13-4.26.f complete) or Phase
     5 entry (mark-sweep GC + TypeDescriptor activation).
   - At resumption, the new chapter sequence starts at `0001` of
     the regenerated set under `docs/ja/learn_clojurewasm/`, using
     the surviving per-task notes as Step-7 input. Archived
     chapters stay read-only references for "how the design used
     to look".

4. **per-task notes during dormancy.**
   - Continue writing per-task notes under `private/notes/` (Step 7
     of the per-task TDD loop). They are not gated; they are the
     hot-context capture that the eventual regeneration consumes.
   - Notes already written (4.6 / 4.7.a / 4.7.b / 4.7.c) are
     preserved. Tasks 4.8-4.24 have no per-task notes; this is
     accepted as a one-time gap and not retroactively filled.

## Alternatives considered

### Alternative A — Continue the chapter cadence as 0021 forward

- **Sketch**: Write chapters 0021-0024 for tasks 4.6-4.12 right now
  from `git log` + ADRs + source, mark 4.13-4.24 as "skeleton wave,
  no chapter".
- **Why rejected**: the hot context for 4.6-4.12 has largely
  decayed (the autonomous loop ran straight through them without
  pausing). Retroactive chapter quality would breach the skill's
  "do not write from `git log` alone" guidance. The result would
  read like a session log, not a textbook.

### Alternative B — Defer the boundary until Phase 5 entry

- **Sketch**: keep accumulating chapters in dormant mode through
  Phase 4 closure, then archive at Phase 5 entry.
- **Why rejected**: deferring the archive while the cadence is
  effectively dormant accumulates more debt without offsetting
  benefit. The trigger is "design transition completed", which
  Phase 4 critical-path close has already crossed.

### Alternative C — Archive only `learn_clojurewasm`, keep `learn_zig` live

- **Sketch**: `learn_zig` is positioned as ROADMAP-independent, so
  it could continue.
- **Why rejected**: the Phase-4 Zig material list above (vtable
  with `*const anyopaque`, comptime build_options branching,
  `std.atomic.Mutex`, packed struct gc_and_lock, ADR-0023 comptime
  stub patterns) is substantial and would force `learn_zig` to
  either grow uneven (Phase-1-3 chapters + Phase-4 chapters with
  different editorial conventions) or stay stale. Archiving and
  regenerating both keeps the editorial convention coherent.

## Consequences

- **Positive**: chapter cadence stops accumulating debt during
  dormancy. The eventual regenerated set covers the post-VM design
  coherently. Both reader sets archive at the same boundary.
- **Negative**: tasks 4.8-4.24 have no per-task notes and the
  regeneration will lean on `git log` + ADRs + source for those.
  Mitigated by the ADR + commit-message density (each Phase-4
  commit has a multi-paragraph rationale; ADR-0006 a1 / ADR-0012 a1
  cover the load-bearing decisions).
- **Neutral / follow-ups**: when the resumption ADR fires, it
  references this ADR and lays out the new chapter scope.

## Affected files

- `docs/ja/learn_clojurewasm/0001-0020 + README.md` → archive
- `docs/ja/learn_zig/README.md` → archive
- `.claude/skills/code_learning_doc/SKILL.md` (dormancy marker)
- `scripts/check_learning_doc.sh` (no-op while dormant)
- `CLAUDE.md` (skill reference annotated with dormancy)
- `.dev/handover.md` (cleanup wave status)

## References

- `code_learning_doc/SKILL.md` L177-197 — the policy this ADR
  invokes
- `private/notes/4.6.md` / `4.7a.md` / `4.7b.md` / `4.7c.md` — the
  surviving per-task notes that survive into regeneration
- ADR-0006 amendment 1 + ADR-0012 amendment 1 (commit bbae2e0) —
  example of the in-loop ADR amendment that the regenerated
  chapters will need to cover

## Revision history

- 2026-05-23: Status: Proposed → Accepted (autonomous-loop
  self-accept per CLAUDE.md § "ADR-level designs are handled
  inline").
