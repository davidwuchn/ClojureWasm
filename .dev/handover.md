# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (v5 plan + wiring landed; HEAD line refreshes
  only on Active-task-identifier change).
- **First commit on resume MUST be**: open **Phase 6.16.b-2** cycle —
  D-061 (`#{...}` reader literal `.set` Form variant + tokenizer
  `set_open` + readSet) + D-059 (map-literal-as-Value analyzer
  `analyzeMapLiteral` + `analyzeSetLiteral` mirror of
  `analyzeVectorLiteral` at `src/eval/analyzer/analyzer.zig`
  L500-517) + TreeWalk eval + VM compile/opcode + tests. Ruler:
  D-060 `op_vector_literal` landed at 1d20ce3 (~60 LOC analyzer +
  Node + tree_walk + VM compile + opcode). Total LOC budget ~230
  per `private/notes/phase6-6.16.b-survey.md` §4. e2e: new
  `test/e2e/phase6_set_map_literal.sh`. After 6.16.b-2:
  Phase 6.16.b-3 (Group C select/project/index/rename/join `.clj`
  defns sitting on this infra). 6.16.b-1 landed at ddb7203
  (Group A+B `.clj` defns + evalInNs rt/ auto-refer; D-070 finding
  recorded — variadic + internal arity discrimination sidesteps
  D-070 for union/intersection/difference; multi-arity dispatch
  remains needed only for "different body per arity" cases).
- **Forbidden this session**: (a) `__zig-` namespace prefix path (v5
  §3.1 rejected; `defn-` + `-name` + `^:private :zig-leaf` metadata is
  the confirmed scheme). (b) `clojure.X.impl/` sub-ns path (v5 §3 rejected
  for取り残しリスク + 分散コスト). (c) `cljw build --source` / `--debug`
  / `--aot` flag path (v5 §11.1 confirmed single mode, flag ゼロ). (d)
  mixing human + EDN in single stderr stream (v5 §13.1 confirmed
  stream-separated TTY=human / pipe=structured EDN). (e) ABI-level
  bytecode format commitment (v5 §12.4 confirmed self-contained binary,
  decoder-only永久互換性).

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` (Bad Smell + Devil's-advocate mandate) →
**`private/notes/clj_vs_zig_split_proposal_v5.md` (placement +
build + error 確定計画 SSOT)** →
`.dev/structure_plan.md` → `.dev/ROADMAP.md` §9.8.

## Current state

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 14/24 `[x]` + 6.10 `[~]`
  + 6.11 `[~] (3/10)` + 6.16.b-1 landed (Group A+B `.clj` defn
  migration). v5 plan + ADR-0033/0034 + 6.16.a-0..a-3.2 + 6.16.b-1
  (ddb7203). **Active task = Phase 6.16.b-2 cycle** (D-061 +
  D-059 reader/analyzer infra).
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file loader +
  in-ns). v5 plan = `private/notes/clj_vs_zig_split_proposal_v5.md`
  (1593 lines, self-contained, SSOT for ADR-0033/0034/0035).
- **Gate**: Mac 31/31 + OrbStack Ubuntu x86_64 30/30 green at
  ddb7203 (phase6_clojure_set_group_ab.sh registered).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 6.16.b-2 (D-061 + D-059 reader/analyzer infra)

Open Phase 6.16.b-2: `#{...}` reader literal + `{...}` map-literal-
as-Value analyzer. Files to touch: `src/eval/form.zig` (`.set`
FormData variant), `src/eval/tokenizer.zig` (`set_open` kind +
readDispatch `'{'` arm), `src/eval/reader.zig` (`readSet` mirror of
`readMap`), `src/eval/node.zig` (`SetLiteralNode` + `MapLiteralNode`),
`src/eval/analyzer/analyzer.zig` (`analyzeSetLiteral` +
`analyzeMapLiteral` mirror of `analyzeVectorLiteral` L500-517),
`src/eval/backend/tree_walk.zig` (`evalSetLiteral` + `evalMapLiteral`),
`src/eval/backend/vm/compiler.zig` (`compileSetLiteral` +
`compileMapLiteral`), `src/eval/backend/vm/opcode.zig`
(`op_set_literal` + `op_map_literal`), `src/eval/backend/vm.zig`
(dispatch). Ruler: D-060 `op_vector_literal` (1d20ce3). e2e:
`test/e2e/phase6_set_map_literal.sh`. Closes D-061 + D-059. After:
6.16.b-3 (Group C `.clj` defns + retire old phase6_clojure_set_cycle*).

v5 follow-up amendments accumulating (fold into ADR-0033 amendment
or next-cycle commit body):
- §5.2 DIVERGENCE D1 wording (contains? on vector, 6.16.a-2)
- §5.2 every?/some explicit Layer 2 designation (6.16.a-3.1)
- §5.2 + §7 transducer arity cw v1 deviation + D-070 trigger spec (6.16.a-3.2)
- ADR-0033 D6a amendment (partial 着地、 D-070 後 back-fill plan)
- 6.16.b-1 evalInNs rt/ auto-refer (ADR-0032 amendment 候補、 ADR-0035
  で `(ns ...)` macro が landing する時に正式置換予定)

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md including new rows D-062..D-069 (v5 §21.1). D-062 cluster
recall trigger anchored to placement.yaml — initial scaffold landed
at `placement.yaml`, populated incrementally as cycles close.

## Guardrail refresh history (condensed)

Waves 1-12: spirit + Bad Smell + F-NNN + stop-list + ADR-0029 F-009
+ ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted (Alt 2) + 6.16
cluster + silent-test-skip surgery + clock API port. **Wave 13-14
(2026-05-25)**: ADR-0032 (in-ns) + v5 placement/build/error plan
SSOT + ROADMAP §9.8 cycle rows 6.16.a-0..e + debt.md D-062..D-073
+ ADR-0033/0034 issued / 0035 deferred to 6.16.b-4.
