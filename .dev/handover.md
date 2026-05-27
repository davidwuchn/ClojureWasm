# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (Phase 12 partial-close commits —
  rows 12.0..12.5).
- **First commit on resume MUST be**: §9.15 Phase 13 task list
  open commit. Run the Phase 12 → 13 boundary review chain
  (`audit_scaffolding` + simplify-on-Phase-12-diff +
  security-review-on-unpushed — parallel fan-out), then expand
  the §9.15 Phase 13 placeholder inline (mirror §9.14 structure)
  and commit alone with
  `git commit -m "roadmap: open Phase 13 task list"`.
- **Forbidden this session**: re-opening Phase 12 D-100 sub-
  deliverables (cljw build CLI / render-error decoder / cold-
  start bench) inside Phase 13 — Phase 13 is STM (`Ref` / `TVal`
  data structures) + VM optimisation peephole.zig + 5-bench
  parity per cw v0 24C.10. Phase 12 D-100 cycles ride dedicated
  future sessions, not Phase 13.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.15 placeholder →
`.dev/debt.md` Step 0.5 sweep (D-045 HAMT; D-080 `=` over
non-numbers; D-096 println output reach; D-097 second-wave
host stdlib; D-098 ns directive surface; D-099 user defmacro;
**D-100** Phase 12 substantive deliverables (a)..(e)).

## Current state

Phase 12 **DONE-PARTIAL** — §9.14 rows 12.0..12.5 all [x] but
rows 12.3 + 12.4 + 12.5 are enumeration-only closes deferring
to D-100 sub-deliverables. Phase 12 master-table deliverable
"cold start < 12 ms" is NOT yet verified — D-100 (d) schedules
the bench. Phase 13 is the next PENDING phase per the §9 master
table (STM + VM optimisation). Branch `cw-from-scratch`. Gate
green: Mac 75/75 + OrbStack Ubuntu x86_64 74/74. Highlights of
Phase 12:

- ADR-0034 rediscovered already-Accepted at 2026-05-25 (row 12.1)
- Bytecode serializer skeleton at `src/eval/bytecode/serialize.zig`
  with magic + version header + Instruction round-trip; 5 unit
  tests (row 12.2)
- D-100 minted for the remaining (a)..(e) Phase 12 substantive
  cycles

## Active task — §9.15 Phase 13 entry

Phase 13 placeholder per §9 master table: "VM optimisation:
peephole.zig + STM Ref/TVal data structures + five canonical
benchmarks within 110% of cw v0 24C.10". Entry ADRs: 0010 (STM
— Ref / TVal data structures). Phase 13 entry owner expands
inline.

## Extended challenge (per `.claude/rules/extended_challenge.md`)

Not applicable — the loop is rolling Phase 12 → Phase 13
boundary with no user-requested stop in flight.

## Guardrail refresh history

Phase 12 landmarks (closed 2026-05-27, partial): ADR-0034
rediscovery + bytecode serializer skeleton (eval/bytecode/) +
D-100 minted (Phase 12 substantive deliverables (a)..(e)).
