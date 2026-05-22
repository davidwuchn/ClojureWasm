# Debt ledger

> Row-level debt tracking. Each row carries a present-tense, testable
> predicate as Barrier. Phase boundary audit verifies per-row, not
> aggregate count (ROADMAP §A13).
>
> Status enum: `now` / `blocked-by: <event>` / `Phase N target` /
> `Discharged (commit SHA)`.
> Last reviewed: refreshed at every continue/SKILL.md Step 0.5 debt
> sweep.

## Active

| ID    | Status              | Category    | Description                                                                                                          | Barrier                            | Last reviewed |
|-------|---------------------|-------------|----------------------------------------------------------------------------------------------------------------------|------------------------------------|---------------|
| D-001 | now                 | refactor    | analyzer expandAnd / expandOr non-recursive rewrite                                                                  | (none — task 4.3)                 | 2026-05-23    |
| D-002 | now                 | security    | uniform errdefer across string / ex_info / list / fn alloc paths                                                     | (none — task 4.2)                 | 2026-05-23    |
| D-003 | now                 | security    | analyzeLoopStar / analyzeRecur u16 bound-check                                                                       | (none — task 4.1)                 | 2026-05-23    |
| D-004 | now                 | perf        | bench/quick.sh expansion + history.yaml                                                                              | (none — task 4.0)                 | 2026-05-23    |
| D-005 | Phase 17 target     | perf        | ARM64 JIT decision (go / no-go)                                                                                      | Phase 17 bench σ < 5%             | 2026-05-23    |
| D-006 | Phase 16 target     | scope       | Wasm FFI re-introduction via Pod boundary                                                                            | zwasm v2 stable + ADR-0006 review  | 2026-05-23    |
| D-007 | Phase 8 target      | scope       | Self-host bootstrap viability check                                                                                  | ADR for self-host trigger          | 2026-05-23    |
| D-008 | Phase 5 target      | perf        | collections.zig split avoidance                                                                                      | ADR-0016 landed                    | 2026-05-23    |
| D-009 | Phase 15 target     | concurrency | STM (ref / dosync) MVCC implementation                                                                               | ADR-0010 implementation phase      | 2026-05-23    |
| D-010 | Phase 15 target     | concurrency | Object header heap-only lock activation                                                                              | ADR-0009 implementation phase      | 2026-05-23    |
| D-011 | Phase 5 target      | runtime     | mark-sweep GC heap implementation                                                                                    | ADR-0017 implementation phase      | 2026-05-23    |
| D-012 | Phase 15 target     | concurrency | atom + watch implementation                                                                                          | std.atomic.Value wiring            | 2026-05-23    |
| D-013 | Phase 15.3 target   | concurrency | STM barge mechanism (priority-based contention)                                                                      | ADR-0010 §barge subsection landed | 2026-05-23    |
| D-014 | Phase 5-7 follow-up | scope       | D10 / D11 / D12 / D13 deferral propagation (numeric tower BigDecimal Tier B, exception :type, multimethod, protocol) | Phase 4 entry exit + Phase 5 entry | 2026-05-23    |
| D-015 | open question       | concurrency | virtual threads (M:N coroutine) evaluation                                                                           | Phase 14 re-evaluation             | 2026-05-23    |
| D-016 | open question       | runtime     | generational GC evaluation                                                                                           | Phase 5 mark-sweep bench results   | 2026-05-23    |

## Discharged

(empty — populate as debts are closed with commit SHA)

## Conventions

- New debt: grep `.dev/debt.md` for class-overlap before adding (per `.claude/rules/debt_dedup.md`).
- Status `blocked-by:` barrier text must be a present-tense, testable predicate. NO vague hopes.
- Last reviewed must be updated when re-evaluating; stale (>14 days) entries trigger narrow audit.
- Debt entries reference ADRs by short ID (e.g., `ADR-0010`) without filesystem paths.
- Open questions tracked here when they are concrete enough to be a barrier; otherwise they live in `.dev/handover.md` under "Open questions / deferred".
