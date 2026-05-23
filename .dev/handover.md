# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 3 files to read (cold-start order)

1. `.dev/handover.md` (this file)
2. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9, take the
   first `[ ]` row in §9.<N>.
3. The most recent `docs/ja/learn_clojurewasm/NNNN_*.md` chapter —
   to recover the conceptual baseline for the active phase.

## Current state

- **Phase**: Phase 4 IN-PROGRESS. §9.6 cluster A done
  (tasks 4.1 / 4.2 / 4.3); **critical-path closed**: 4.0 / 4.0a /
  4.4 / 4.5 / 4.6 / 4.7 / 4.8 / 4.9 / 4.10 / 4.11 / 4.12 done.
  Remaining §9.6 rows (4.13–4.26.f) form the post-VM cleanup
  wave (io abstraction, debt operationalisation, compat_tiers
  expansion, Wasm FFI removal, type_descriptor / protocol /
  object_header / host extension / deftype-raise / binding_stack /
  big_int / lazy_seq / method_table skeletons, error-system
  migration).
- **Branch**: `cw-from-scratch` (long-lived; v0.5.0-derived;
  push free after gate green; never push to `main`).
- **Last commit**: see `git log -1` (compute on resume — the
  resume procedure reads it directly).
- **Gate**: Mac (9/9) + OrbStack Ubuntu x86_64 (8/8) green at
  HEAD. 🔒 fresh OrbStack run due at Phase 4 close.
- **Last paired chapter commit**: `cc46a48` (chapter 0020 —
  Phase 3 closure, covers §9.5 / 3.8–3.14).
- **Unpaired source SHAs**: `git log cc46a48..HEAD --oneline -- src/`
  (compute on resume; chapter pairing decision is per the
  `code_learning_doc` skill's two-cadence rule).

## Active task — §9.6 / 4.13

`src/runtime/io_interface.zig` (new) — Zone 0 vtable abstraction
for `Reader` / `Writer` / `Net` / `Process` (per ADR-0015).
Concrete `io_default.zig` (Zone 1) wires it to current `std.Io`.
Insulates the runtime from Zig stdlib reshape.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.13 + dependency-graph at §9.6.x.
- ADR-0015 (io abstraction). Pattern mirror: ADR-0011 host
  extension dispatch (4.20 ships its sibling skeleton).
- Existing zone-0 vtable: `src/runtime/dispatch.zig::VTable` —
  the new io vtable should follow the same `?fn-ptr` shape with
  default no-op fallbacks where applicable.

## Open questions / blockers

None. External blockers, recall triggers, and follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-026`). The resume Step 0.5 debt sweep walks them.
