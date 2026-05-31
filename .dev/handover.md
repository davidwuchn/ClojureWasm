# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `a9f35018` (`cw-from-scratch`; see `git log` for drift). Tree clean,
  **0 unpushed**. Mac gate green (180).
- **First commit on resume MUST be**: **drain the quality-loop floor**,
  highest-value-first, per CLAUDE.md Step 0.5 "Quality-loop floor drain"
  (read all `quality-loop floor:` debt rows; backlog = 13). Start with
  **D-168 — `(range n)`/`(range a b)` return an EAGER VECTOR, not a seq**
  (`(seq? (range 3))`→cljw false / clj true; `(conj (range 3) 99)` diverges
  append-vs-prepend). Fix = align the 1/2-arg arms with cljw's already-correct
  3-arg lazy-seq `range` (a `(seq …)` wrap = CONSISTENCY, not ad-hoc); chunked
  LongRange is the F-004 finished form. clj-grounded. Then D-169/170 (quot/int
  on the tower), D-171 (json float → pub `printFloat`), D-172 (Math *Exact),
  D-174 (rest char-seq); D-173 low. Index: `.dev/tech_debt_consolidation.md`.
- **Operating mode** = clj differential sweep (F-011): probe a category through
  BOTH `clj` and `cljw`, diff, fix every divergence at the finished form;
  commonise rather than per-op patch. Deep/unresolvable → master ledger entry +
  `.dev/debt.md` D-NNN. Fully autonomous; loop self-selects per F-002 (may
  weigh the higher-value structural items in Open debts over bit-method
  coverage).
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

java.lang scalar-class **static cluster COMPLETE** (cluster A26, cycles A-G,
`678b78ba..b132baf6`): Integer / Long / Double / Character / Boolean static
methods + fields, Math PI/E/floorDiv/floorMod. Integer/Long bit statics
(`7f1c8342`) + **D-166 float printer** (`4af003c6`: JVM `Double.toString`
scientific notation, single `printFloat` via F-011 fold) both DONE.
Then a user-directed **tech-debt consolidation テコ入れ** landed
(`b76e9574`/`9c951756`/`a9f35018`): 5-lens audit → standing
**`quality-loop floor:` Barrier** mechanism + **CLAUDE.md Step 0.5 drain
step** + `check_debt_id_refs.sh` guardrail (now in the gate) + 8 floor rows
(D-168–175) + Phase-7.x re-anchor. Invariants: **F-011** + **F-010**
(the floor IS the F-010 quality loop's drain queue).

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

User instruction (2026-05-31): directed a tech-debt consolidation テコ入れ
(aggregate every silently-dropped "should-do", wire it into the debt /
dependency trigger system so autonomous dev resolves it), then "(a)(b) を
やったあと、クリアなセッションから continue 継続できるか配線・参照チェーンを
チェック修正してから、このセッションはクリアします". Done: (a) D-NNN guardrail
wired into the gate, (b) Phase-7.x stranded rows re-anchored; reference chain
verified; HEAD `a9f35018`, gate green 180, all pushed, tree clean. Resume per
the Resume-contract First-commit line — drain the quality-loop floor starting
at D-168. Extended-challenge 3 items live in
`private/notes/phaseA26-tech-debt-consolidation.md`.
