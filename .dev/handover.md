# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (perf-campaign commits on `cw-from-scratch`).
  Tree clean, 0 unpushed. Mac gate green (180).
- **First on resume MUST be**: **ROADMAP §9.2.S Performance tuning campaign**
  (user-directed pull-forward, ADR-0063, ROI-ordered, PERF-marked →
  `.dev/optimizations.md` SSOT). Start at **D-180 — bulk `persistent!` /
  `vector.fromSlice`**: `transient_vector.toPersistent` rebuilds via N
  persistent conjs (O(n log n)) → `(vec (range 1e6))` = 121s; build the HAMT
  from the flat buffer in O(n), then re-land the reverted O-003 transient
  `into`/`vec` pair (they land together). **Core Vector → exhaustive boundary
  tests** (n∈{0,1,31,32,33,63,64,65,1023,1024,1025,1e5}: build → nth-all +
  count + `=` vs conj-built). Then D-163 fusion (own ADR), D-140 startup.
  DONE: O-001 range `72d7bfcc`, O-002 reduce-vector `0898ba2c`.
- **Then** quality-loop floor (D-169/170 quot/int on tower, D-171 json float,
  D-172 Math *Exact, D-174 rest char-seq; D-173 low) — D-168 DONE.
- **Operating mode** = clj differential sweep (F-011) + perf campaign (§9.2.S):
  probe via BOTH `clj`+`cljw`, fix at the finished form, commonise; perf =
  measure before/after + `// PERF:` marker + optimizations.md row per win.
  Autonomous; loop self-selects per F-002 / ROI.
- **Forbidden**: re-opening anything landed (git log = SSOT). JIT/superinstruction
  (perf deferred, D-163). Touching `tree_walk.zig`/`vm.zig` for statics/fields
  (they resolve to `.constant` Node / shared builtins — backend-agnostic; the
  diff oracle verifies parity).

## Process discipline (load incident 2026-05-31 — full detail in memory + rules)

- **Never poll a background gate** (`sleep N; cmd` is harness-blocked): launch
  `run_in_background`, yield, act on the completion notification, read once.
- **`clj -M -e` MUST be `timeout 20`-wrapped** (infinite-seq orphan → ~160% CPU).
- **Never pass `\a`-style char literals through `cljw -e`** (shell eats `\`); use
  `(char N)`.
- **Under load, capture probe output to `/tmp/*.txt` and Read it**; bare reads can
  be garbled. One Claude session per repo — 2026-05-31 confirmed only this
  session on cljw (others were zwasm/myskill).
- **Defender exclusions** (`mdatp exclusion`): verify post-reboot via
  `mdatp exclusion list`, re-add any dropped (zig + project `.zig-cache`/`zig-out`
  + `~/.cache/zig`).

## Current state

java.lang scalar-class **static cluster COMPLETE** (A26) + **D-166 float
printer** done. Two user-directed scaffolding passes since: tech-debt
consolidation (`b76e9574`..`a9f35018`: standing **`quality-loop floor:`
Barrier** + **CLAUDE.md Step 0.5 drain** + `check_debt_id_refs.sh` gate
guardrail + 8 floor rows D-168–175), and the **scaffolding diet**
(`7a73d27d`, ADR-0062): 200K-window default, pruned always-on rules,
project-scoped MCP disable, de-duplicated SessionStart/PostCompact hooks.
Invariants: **F-011** + **F-010** (the floor IS the F-010 quality loop's
drain queue).

## Master divergence ledger (compaction-survival)

[`private/notes/phaseA26-clj-differential-oracle.md`](../private/notes/phaseA26-clj-differential-oracle.md)
holds every clj diff (fixed + unresolved + acceptable), the oracle recipe, the
swept categories, the next-sweep candidates (bit methods / Math `*Exact`), and
the remaining Java-interop gap list. **Read it first on resume.** Per-task
notes: `private/notes/phaseA26-*.md`.

## Open debts (full rows in `.dev/debt.md`)

- **Quality-loop floor (drain queue, backlog 13)** — the F-010 loop drains
  these highest-value-first (CLAUDE.md Step 0.5): D-168 range-vector (HIGH),
  D-169/170 quot/int on the tower, D-171 json float, D-172 Math *Exact, D-174
  rest char-seq, D-173 bit tail (low); re-anchored D-086/087/088/090/091
  (deftype/recur/docstring); D-175 = remaining Lens-C re-anchor + M5 housekeeping.
- **D-166 / D-167 / D-161 DISCHARGED**.
- **Structural-deferred (F-003, owner-Phase trigger)**: D-164 empty-seq≡nil
  (front-of-loop once corpus hits it), D-165 i48→i64 long prints `N`, D-163
  perf (F-010 post-M), D-006/036/037/039 zwasm v2.
- **Acceptable divergences**: `(class 5)`→`Long` (ADR-0059); `(float 1/3)` f64;
  set print order; subnormal `5.0E-324` vs JVM `4.9E-324` (same double).

## Cold-start reading order

handover → master ledger (above) → **`.dev/tech_debt_consolidation.md`** (the
quality-loop-floor index + action list) → CLAUDE.md (§ Project spirit +
Autonomous Workflow + **Step 0.5 Quality-loop floor drain** + The only stop) →
`.dev/project_facts.md` (F-011 + F-010) → `.dev/principle.md` (Bad Smell) →
`.dev/reference_clones.md` (clj oracle).

## Stopped — user requested

User instruction (2026-05-31): directed a scaffolding diet — measure the
auto-injected per-turn footprint, cut stale/duplicated/obsolete guards while
keeping load-bearing ones, research compaction best practices, cap the window
(→ 200K); disable this project's unused MCP servers
(datadog/figma/slack/notion/chrome-devtools/playwright) via project override;
then "新クリアセッションから continue で続行できる状態にし、配線・参照チェーンも
監査". Done: ADR-0062 landed (`7a73d27d`); reference chain audited + 4 dangling
refs fixed (this commit); resume contract unchanged. **Post-restart**: 200K
window + MCP disable take effect on reload — verify via `/model` + the MCP tool
list (fallback: `/plugin` menu if project `enabledPlugins:false` is not
honored). Resume per the Resume contract — drain the quality-loop floor at
D-168.
