# Optimizations ledger (SSOT)

> **Purpose.** A discoverable index of every place where cljw's code is
> shaped for *speed* rather than for the simplest correct form. The
> user's directive (2026-05-31): *"将来の最適化のとき、「最適化してる
> んだよ」と分かりやすく — 理想は SSOT 的な箇所があること"*. This is that
> SSOT. Optimizations come in many kinds and not all fit one registry
> cleanly, so this is a **best-effort index**, paired with the
> grep-discoverable in-code `// PERF:` marker
> (see [`.claude/rules/perf_marker.md`](../.claude/rules/perf_marker.md)).
>
> An entry answers: *what is the naive correct form, what is the
> optimized form, why is it faster, and what verifies they agree?*
> The naive form is the behavioural contract; the optimization must be
> observably equivalent (F-011) — only the internal mechanics change.

## How to read / maintain

- Every optimization that trades simplicity for speed gets (a) a
  `// PERF: <what> [refs: O-NNN, …]` marker at the code site and
  (b) a row here. The `O-NNN` id is this ledger's; cross-ref the
  driving `D-NNN` debt row when one exists (perf debt lives in
  `.dev/debt.md`; this ledger is the *implemented* optimizations).
- A "fast path" that can be removed and replaced by the naive form
  with no behaviour change is the cleanest kind — note the naive
  fallback explicitly so a future reader can verify by deletion.
- When an optimization is reverted / superseded, mark the row
  `RETIRED <date>` rather than deleting it (history).

## Entries

| ID    | Site                                         | Naive form (the contract)                                                                                  | Optimized form                                                                                         | Why faster                                                                                                                                                  | Verified by                                       | Refs          |
|-------|----------------------------------------------|------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|---------------|
| O-001 | `runtime/collection/range.zig` + call sites  | `(range a b s)` as a lazy cons-seq (one cons + lazy_seq per element)                                       | Compact `.range` value `{start,end,step,count}`: O(1) count/nth, tight-loop reduce, chunked-cons `seq` | No per-element alloc on count/nth/reduce; 1 alloc/32 on walk                                                                                                | `phase14_range_indexed.sh` + diff oracle vs `clj` | D-163 / D-168 |
| O-002 | `higher_order.zig::reduceFn` (`.vector` arm) | `reduce` over a vector via `seqFn` → `vectorToList` (N-element eager cons list), then walk via first/next | Index-walk: `vector.nth(coll, i)` in a tight `i` loop, honouring `reduced`                             | No N-element intermediate cons list; `(reduce f bigvec)` / `(into to bigvec)` went O(n) alloc → O(1). Measured `(reduce + (vec (range 1e6)))` 182s → fast | `phase14_*` reduce e2e + diff oracle vs `clj`     | D-163         |

## Identified high-ROI candidates (measured, not yet implemented)

Ranked by ROI (impact × frequency / effort·risk). Measured 2026-05-31 on
mac-arm-m4pro, startup baseline 0.48s subtracted where noted.

1. **`persistent!` rebuilds the vector via N persistent `conj`s**
   (`transient_vector.zig::toPersistent` L124-131 loops `vector.conj`
   per element). The transient's flat buffer fill is O(1) amortised, but
   `persistent!` is O(n log n) + N node allocs — so transient-backed
   `into`/`vec` get NO benefit (the win JVM transients give is an O(1)
   `persistent!` handoff). **Measured: `(count (vec (range 1e6)))` =
   121s; `(reduce + (vec (range 1e6)))` = 123s — almost entirely
   `persistent!`** (the `reduce conj!` fill is <1s; cf. `(reduce +
   (range 1e6))` = 60ms). **Fix:** a bulk `vector.fromSlice(rt, items)`
   that builds the HAMT trie bottom-up from the flat buffer in O(n)
   (fill 32-element leaf HamtNodes → interior levels → tail), then
   `toPersistent` + transient `into`/`vec` use it. **HIGH ROI**
   (into/vec ubiquitous) but **touches the core Vector type → needs a
   focused unit with exhaustive boundary tests** (n ∈ {0,1,31,32,33,63,
   64,65,1023,1024,1025,1e5}: build → nth-all + count + `=` vs a
   conj-built vector). cw v0 + JVM both maintain the trie incrementally
   in the transient so `persistent!` is O(1); a bulk `fromSlice` is the
   cljw-appropriate equivalent (the transient stays a flat buffer; the
   conversion is the one O(n) pass). Tracked: D-180.
   *(The transient-routing half — `into`/`vec` calling `transient`/
   `conj!`/`persistent!` with an `-editable?` guard — was prototyped and
   reverted 2026-05-31: net-neutral until this `persistent!` fix lands,
   so the pair must land together.)*

2. **cljw startup ≈ 0.48s per invocation** — every `cljw -e` / test /
   probe re-parses + analyses + evaluates ~1000-line `core.clj`. The
   e2e suite's ~138s parallel block is dominated by this (hundreds of
   invocations × 0.48s). **Highest dev-velocity ROI** (every iteration
   pays it) but **architectural** (a pre-analysed bootstrap cache, à la
   ClojureScript's analyzer cache). Tracked: D-140.

## Out-of-scope future optimizations (tracked, not yet implemented)

- **Map/filter/take reduce-fusion** (cw v0 `fusedReduce`: collapse a
  `(reduce f (map g (filter p (range n))))` chain to a single 0-alloc
  pass over the base). The compact `.range` value (O-001) is the
  substrate this operates over. **Measured: `(count (map inc (range
  1e5)))` = 42s ≈ 420µs/element** (the lazy_seq per-element thunk
  realisation). Deferred to the D-163 perf window as its own ADR. cw v0
  measured 1336x on lazy_chain — see D-163's cw-v0
  blueprint note.
