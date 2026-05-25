# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (v5 plan + wiring landed; HEAD line refreshes
  only on Active-task-identifier change).
- **First commit on resume MUST be**: open **Phase 6.16.a-2** cycle —
  collection ops (conj / disj / contains? / get / nth / assoc /
  dissoc / keys / vals) per ADR-0033 D6 + ROADMAP §9.8 row 6.16.a-2
  + v5 §5.2. Step 0 survey required (general-purpose subagent,
  output `private/notes/phase6-6.16.a-2-survey.md`). Pattern: Layer
  2 Tag switch wrapping existing Layer 0 collection helpers (vector.
  conj / set.contains / map.get etc), same shape as sequence.zig
  (d35dc3b). e2e deliverable: `test/e2e/composition_unlock_a2.sh`.
  After this cycle: Phase 6.16.a-3 (higher-order + transducer 先取り,
  2-3 cycles range). ADR-0033 (2bf491b) + ADR-0034 (2834511) +
  Phase 6.16.a-0 (b5d44f7) + Phase 6.16.a-1 (d35dc3b) all landed.
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

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 12/24 `[x]` + 6.10 `[~]
  (7/12)` + 6.11 `[~] (3/10)`. v5 plan + ADR-0033 (2bf491b) + ADR-0034
  (2834511) + ROADMAP §9.8 rows 6.16.a-0..e + §9.14/16/18/19 v5
  expansions + debt rows D-062..D-069 (757a0b5) + Phase 6.16.a-0
  env.intern metadata (b5d44f7、 D-065 解消) + Phase 6.16.a-1
  sequence.zig 6 primitives (d35dc3b). **Active task = Phase 6.16.a-2
  cycle** (collection ops).
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file loader +
  in-ns). v5 plan = `private/notes/clj_vs_zig_split_proposal_v5.md`
  (1593 lines, self-contained, SSOT for ADR-0033/0034/0035).
- **Gate**: Mac 26/26 + OrbStack Ubuntu x86_64 24/24 green at b5d44f7
  (Phase 6.16.a-0 e2e `phase6_16_a_0_metadata.sh` registered).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 6.16.a-2 (collection ops)

Open Phase 6.16.a-2 cycle: conj / disj / contains? / get / nth /
assoc / dissoc / keys / vals as Layer 2 polymorphic Tag switch
wrapping existing Layer 0 collection helpers. Per ADR-0033 D6 +
ROADMAP §9.8 row 6.16.a-2 + v5 §5.2. Same shape as sequence.zig
(d35dc3b). e2e: `composition_unlock_a2.sh`. Step 0 survey via
general-purpose subagent first.

After this: Phase 6.16.a-3 (higher-order + transducer 先取り,
2-3 cycles range).

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md including new rows D-062..D-069 (v5 §21.1). D-062 cluster
recall trigger anchored to placement.yaml — initial scaffold landed
at `placement.yaml`, populated incrementally as cycles close.

## Guardrail refresh history (condensed)

Waves 1-12: spirit + Bad Smell + F-NNN + stop-list + ADR-0029 F-009
+ ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted (Alt 2) + 6.16
cluster + silent-test-skip surgery + clock API port. **Wave 13
(2026-05-25)**: ADR-0032 multi-file bootstrap loader + `(in-ns)`
analyzer special form. **Wave 14 (2026-05-25)**: v5 placement/build/
error plan landed (`private/notes/clj_vs_zig_split_proposal_v5.md`)
+ ROADMAP §9.8 cycle rows 6.16.a-0..e + ROADMAP §9.14/16/18/19
deliverable extensions + debt.md D-062..D-069 + placement.yaml stub
+ ADR-0033/0034/0035 起票計画 (ADR-0033 immediate, 0034/0035 cycle-
terminus deferred).
