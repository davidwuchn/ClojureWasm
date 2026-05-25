# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (v5 plan + wiring landed; HEAD line refreshes
  only on Active-task-identifier change).
- **First commit on resume MUST be**: open **Phase 6.16.a-3** cycle —
  higher-order + transducer 先取り (apply / reduce 素朴版 / into /
  map / filter / take / drop / keep / remove / every? / some / some?
  + Layer 3 `.clj` defn partial / comp / complement / constantly /
  juxt) per ADR-0033 D6 + D6a + ROADMAP §9.8 row 6.16.a-3 + v5 §5.2
  + §7 transducer 先取り spec. **2-3 cycles range** — apply の lazy
  seq 連携が cw v0 evidence で ~100 LOC + threadlocal の規模、 cw v1
  では Phase 6.16.a-3 段階で 50 LOC 素朴版 start (lazy seq 連携は
  Phase 7)、 詳細 scope は cycle 着手時の survey で再見積もり可能。
  transducer arity (1-arg = xform) + multi-arity (eager + multi-coll)
  両方着地、 rf protocol を Layer 2 で正式登録 (v5 §7.2)。 Step 0
  survey via general-purpose subagent first (output
  `private/notes/phase6-6.16.a-3-survey.md`). e2e: `transducer_unlock_a3.sh`.
  After cycle close: Phase 6.16.b (clojure.set 12 vars `.clj` 化).
  Prior landings: ADR-0033 (2bf491b) + ADR-0034 (2834511) + Phase
  6.16.a-0 (b5d44f7) + 6.16.a-1 (d35dc3b) + 6.16.a-2 (a4bfca5).
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

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 13/24 `[x]` + 6.10 `[~]
  (7/12)` + 6.11 `[~] (3/10)`. v5 plan + ADR-0033 (2bf491b) + ADR-0034
  (2834511) + ROADMAP §9.8 rows 6.16.a-0..e + §9.14/16/18/19 v5
  expansions + debt rows D-062..D-069 (757a0b5) + Phase 6.16.a-0
  env.intern metadata (b5d44f7) + Phase 6.16.a-1 sequence.zig 6
  primitives (d35dc3b) + Phase 6.16.a-2 collection.zig 9 primitives
  (a4bfca5). **Active task = Phase 6.16.a-3 cycle** (higher-order +
  transducer, 2-3 cycles range).
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file loader +
  in-ns). v5 plan = `private/notes/clj_vs_zig_split_proposal_v5.md`
  (1593 lines, self-contained, SSOT for ADR-0033/0034/0035).
- **Gate**: Mac 28/28 + OrbStack Ubuntu x86_64 27/27 green at a4bfca5
  (6.16.a-1 `composition_unlock_a1.sh` + 6.16.a-2
  `composition_unlock_a2.sh` registered).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 6.16.a-3 (higher-order + transducer 先取り)

Open Phase 6.16.a-3 cycle (2-3 cycles range): 12 Layer 2 primitives
(apply / reduce 素朴版 / into / map / filter / take / drop / keep /
remove / every? / some / some?) + 5 Layer 3 `.clj` defn (partial /
comp / complement / constantly / juxt) + rf protocol formal
registration. transducer arity 先取り per v5 §7. Step 0 survey via
general-purpose subagent first.

After cycle close: Phase 6.16.b (clojure.set 12 vars `.clj` 化、
Group A+B+C 一括 per ROADMAP §9.8 row 6.16.b).

DIVERGENCE D1 v5 §5.2 amendment also queued (contains? wording
correction) — fold into Phase 6.16.a-3 survey or first commit body.

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
