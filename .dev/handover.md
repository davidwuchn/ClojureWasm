# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; ≈ `368c9851`). Per-commit = smoke; commit
  **and** push (CLAUDE.md § atomic Step 6). `build.zig.zon` `.zwasm` = tag pin
  `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: **ADR-0162 step 2 = D-516 lazy-namespace bytecode**
  (the cold-start floor arc, D-450's highest cross-cutting lever). Steps 1 DONE: env-gated
  startup profiler (24a2d635) + **D-140 footer-seek (74970240)**. Measure-first attributed
  the ~9.4ms floor: self-exe read ~1ms / runEnvelope ~4.6ms (deserialize≈eval, 891 chunks,
  **non-core 79%**) / exec-residual ~3.4ms; D-140 cut tryRunEmbedded ~1000µs→~44µs (floor
  9.4→8.6ms). **D-516**: shrink the eager bootstrap to core + its load-time deps; embed each
  of the ~28 non-core stdlib ns as its OWN bytecode envelope replayed on demand by `require`
  (NOT re-parse) → ~4.8ms common case. MANDATORY F-011 gate same arc: build-time per-ns
  replay-clean check + audit defmethod/derive/extend-type/print-method side-effect visibility.
  Then step 3 D-517 zero-copy in-place deserialize (~3.5-3.8ms); step 4 D-518 heap-snapshot
  DEFERRED to the moving-GC unit (DA-vetted: B buys ~1ms behind a ~3.4ms wall at silent-heap-
  corruption risk). Plan: `private/notes/9.2.S-coldstart-architecture-20260624.md`; decision
  **ADR-0162** (DA folded verbatim). **GUARDRAIL**: never Zig-ify the .clj bootstrap (cljw-v0
  rut) — touch only the restore mechanism + eager set, .clj stays the definition language.
  9 other LIVE GAPS (D-450, re-measure on a quiet Mac — this session loaded): sieve 1.59× ·
  gc_alloc_rate 1.43× · string_ops 1.40× · destructure 1.20× · json_parse 1.12× ·
  map_filter_reduce 1.11× · bigint_factorial 1.08× · gc_large_heap 1.07× · nested_update 1.05×
  — after the cold-start arc. D-180/D-510/D-511(2-arg) DONE; D-515 binary-size axis (standing).
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails —
  `zig_build_test_needs_dwasm`); bare `zig build` for a probe (ADR-0133 — ReleaseSafe).

## Last landed (git log = SSOT)

**Cold-start floor arc (ADR-0162), steps 1 of 4.** Measure-first attribution of the
~9.4ms cold floor via a new env-gated startup profiler (`CLJW_PROFILE_STARTUP=1`,
24a2d635) → **D-140 footer-seek (74970240)**: `serialize.readEmbeddedPayload` stats the
self-exe + reads ONLY the 12-byte trailer (was: whole 8.8MB read every startup);
tryRunEmbedded ~1000µs→~44µs, floor 9.4→8.6ms. ADR-0162 (DA red-team folded verbatim)
chose lazy-ns bytecode (D-516) + zero-copy deserialize (D-517) for sub-4ms, deferring the
heap-snapshot (D-518) to the moving-GC unit. Survey+DA showed snapshot buys ~1ms behind a
~3.4ms exec wall at silent-heap-corruption risk. Guardrail: no .clj→Zig bootstrap rewrite.

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
- **gap-III perf campaign** (ROADMAP §9.2.S, D-450) — the fastest-script goal
  (ADR-0148): cljw FASTEST among cljw/Python/Ruby/Node/Babashka cold-start. The
  ACTIVE front (see Resume contract for the re-measured 2026-06-24 gaps + lever
  order). Then D-386 dispatch→superinstructions→JIT.

## North star (ACTIVE)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
The embedded **zwasm** JIT engine (ADR-0200) is the cljw DEFAULT (`.auto`); the
remaining north-star step is **components-through-the-JIT** (zwasm-side, D-500).
Live ledger: `.dev/zwasm_capabilities.md`.

## Cold-start reading order (resume)

handover → **ADR-0162** (cold-start architecture decision; DA red-team in Alternatives) →
`private/notes/9.2.S-coldstart-architecture-20260624.md` (measured attribution + D-516
lazy-ns Step-0 prep + D-140 record; gitignored, on local disk) → `.dev/debt.yaml`
**D-516/D-517/D-518** (the arc's steps) + **D-450** (the 9 other gaps, re-measure quiet) →
memories `perf_campaign_roadmap_9_2_s` / `perf_beat_python_every_bench` /
`verify_actual_pattern_not_proxy` / `verify_against_releasesafe_binary` /
`smoke_first_batch_full_gate`. Profiler: `CLJW_PROFILE_STARTUP=1 cljw -e 1` (stderr phase
deltas). The campaign fast-mode is injected by `scripts/perf_campaign_remind.sh`
(`.dev/.perf_campaign_active` set).
