# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). Per-commit = smoke; commit **and** push
  (CLAUDE.md § atomic Step 6 — the perf-campaign no-push mode is LIFTED; push normally).
  `build.zig.zon` `.zwasm` = tag pin `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: drain `.dev/debt.yaml` `active:`
  **EASIEST-FIRST** (NEW work-order, 2026-06-25 user decision — by tractability NOT
  value; CLAUDE.md § next-task rule). Read **`private/notes/2026-06-25-debt-drain-order.md`**
  (the snapshot + easiest→hardest order) and take **Tier 1** first — the partial-
  residual + niche contained quick-wins: start **D-472** (`bytes?` predicate) →
  D-480 (`Serializable` marker) → D-526 (Arrays/Collections statics) → D-446
  (multidim `aset`) → D-439 (BigDecimal sqrt/scaleByPowerOfTen/ulp/divideAndRemainder)
  → … Drain the WHOLE list incl. niche/deferred to clear 残件; do NOT defer a row as
  "take-up-on-consumer". **Update the ledger reliably each cycle**: discharge + MOVE
  the finished row active→discharged (insert before the trailing `conventions:` key)
  in the same cycle. Tier 4 (Tier-D / security-forward / perf-campaign / recall /
  `.claude/`-blocked) stays until its gate changes. The D-530/Compiler-specials/
  D-534/D-533 arc + the full debt audit (active 111→87) are DONE.
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

User instruction (2026-06-25, paraphrase): "this debt re-categorization feels like
something I keep making you redo — persist it (dated, in private), then from next
time sweep NOT by value but **easiest-first (取り組みやすい順)**, and **update debt
reliably** as you go; **review niche/deferred too and eliminate the 残件** (don't
perpetually defer 'low-value'). Audit the wiring / reference chain so this fires
going forward, then **stop**." DONE this session: (1) full code-truth debt audit
(active 111→87 — 24 done rows refiled, D-239/D-439 re-narrowed, 87 verified
genuinely-open); (2) snapshot + easiest→hardest drain order persisted to
`private/notes/2026-06-25-debt-drain-order.md`; (3) re-wired the work-order to
EASIEST-FIRST drain-ALL + reliable-per-cycle-update across CLAUDE.md (3 next-task
spots) + ROADMAP §9.2.T + tech_debt_consolidation + the `debt-ledger-audit-decisions`
memory (Refinement 2026-06-25). **Resume = drain `active:` Tier 1 first (D-472,
D-480, D-526, D-446, D-439…), reliably moving each finished row to `discharged:`.**
