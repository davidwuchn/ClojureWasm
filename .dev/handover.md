# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (Phase 11 close commits — rows 11.0..11.5).
- **First commit on resume MUST be**: §9.14 Phase 12 task list
  open commit. Run the Phase 11 → 12 boundary review chain
  (`audit_scaffolding` + simplify-on-Phase-11-diff +
  security-review-on-unpushed — parallel fan-out), then expand
  the §9.14 Phase 12 placeholder inline (mirror §9.13 structure)
  and commit alone with
  `git commit -m "roadmap: open Phase 12 task list"`.
- **Forbidden this session**: re-opening D-099 (user defmacro
  / deftest) within Phase 12 — Phase 12 is bytecode cache
  (cljw build single mode + Tier 0 metadata + EDN decode per
  ADR-0034), not clojure.test surface expansion.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.14 placeholder →
`.dev/debt.md` Step 0.5 sweep (D-045 HAMT; D-080 `=` over
non-numbers; D-096 println output reach; D-097 second-wave host
stdlib; D-098 ns directive surface; D-099 user defmacro).

## Current state

Phase 11 **DONE** — §9.13 rows 11.0..11.5 all [x]. Phase 12 is
the next PENDING phase per the §9 master table (bytecode cache
+ cljw build + Tier 0 metadata per ADR-0034). Branch
`cw-from-scratch`. Gate green: Mac 75/75 + OrbStack Ubuntu
x86_64 74/74. Highlights of Phase 11:

- ADR-0046 — Upstream skip taxonomy + Tier A 100% PASS gate
  semantics (row 11.1; numbering corrected from placeholder
  "ADR-0025" collision)
- `clojure.test/is` Zig primitive + `clojure.test/run-tests`
  Pattern A variadic over explicit test fns (row 11.2;
  `deftest` macro deferred per D-099 — needs user defmacro)
- 13 ported tests at `test/clj/cw_ported.clj` covering
  arithmetic / string / vector / map / set / seq /
  clojure.set/.edn / closure / loop-recur (row 11.3)
- Tier A 100% PASS gate wired as `test_clj_tier_a` run_step
  asserting `[13 0]` (row 11.4)
- `build_options.phase_at_least_11 = true` flipped + exit
  smoke green (row 11.5)
- D-097 + D-098 + D-099 all Active for future-cycle pickup

## Active task — §9.14 Phase 12 entry

Phase 12 placeholder per §9 master table: "Bytecode cache
(serialize + cache_gen) — cold start < 12 ms; cache format
versioning established". The existing §9.14 placeholder also
flags **ADR-0034** issuance (cljw build single mode + Tier 0
metadata + structured EDN + post-mortem decode) + D-064 (cljw
render-error post-mortem decoder archive) + D-062 (placement
.yaml transient_zig migration). Phase 12 entry owner expands
inline.

## Extended challenge (per `.claude/rules/extended_challenge.md`)

Not applicable — the loop is rolling Phase 11 → Phase 12
boundary with no user-requested stop in flight.

## Guardrail refresh history

Phase 11 landmarks (closed 2026-05-27): ADR-0046 (skip
taxonomy) + clojure.test/is primitive + 13 ported tests +
Tier A 100% PASS gate active + `phase_at_least_11 = true`
flip + D-099 minted for user defmacro deferral.
