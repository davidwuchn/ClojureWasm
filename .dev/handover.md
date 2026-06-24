# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; ≈ `368c9851`). Per-commit = smoke; commit
  **and** push (CLAUDE.md § atomic Step 6). `build.zig.zon` `.zwasm` = tag pin
  `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: **§9.2.S collection-perf L1 — transients** (**ADR-0165**
  / **D-520**). The 2026-06-24 investigation (3 surveys + cljw code-truth) REFINED the direction:
  cljw's VM WINS pure-compute 2× (fib_loop/tak) + ratio_sum 1.42×; it LOSES bb 1.02–1.16× ONLY
  on COLLECTION-heavy benches (sieve/destructure/gc_*/bigint) because clojure.lang's mature data
  structures beat cljw's younger ones — NOT an interpreter gap (bb = SCI tree-walk + clojure.lang,
  NO JIT; cljw's bytecode VM beats SCI). So the immediate lever is **COLLECTIONS, not the JIT**
  (the JIT = the SEPARATE bigger compute frontier, D-386, that bb structurally cannot follow).
  cljw already has best-of-breed ALGORITHMS (real CHAMP+@popCount, radix+tail, array-map,
  std.math.big — NO rewrite; RRB rejected); the win is Zig-native LAYOUT. Drain ROI-ordered
  (ADR-0165 levers): **L1 transients (owner-token; a STUB today) FIRST** → L2 chunked-seq WALK
  path (sieve) → L3 keyword-map get fast-path+@Vector (destructure) → L4 variable vector tail →
  L5/L6. Per lever: branch `develop/collection-<lever>`, experiment-and-revert / commit-no-push,
  **FULL diff oracle (global change, NOT smoke)** + interleaved cljw-vs-bb A/B (quiet-ish Mac).
  Optional baseline-lock first: confirm the peer re-rank + the 2 py-benches (json_parse,
  nested_update) at load <2. **GUARDRAIL**: never Zig-ify the .clj bootstrap. D-517/D-518
  DEFERRED; D-515 binary-size (standing).
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails —
  `zig_build_test_needs_dwasm`); bare `zig build` for a probe (ADR-0133 — ReleaseSafe).

## Last landed (git log = SSOT)

**D-519 eval auto-collect LANDED + GO-PASSED (ADR-0164).** Shared `GcHeap.maybeAutoCollect()`
(the torture-alloc collect verbatim, gated `bytes_since_last_gc>threshold_bytes`) at BOTH the
`alloc` boundary + the VM back-edge poll; default floor 1MB→4MB via new per-heap
`threshold_floor_bytes` + `CLJW_GC_THRESHOLD_MB` knob; torture kept in the gate. Root cause
(no eval auto-collect → unbounded malloc + latent OS-OOM) fixed decisively: `CLJW_GC_STATS`
mallocs 401K→27335 (4M-vector run FLAT at 27335 = memory bounded). The load-robust OFF-vs-ON
A/B refuted the DA's canary-regression fear — ON is FASTER on all 8 benches (gc_alloc_rate
1.39×, string_ops 1.28×, …) + ~10× lower variance (collect+reuse wins cache/page-fault
locality). Correctness: diff oracle green; 15/305 mid-eval collects yet sums exact. Prior arc
(cold-start floor 9.4→4.3ms, ADR-0162/0163) still holds. Guardrail held: no .clj→Zig rewrite.

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

## Stopped — user requested

User instruction (2026-06-24): 「この調査は貴重なので、しっかりコミット領域に永続化し、どこ
かから参照させ、その上で、クリアセッションからでもcontinueで自律継続できるように、配線・参照
チェーン監査をして停止してください」(persist the collection-perf investigation into the tracked
area, reference it, and wire/audit the chain so a clean session can `/continue` autonomously,
then stop). Done: the investigation is persisted as **ADR-0165** (collection-perf strategy) +
**D-520** (the draining campaign row) + 3 `private/notes/` survey records; referenced from the
Resume contract, the gap-III standing bullet, the Reading order, and ROADMAP §9.2.S. The perf
campaign is **RE-OPENED into the collection-perf phase** (`.dev/.perf_campaign_active`
re-touched); First-commit-on-resume = collection-perf **L1 transients** (above). Earlier "lever
= JIT" framing CORRECTED by this investigation: the immediate lever is COLLECTIONS (the JIT is
the separate bigger frontier). Clean state: tree clean, HEAD pushed, full gate green (the D-519
arc; collection work has not started — only docs/wiring landed since). Resume chain audited:
handover → ADR-0165 → D-520 → the 3 notes, then start L1.
