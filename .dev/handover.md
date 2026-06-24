# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; ≈ `368c9851`). Per-commit = smoke; commit
  **and** push (CLAUDE.md § atomic Step 6). `build.zig.zon` `.zwasm` = tag pin
  `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: the loop SELF-SELECTS here — the perf campaign's ACCESSIBLE
  levers are now exhausted (O-051 was the last clean one), so the remaining 9-bench gaps are all
  big/risky/fenced. Pick highest-value per CLAUDE.md (a correctness/clj-parity floor outranks new
  coverage; Step 0.5 quality-loop-floor drain first). The perf options, all characterized:
  **(L4 small-map)** Step-0'd + DEFERRED — `traceArrayMap` is already count-bounded (not 16-wide) so
  L4's only gain is the 256B→~64B alloc, and `GcHeap.alloc` is fixed-size-only (no variable-length
  objects), so L4 = introducing variable-length GC objects (F-006 GC-arch) for a 1.12× bench. Poor
  ROI. **(D-386 dispatch, destructure 1.16×)** the destructure residual is per-op dispatch + binding
  lowering = D-386(a) inline-stepOnce — but its own row marks (a) "risky UAF-class, not to be
  rushed" + PREREQUISITE D-244 #4 gc_self_guard hoist; (b) DEAD (empirically refuted); (c) JIT
  user-fenced (ADR-0151). So D-386 is NOT a quick win — only attempt (a) WITH the D-244 #4
  prerequisite + alloc-torture validation, deliberately. The collection-perf sub-strategy (ADR-0165)
  has DELIVERED its clean lever (**O-051**, see Last landed). Post-O-051 decomposition (hyperfine -N,
  20 runs, load ~3) of the remaining 9-bench gaps:
  - **gc_large_heap 1.12×** → **L4 small-map alloc/GC**. Decomposed: walk+reduce TIES (glh_A 0.99),
    map-alloc+into WINS (glh_B 0.88), but reduce over a vec holding 100K live array-maps LOSES
    (glh_D maps=1.03 tie vs glh_E ints=0.64 win — the only diff is maps-vs-ints in the live vec).
    So the loss is ALLOCATION + GC-tracing of 100K live `[16]Value` (256B) array-maps holding 2
    entries — NOT the get (O-051 done) nor the walk. Lever = right-size ArrayMap (256B→~64B) /
    reduce GC trace cost. **Invasive** (ArrayMap is a fixed `extern struct` — variable-length
    trailing array touches every site + GC trace + assoc growth) → its own Step 0 survey + DA.
  - **destructure 1.16×** → **D-386 (VM frontier)**. O-051 cut the get path; the residual is the
    binding-lowering EXECUTION (mapd−getonly ≈10ms cljw vs ≈3ms bb — clj-identical expanded code,
    so it's VM local-slot/seq?-coercion execution, not a collection lever). DA classified the clean
    attack (destructure inline-cache) as D-386 territory.
  - **sieve 1.13×** / **gc_alloc_rate 1.05×** → hard / near-noise. sieve's source is a `cons`-list
    (non-chunked in clj AND cljw — filter/map already chunk CHUNKED sources via O-032; a list
    can't); the residual is per-element `force` (VM thunk call). gc_alloc_rate is L4 (TailNode
    `[32]Value` over-alloc for 4-elem vectors, partly O-040'd) but ~noise.
  Other classes WIN big (map_filter_reduce 1.65× / vector_ops 2.39× / map_ops 3.48× / nested_update
  1.39× / ratio_sum / pure-compute 2×). So the campaign's next real front = **L4 (invasive, dedicated
  cycle) OR D-386 (the separate VM frontier)** — NOT another cheap collection constant-factor.
  Per lever: branch `develop/collection-<lever>`, experiment-and-revert / commit-no-push, **FULL
  diff oracle (global change, NOT smoke)** + clean old-vs-new-binary A/B (load-robust; the channel
  degrades at load ≥3 — use file-sentinels). **GUARDRAIL**: never Zig-ify the .clj bootstrap.
  D-517/D-518 DEFERRED; D-515 binary-size (standing).
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails —
  `zig_build_test_needs_dwasm`); bare `zig build` for a probe (ADR-0133 — ReleaseSafe).

## Last landed (git log = SSOT)

**L3 keyword-map-get fast path LANDED as O-051 (ADR-0165 Amendment 1).** `array_map`
`get`/`contains` compare keyword keys by raw NaN-box payload bits (keywords are interned ⟹
`=` is bit-identity) via the new `arrayMapKeywordSlot` helper, skipping the per-entry
`keyEq`→`eqConsult`→`keyEqValue` error-union chain; non-keyword keys keep the general path;
the `>8`-entry hash_map path is unchanged. Clean old-vs-new ReleaseSafe binary A/B (hyperfine
-N, 30 runs): destructure −6.6%, gc_large_heap −4.5%, 300k-get −11.0%, map-destructure −6.3%.
diff oracle (`zig build test -Dwasm` ×2) green + new map.zig unit test (keyword hit/miss +
mixed keyword/int/string keys) + lint clean. Amendment 1 also corrected ADR-0165's two false
premises (transients-are-a-stub; L1-first) and the stale peer standing. Prior: D-519 eval
auto-collect (ADR-0164, memory bounded + faster) + the cold-start arc (ADR-0162/0163).

## Standing units (tracked in .dev/debt.yaml)

- **D-511** — 2-arg `(BigDecimal. x mc)` ctor LANDED (8db6d82f); only the
  exact-binary `(BigDecimal. double)` footgun remains (OPEN-LOW, deferred).
- **D-513** — three linked clj-parity gaps, all foundational (NOT clean drop-ins):
  (1) `clojure.core.reducers` (needs reduce→CollReduce wiring OR a cljw-native
  reducers impl; transducers supersede it, moderate-low value); (2) `clojure.repl`
  (dir/apropos implementable, but doc/find-doc/source blocked by (3)); (3) var
  `:doc` metadata absent — `(:doc (meta #'reduce))` → nil; wiring docstrings
  through every bootstrap defn/def + primitive var registration is a large,
  separate unit and the real prerequisite for a useful `clojure.repl`.
- **gap-III perf campaign** (ROADMAP §9.2.S) — fastest-script goal (ADR-0148). ACTIVE
  sub-strategy = **collection-perf (ADR-0165 / D-520)**: keep best-of-breed algorithms,
  win on Zig-native layout, transients-first (see Resume contract). Startup axis is won
  (cold-start arc); the SEPARATE compute frontier beyond bb = D-386 JIT.

## North star (ACTIVE)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
The embedded **zwasm** JIT engine (ADR-0200) is the cljw DEFAULT (`.auto`); the
remaining north-star step is **components-through-the-JIT** (zwasm-side, D-500).
Live ledger: `.dev/zwasm_capabilities.md`.

## Reading order (resume)

handover → **ADR-0165** (collection-perf strategy + ROI levers + experiment/regression protocol;
the NEXT direction) → **D-520** (the draining campaign row) → `private/notes/`
**collection-perf-proposal-20260624.md** (3-survey synthesis) + **9.2.S-clean-peer-rerank-20260624.md**
(measured standing) + **cljw_collection_codetruth.md** (where cljw is naive). Background:
**ADR-0148** (fastest-script campaign) → **ADR-0164** (D-519 auto-collect, LANDED). Tools:
`CLJW_GC_STATS=1` (alloc/reuse%/collects) / `CLJW_GC_THRESHOLD_MB` (auto-collect floor knob,
also the OFF-vs-ON A/B lever) / `CLJW_PROFILE_STARTUP=1`. Measurement discipline: ms-margin
peer benches need a QUIET Mac (load <~2); the load-robust signal is the interleaved OFF-vs-ON
knob A/B. Memories: `verify_against_releasesafe_binary` / `smoke_first_batch_full_gate` /
`perf_campaign_roadmap_9_2_s`. Campaign fast-mode injected by `scripts/perf_campaign_remind.sh`.
