# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (Phase 6.9 cycle 1 just landed; HEAD line
  refreshes only on Active-task-identifier change per the
  ≤ 2 / session cap).
- **First commit on resume MUST be**: §9.8 row 6.11 =
  `lang/clj/clojure/walk.clj` (Tier A, ~10 vars). Spawn Step-0
  survey subagent to map `clojure.walk` against JVM upstream +
  cw v0 + check which `clojure.walk` vars need higher-order
  primitives like `map` / `keys` / `vals` (those may force
  new primitive registration vs DIVERGENCE D1 Zig-direct
  pattern). Phase 6.10 cycles 3+ (Group C relational ops)
  remain deferred per D-061.
- **Forbidden this session**: (a) re-opening `core.zig` /
  `math.zig` primitive cluster (6.16 still closed). (b) handover
  HEAD-pointer churn — refresh only when Active-task-identifier
  changes. (c) acting on the **original** (pre-2026-05-25-amendment)
  D-054 plan that referenced a non-existent JVM upstream
  `regex.clj` — read the amended D-054 + deep-dive note first.
  (d) Implementing Unicode case-folding inline in cycle 2 — D-057
  tracks it for Phase 11 conformance; cycle 2 stays ASCII-fold.

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell + Devil's-advocate mandate)
→ `.dev/structure_plan.md` → `.dev/ROADMAP.md` §9.8.

## Current state

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 10/16 `[x]` plus
  6.10 `[~] (cycles 1-2 done, 7/12 vars)` (6.1, 6.5.b,
  6.11-6.15 remain). 6.9 closed across 4 cycles (22 vars in
  `clojure.string`). 6.10 cycle 1 = Group A + `hash-set` +
  `printSet`. 6.10 cycle 2 = Group B (`rename-keys` /
  `map-invert`) + `hash-map` + `printMap`. Group C (5 vars)
  deferred to D-061 (set-literal reader + map-literal
  analyzer).
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file
  loader + in-ns). Symbol-Value-Form unsupported at runtime
  (Group A slot 1 reserved per F-004) → `(in-ns)` lands as
  analyzer special form, not primitive fn — analyzer flattens
  bare `(in-ns sym)` and quoted `(in-ns 'sym)` to InNsNode.
- **Gate**: Mac 24/24 + OrbStack Ubuntu x86_64 23/23 green.
  Layer-2 e2e: 4 × clojure_string + 2 × clojure_set
  (16+9 cases).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.8 row 6.11 (clojure.walk)

`lang/clj/clojure/walk.clj` (Tier A, ~10 vars). Step-0 survey
subagent to map `clojure.walk` against JVM upstream + cw v0 +
identify which higher-order primitives (`map`, `keys`, `vals`,
`reduce`, anonymous-fn dispatch) are required. `walk` itself
is a higher-order traversal that takes user fns — calling
Clojure fns from Zig already works via `rt.vtable.callFn`
(escape primitive's pattern from Phase 6.9 cycle 3).

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md (D-005, D-014a/b, D-017, D-040, D-043, D-048..D-052,
D-054, D-056..D-060, **D-061 new** clojure.set relational ops
deferred until set-literal reader + map-literal analyzer).

## Guardrail refresh history (condensed)

Waves 1-12: spirit + Bad Smell + F-NNN + stop-list + ADR-0029
F-009 + ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted
(Alt 2) + 6.16 cluster (48 fns) + silent-test-skip surgery +
clock API port (D-053). **Wave 13 (2026-05-25)**:
ADR-0032 multi-file bootstrap loader + `(in-ns)` analyzer
special form + Devil's-advocate fork (Alt 1 smallest-diff /
Alt 2 finished-form / Alt 3 wildcard); cycle 1 e2e green;
D-057 + D-058 minted.
