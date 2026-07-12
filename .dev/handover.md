# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). Per-commit = smoke; commit
  **and** push (atomic Step 6). `build.zig.zon` `.zwasm` = tag pin `v2.2.0` (AOT-full-fidelity; from v2.1.0).
- **1.1.0 RELEASED (2026-07-12).** cljw `v1.1.0` tagged + pushed (user-authorized);
  release.yml published macos-aarch64 + linux-x86_64 binaries + sha256. Pins **zwasm
  v2.2.0**. Contents = 56 commits past v1.0.1: clojure.repl bundle + :arglists/:doc meta
  + regex lookbehind + %t format + interop statics + the D-555…558/C10 GC-correctness
  batch. **Homebrew tap LIVE**: `clojurewasm/homebrew-tap` (own tap, holds many
  formulae), `brew install clojurewasm/tap/cljw` verified on Apple Silicon (unsigned,
  ad-hoc/linker sig, no quarantine xattr; eval+wasm-FFI+clojure.repl all work). Signing
  = unsigned + README xattr fallback note (user call). D-549 residual (Docker/ghcr +
  Developer-ID notarization) stays user-LOCKED.
- 2026-07-07 session closed clean at
  `bff6d5eb0`. The ceiling FULL gate ran: ONE red (`dir_fn_set` — an e2e
  still calling the in-core dir-fn removed with D-513) — FIXED + re-smoked
  same session (the non-code-check exception; no full-gate re-run needed).
- **User BFS bug: BOTH layers now fixed (2026-07-09).** The 2026-07-07
  "VERIFIED FIXED" covered only the integer-state minimal repro (D-556
  class); the cw-arcade rush-hour suite STILL corrupted on HEAD. The
  residual root cause was **C10** (`.dev/gc_rooting.md`):
  `chunked_cons.rest`'s offset+1 alloc could collect while the input
  cursor (a fresh `range.seqChunk` result / a walk-loop Zig local) was
  on no root → ChunkBuffer UAF (`(first (rest (range 2)))` → nil under
  CLJW_GC_TORTURE_ALLOC). Fixed with the ADR-0150 fabrication bracket
  inside `chunked_cons.rest`; guards = gc_torture rest_range ladder +
  phase16_bfs_queue_gc + corpus bfs_queue. rush-hour verified green
  piecewise on HEAD (28 fast tests + generator tests; all 18
  difficulty-ordering samples byte-identical to clj). Perf datum:
  generator on cljw = seconds-to-minutes (interp; 4MB GC floor thrashes
  ~5x on live-heap-growing BFS — see the 2026-07-09 per-task note).
- **First commit on resume: the easiest-first drain head** — no floor
  open. DONE 2026-07-07 (**18 discharges**): D-555+556+557+558 GC/AOT
  arc (root fixes: persist-analysis-roots incl. builder.zig, conservative
  stack scan, evalRecur reentrancy, vm loc fidelity) / D-526 (9 interop
  drains) / D-554 ns attr-map / D-470 format %t / D-305+D-513-drains
  :arglists/:doc (291 vars, scripts/extract_core_meta.sh) + clojure.repl
  bundled (bare (doc x) at the REPL; core's pre-D-305 copies removed) /
  D-471 stream slurp/spit / D-521 destructure corpus net / D-529 markers
  / D-536+D-547 ledger honesty / D-241 baseline set! / D-466 stale row.
  Plus regex lookbehind + Pattern.split (HoneySQL green) + nREPL --port 0.
  Next candidates: D-513 lazy-ns docstrings (alt: bake per-ns meta chunks
  into lazy regions at cache_gen — see the per-task note), D-517
  zero-copy deserialize (M-L), D-522/523/524/525 public-ization sweeps.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm`; bare `zig build`
  for a probe (use ReleaseSafe). **The FULL gate MUST run `--serial-e2e`** — the `-P8`
  parallel default flakes the **D-418/D-258 agent load-race** (`agent_conj` →
  `[#<promise> 2]`; green isolated/serial, NOT a regression). **Never run a concurrent
  build during a gate** (host contention → false timeout). `.claude/**` edits may hit
  the auto-mode self-modification block — surface those to the user. **D-549
  distribution cluster (brew/Docker/signing) is user-LOCKED** — never self-select.

## Last landed (git log = SSOT)

2026-07-09 session: BFS pin (e2e phase16_bfs_queue_gc + corpus bfs_queue) +
the C10 `chunked_cons.rest` UAF fix (gc_torture rest_range ladder). zwasm
tag watch active (10-min cron; pin bump on a >v2.1.0 tag).

## Standing units (tracked in .dev/debt.yaml)

- **Perf campaign (§9.2.S) — PAUSED** (cheap levers exhausted; D-520 / D-386 / D-005/006).
- **D-439 sqrt(MathContext)** — the one BigDecimal remnant; a focused numeric cycle
  (correct rounding ×8 modes + JDK preferred output scale; base = the native Managed.sqrt).
- **D-513** — clojure.core.reducers / clojure.repl / var :doc (foundational).
- **D-418/D-258** — agent send/await + GC load-race (open, recall-trigger; re-gate serial).
- **D-430** — instaparse frontier is now DETERMINISTIC (core.cljc:361 `#'gll/TRACE`
  family) after the GC arc; re-derivable without the corruption noise.

## North star (ACTIVE, distal)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
zwasm JIT (ADR-0200) is the cljw default; remaining = components-through-the-JIT
(zwasm-side, D-500). Distal — needs a user nod; the §9.2.T public-ization sweep
(easiest-first debt drain) is the active near-term mode.

## Reading order (resume)

handover → **`private/notes/2026-06-25-debt-drain-order.md`** (easiest-first snapshot)
→ `yq` the live `active:` list → **ADR-0166** (public-ization sweep mode) → ROADMAP
§9.2.T. Memories: `verify_against_releasesafe_binary` / `smoke_first_batch_full_gate` /
`gate_parallel_e2e_timeout`.

## Stopped — user requested

User instruction (2026-07-09): 「これおわったら今日のサマリーを表示して停止して。」
Summary shown; the zwasm tag-watch cron stays armed per the same day's
directive (pin bump on a >v2.1.0 tag). A batched full gate (--serial-e2e,
ceiling look-ahead) was in flight at stop; HEAD's 4 commits are each
smoke-green + pushed. Resume at **D-523's residual**: `docs/architecture.md`
+ `docs/examples/wasm/README.md` were NOT in drain 1's "7/7 audited" set —
audit both vs code-truth (recipe in
`private/notes/2026-07-09-d460-sorted-as-key.md` § Extended challenge),
then D-522 pointer-condensation / D-527/528 / D-430 var-alias (S-sized).
