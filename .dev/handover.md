# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (Phase 6.9 cycle 1 just landed; HEAD line
  refreshes only on Active-task-identifier change per the
  ≤ 2 / session cap).
- **First commit on resume MUST be**: address user's
  2026-05-25 question on `.clj` vs Zig implementation split.
  Concrete output expected: an ADR or principle.md amendment
  capturing (a) the decision rule for "should this var go
  in .clj or in Zig?", (b) maintenance / self-hosting cost
  trade-offs, (c) re-evaluation of Phase 6.9-6.11 var
  placements against the rule, (d) the placement rule for
  Phase 6.12+ namespaces (zip / json / edn / spec.alpha
  etc.). Only after that lands → §9.8 row 6.11 cycle 2
  (keywordize-keys / stringify-keys / prewalk-replace /
  postwalk-replace) or row 6.12 (clojure.zip).
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

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 10/16 `[x]` +
  6.10 `[~] (7/12)` + 6.11 `[~] (3/10)` (6.1, 6.5.b, 6.12-6.15
  remain). 6.9 closed (22 vars `clojure.string`). 6.10
  cycles 1-2 = Group A+B (7/12). 6.11 cycle 1 = spine
  (`walk`/`prewalk`/`postwalk`) with rt.vtable.callFn for
  user fn callouts, Zig-direct recursion (no `partial`
  dependency).
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file
  loader + in-ns). Symbol-Value-Form unsupported at runtime
  (Group A slot 1 reserved per F-004) → `(in-ns)` lands as
  analyzer special form, not primitive fn — analyzer flattens
  bare `(in-ns sym)` and quoted `(in-ns 'sym)` to InNsNode.
- **Gate**: Mac 25/25 + OrbStack Ubuntu x86_64 24/24 green.
  Layer-2 e2e: 4 × clojure_string + 2 × clojure_set +
  1 × clojure_walk_cycle1 (9 cases).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — user-raised `.clj`-vs-Zig split decision

User stop directive 2026-05-25: 「.cljで済むものとzigで実装する
ものの切り分けの現時点での実際とあなたの考え」を分析せよ。保守
コスト + セルフホスト的なガイドに関わる、まだ十分に考慮できて
いなかった事項。次セッションは ADR or principle.md amendment
で切り分けの decision rule を確定 → 6.9-6.11 の placement 再評価
→ 6.12+ への適用方針までを射程に置く。

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md (D-005, D-014a/b, D-017, D-040, D-043, D-048..D-052,
D-054, D-056..D-061). 6.11 surfaced no new debt rows
(macroexpand-all + *-demo deferred but tracked in survey for
cycle 3 instead of debt — small enough to land then).

## Stopped — user requested

User instruction (2026-05-25): 「ちなみに、きりのよいところまで
進んでコミット（サイクル終端）したら、止めて、『.cljで済むものと
zigで実装するものの切り分けの現時点での実際とあなたの考え』を
教えてください。保守コストとかセルフホスト的なガイドに関わる、
まだあんまり考慮できていなかった事項とわたしは認識している」
= stop at the next cycle end + commit, then analyse the
`.clj`-vs-Zig implementation split (current actuality + my
opinion), noting maintenance cost + self-hosting implications.
Phase 6.11 cycle 1 (clojure.walk spine) closed end-to-end +
gate green; per-task note at `private/notes/phase6-6.11-cycle1.md`
with extended-challenge 3 items. Analysis follows in chat.
Resume at the user-raised `.clj`-vs-Zig split decision per
the Resume contract above.

## Guardrail refresh history (condensed)

Waves 1-12: spirit + Bad Smell + F-NNN + stop-list + ADR-0029
F-009 + ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted
(Alt 2) + 6.16 cluster (48 fns) + silent-test-skip surgery +
clock API port (D-053). **Wave 13 (2026-05-25)**:
ADR-0032 multi-file bootstrap loader + `(in-ns)` analyzer
special form + Devil's-advocate fork (Alt 1 smallest-diff /
Alt 2 finished-form / Alt 3 wildcard); cycle 1 e2e green;
D-057 + D-058 minted.
