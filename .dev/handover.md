# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Resume contract

- **HEAD**: see `git log` (Phase 6.9 cycle 1 just landed; HEAD line
  refreshes only on Active-task-identifier change per the
  ≤ 2 / session cap).
- **First commit on resume MUST be**: Phase 6.9 cycle 3 =
  indexing + simple replace + escape + reverse (6 vars:
  `index-of` / `last-index-of` / `replace` string-only /
  `replace-first` string-only / `escape` / `reverse`) per
  `private/notes/phase6-6.9-survey.md` §6 cycle 3. `replace`
  regex form raises `feature_not_supported` per DIVERGENCE D3
  (regex captures land at D-051 cycle 3). `reverse` needs new
  `charset.zig::reverseCodepoints` helper. `escape` needs char
  iteration + per-char Clojure-fn callout (the first cycle-3 var
  that requires invoking a Clojure fn from Zig — check how
  `dispatch.callFnVal` exposes that).
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

- **Phase**: **Phase 6 IN-PROGRESS** — §9.8 9/16 `[x]` + 6.9
  `[~] (cycles 1-2 done)` (6.1, 6.5.b, 6.10-6.15 remain). 6.9
  cycle 1 = multi-file bootstrap + `(in-ns)` + `upper-case` /
  `lower-case` / `blank?`. Cycle 2 = trim + predicate families
  (7 vars). Cycles 3-4 land remaining ~11 vars per
  `private/notes/phase6-6.9-survey.md` §6.
- **Branch**: `cw-from-scratch`. ADR-0032 issued (multi-file
  loader + in-ns). Symbol-Value-Form unsupported at runtime
  (Group A slot 1 reserved per F-004) → `(in-ns)` lands as
  analyzer special form, not primitive fn — analyzer flattens
  bare `(in-ns sym)` and quoted `(in-ns 'sym)` to InNsNode.
- **Gate**: Mac 20/20 + OrbStack Ubuntu x86_64 19/19 green.
  Two Layer-2 e2e: `phase6_clojure_string_cycle1` (9 cases) +
  `phase6_clojure_string_cycle2` (16 cases incl Unicode
  ideographic trim + UTF-8 substring includes?).
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — Phase 6.9 cycle 3

Land `clojure.string` indexing + simple replace + escape +
reverse (6 vars). `replace` regex form raises
`feature_not_supported` (D-051 cycle 3 dependency); `escape`
introduces the first Clojure-fn callout from a clojure.string
primitive — verify the dispatch surface before sinking time.

## Open questions / blockers

None testable from inside the loop. Step 0.5 debt sweep walks
debt.md (D-005, D-014a/b, D-017, D-040, D-043, D-048..D-052,
D-054, D-056, **D-057 new** Unicode case-fold, **D-058 new**
bootstrap renderer SourceContext per-file thread).

## Guardrail refresh history (condensed)

Waves 1-12: spirit + Bad Smell + F-NNN + stop-list + ADR-0029
F-009 + ADR-0030 + 6.1 analyzer split + ADR-0031 Accepted
(Alt 2) + 6.16 cluster (48 fns) + silent-test-skip surgery +
clock API port (D-053). **Wave 13 (2026-05-25)**:
ADR-0032 multi-file bootstrap loader + `(in-ns)` analyzer
special form + Devil's-advocate fork (Alt 1 smallest-diff /
Alt 2 finished-form / Alt 3 wildcard); cycle 1 e2e green;
D-057 + D-058 minted.
