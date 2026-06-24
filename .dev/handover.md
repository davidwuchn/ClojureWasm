# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). Per-commit = smoke; commit **and** push
  (CLAUDE.md § atomic Step 6 — the perf-campaign no-push mode is LIFTED; push normally).
  `build.zig.zon` `.zwasm` = tag pin `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: self-select the highest-value remaining unit
  — **D-530 (deftype/reify cross-section overload), Compiler/specials (tools.macro
  unblock), and D-534 (APersistentSet/IPersistentList extend markers) are all DONE**
  this arc (the satisfying chain: Compiler/specials → tools.macro → algo.monads now
  fully loads). The remaining menu is lower-value, so re-raise precision: a
  **tools.macro-dependent library re-probe** (proven bug-finder — D-530/D-534 came
  from real libs; with tools.macro now loading, retry libs that rode it) is the
  highest-yield; then **D-533** (ref/var validators + ref ctor option — moderate
  STM/Var-GC, low-freq), **D-531** (partitions-M UAF — GC-poison instrument first),
  **D-532** (fuzzy float round-trip only), then pure-polish **D-522** (de-pointer —
  few BARE pointers) · **D-524/525** (`.claude/`-blocked, surface to user) · **D-529**
  marker inventory. A correctness/clj-parity floor outranks pure polish.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails);
  bare `zig build` for a probe (ADR-0133 — use ReleaseSafe). Note: `.claude/**` edits
  (D-524/525) may hit the auto-mode self-modification block — surface those to the user.

## Last landed (git log = SSOT)

§9.2.T public-ization session. **D-530 (deftype/reify cross-section same-name-arity
overload)** — `lowerDefType` + `expandReify` merge a method name appearing at
different arities across protocol sections into one multi-arity `fn*`; Step 0 survey
+ DA fork + ADR-0066 Amendment 1 + dual-backend diff + e2e; unblocks data.priority-map
subseq. **Compiler/specials** — `clojure.lang.Compiler/specials` exposes cljw's
special-form symbol set (SSOT-derived, gc.pin-rooted), the single wall blocking
tools.macro. **D-534** — `APersistentSet`/`IPersistentList` as extend-protocol targets
distribute to native set/list tags; **algo.monads now fully loads + runs clj-faithfully**
(the Compiler/specials → tools.macro → algo.monads chain). Earlier this session: the
interop surfaces (UUID/BigInteger/BigDecimal ctors, java.util.Objects), 8 real bug fixes
(deftype `=`/predicates, core lazy-`=` GC-rooting), the D-528 6-library drain, and the
**D-523 doc audit (all 7 user-facing docs/, 6 had stale claims)**. All gates green.

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
