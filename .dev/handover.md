# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). Per-commit = smoke; commit **and** push
  (CLAUDE.md § atomic Step 6 — the perf-campaign no-push mode is LIFTED; push normally).
  `build.zig.zon` `.zwasm` = tag pin `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: self-select the highest-value §9.2.T unit
  (**ADR-0166** standing mode; Step 0.5 reads the `quality_floor:` rows). The
  **contained correctness floor is now drained** — so the highest-value remaining
  is the two deep real-library bugs: **D-530** (deftype overloaded same-name-method
  arity dispatch — the top *code-tractable* target: investigate the `expandDeftype`
  lowering + `lookupMethod` name-only keying; fully unblocks data.priority-map's
  subseq; warrants a DA fork as a dispatch-design change) and **D-531** (partitions-M
  UAF — needs a GC-poison instrument or faster torture-under-lldb first; see its
  debt row's tooling diagnostics). Lower-value standing fallbacks: **D-528** more
  real-library loads (3 done: priority-map/math.combinatorics buggy, core.unify
  clean), then the pure-polish rows **D-522** (de-pointer — note: few BARE pointers
  exist; most refs are anchors within explanatory prose, keep those) · **D-523**
  doc audit · **D-524** `private/` decouple · **D-525** rules/skills review ·
  **D-529** marker inventory (the PERF/optimizations.md cross-check is clean bar
  ISO-8601 regex noise). **D-526 is COMPLETE** (java.lang scalar statics + Objects).
  A correctness/clj-parity floor outranks pure polish.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails);
  bare `zig build` for a probe (ADR-0133 — use ReleaseSafe). Note: `.claude/**` edits
  (D-524/525) may hit the auto-mode self-modification block — surface those to the user.

## Last landed (git log = SSOT)

§9.2.T correctness-floor session (D-526/527/528). **D-526 java.lang scalar static
surface COMPLETE** (Long/Integer/Double/Boolean/Character/Math; String/join,
unsigned-arithmetic cluster, Character surrogate/codePoint, Double bit-conversion,
hashCode + Math ceilDiv family — 6 corpus files) + **new java.util.Objects surface**.
**D-527**: clj-parity sweeps found no real bugs (solid); fixed clj_diff_sweep.sh to
auto-require qualified ns on the cljw side. **D-528 real-library load found + fixed
4 bugs**: deftype-as-map `=` symmetry (MapEquivalence gate), map?/sorted?/set?
deftype recognition, and a **core lazy-`=` GC-rooting bug** (seqEqualWalk root frame;
minimal torture repro). Deep bugs recorded with full diagnostics: **D-530** (deftype
overloaded same-name-method arity dispatch — blocks data.priority-map subseq),
**D-531** (partitions-M lazy-realization UAF — ReleaseSafe-only, lldb/Debug both
tooling-blocked). All gates green.

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
