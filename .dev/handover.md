# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). Per-commit = smoke; commit **and** push
  (CLAUDE.md § atomic Step 6 — the perf-campaign no-push mode is LIFTED; push normally).
  `build.zig.zon` `.zwasm` = tag pin `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: **self-select one §9.2.T public-ization
  polish-sweep category and drain it** (**ADR-0166**; Step 0.5 reads the
  `quality_floor: "public-ization: …"` rows **D-522…D-529** and drains
  highest-value-first). This is the standing `/continue` mode now (repeatable,
  like the F-010 quality-loop floor) — the perf campaign is PAUSED (its cheap
  levers are exhausted; see Standing units). The categories: **D-522** comment
  de-pointering + condensation (≈1409 ADR + 1528 D-NNN pointer lines → self-contained
  prose; ADR docs stay; GRADUAL, largest) · **D-523** doc audit vs code-truth (29
  docs; fix/simplify/prune/archive) · **D-524** `private/` decouple + per-task-note
  retire (853 notes; the loop must not depend on a gitignored dev-env dir) · **D-525**
  rules + skills public-ization review (31 rules / 3736 lines auto-load) · **D-526**
  java-interop static-member gap catalog + fill (49 surfaces / 92 fqn) · **D-527**
  clj-parity upstream alignment (folds into D-175) · **D-528** real-`deps.edn`
  famous-library usage (surface bugs) · **D-529** marker-comment inventory (110
  markers). A correctness/clj-parity floor still outranks pure polish. Code-touching
  rows (D-526/527/528) take the diff-oracle gate; the rest are no-behaviour-change.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails);
  bare `zig build` for a probe (ADR-0133 — use ReleaseSafe). Note: `.claude/**` edits
  (D-524/525) may hit the auto-mode self-modification block — surface those to the user.

## Last landed (git log = SSOT)

This session closed the perf campaign's cheap-lever phase + recorded the milestone:
**O-051** keyword-map-get fast path (ADR-0165 Amendment 1; destructure −6.6% /
gc_large_heap −4.5% / 300k-get −11.0%) · **kwarg destructure fix** (clj-1.11
trailing-map kwargs; D-521 records the two-destructure-paths drift audit) ·
**json read-str GC-rooting fix** (D-519 exposed a latent fabrication gap →
json_parse 19000→20000; fabrication-region bracket + alloc-torture regression
guard) · **full cross-lang bench re-run → `bench/README.md`** (2026-06-24;
json_parse now cljw 35.4ms < Python 36.2ms). All diff-oracle + lint green.

## Standing units (tracked in .dev/debt.yaml)

- **Perf campaign (§9.2.S) — PAUSED.** Cheap levers exhausted (O-051 last clean
  one). Remaining in standing debt for a future deliberate decision: **D-520**
  collection-perf (L4 small-map = a GC-arch variable-length-object change, poor ROI
  for 1.05–1.16×) · **D-386** VM dispatch ((a) inline-stepOnce risky/UAF + D-244 #4
  prereq; (b) DEAD; (c) JIT user-fenced ADR-0151) · **D-005/006** broad JIT (future).
  `.dev/.perf_campaign_active` REMOVED (re-`touch` to re-open).
- **D-513** — three linked clj-parity gaps (clojure.core.reducers / clojure.repl /
  var `:doc` metadata) — foundational, not clean drop-ins; a D-527 sweep may reach them.
- **D-511** — only the exact-binary `(BigDecimal. double)` footgun remains (OPEN-LOW).

## North star (ACTIVE, distal)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
The embedded **zwasm** JIT engine (ADR-0200) is the cljw DEFAULT (`.auto`); the
remaining step is **components-through-the-JIT** (zwasm-side, D-500). Distal — needs
a user nod; the public-ization sweep (§9.2.T) is the active near-term mode.

## Reading order (resume)

handover → **ADR-0166** (public-ization polish-sweep mode — the active direction) →
the **D-522…D-529** rows in `.dev/debt.yaml` (the drain menu) → **ROADMAP §9.2.T**.
Background: **ADR-0165** + Amendment 1 (perf levers exhausted) → **D-520** (paused
perf). Bench: `bash bench/compare_langs.sh --skip-build --yaml=bench/cross-lang-latest.yaml`
then `yq -o=json … | python3 bench/gen_cross_table.py` → splice into `bench/README.md`.
Memories: `verify_against_releasesafe_binary` / `smoke_first_batch_full_gate`.

## Stopped — user requested

User instruction (2026-06-24, paraphrase): after this perf milestone, the standing
`/continue` mode is the **(b) sweep** — the finite quality work previously deferred
as low-ROI: java-interop missing statics (catalog first if not mechanically
knowable), "あと少し欠落" near-complete gaps, clj-parity alignment with upstream,
real-`deps.edn` library usage to surface bugs, doc audit against code-truth
(prune/simplify/archive), abolish the per-session `private/notes` dependence
(public artifact — anyone develops in their own env), skill/rules review, replace
ADR/debt **pointer** comments with self-contained explanation (ADR docs stay) +
condense verbose comments (huge, gradual), marker-comment inventory. The user asked
to lightly pre-investigate, record perf, push, then **wire + audit the reference
chain so a clear session's `/continue` fires these going forward**, and stop. Done:
**ADR-0166** + **§9.2.T** + **D-522…D-529** + this resume contract wire it; the perf
campaign is paused. Resume = self-select a §9.2.T category and drain it.
