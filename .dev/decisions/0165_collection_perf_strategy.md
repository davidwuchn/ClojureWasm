# ADR-0165 — Collection-perf strategy: keep best-of-breed algorithms, win on Zig-native layout (transients-first)

- **Status**: Accepted as the **direction** for §9.2.S collection work (2026-06-24). The
  per-lever activation is the TDD-loop's job; this ADR is the durable research synthesis +
  ROI ordering + the experimentation/regression protocol. Driven by the 2026-06-24 clean
  peer re-rank (ADR-0148 follow-up): cljw LOSES bb 1.02–1.16× on the collection-heavy
  benches (sieve/destructure/gc_*/bigint) but WINS pure-compute 2× (fib_loop/tak) + ratio_sum
  — so the gap is the COLLECTION/LIBRARY layer, not the VM engine.
- **Relates to**: ADR-0148 (fastest-script campaign — this is its collection sub-strategy),
  F-002 (finished-form), F-005 (numeric tower), F-006 (GC; GC-backed sharing avoids per-node
  refcount), F-011 (behavioural equivalence — the diff oracle is the safety net). D-520 (the
  draining debt row). The JIT (D-386 / ADR-0200 zwasm JIT) is the SEPARATE, larger compute
  frontier (JVM-Clojure territory; babashka structurally cannot JIT — SCI is not a Truffle
  interpreter, GraalVM native-image is AOT-only).

## Context — the measured truth

Clean **interleaved cljw-vs-bb** A/B (load-robust; the cross-run compare_langs table at
load ~9 was contaminated and over-claimed "7/9 won"):

| class                           | benches                                                                    | verdict                     |
|---------------------------------|----------------------------------------------------------------------------|-----------------------------|
| pure compute (interpreter loop) | fib_loop 2.0× · tak 2.2× · arith_loop 1.33×                           | **cljw WINS**               |
| exact rational                  | ratio_sum 1.42×                                                           | **cljw WINS**               |
| collection / library            | sieve · destructure · gc_alloc_rate · gc_large_heap · bigint_factorial | **cljw loses 1.02–1.16×** |

bb = SCI (tree-walk interpreter) + clojure.lang + java.math, all GraalVM-native-AOT, **no
JIT**. So bb and cljw are non-JIT-interpreter PEERS; cljw's bytecode VM actually BEATS SCI on
pure compute. cljw loses only where clojure.lang's 15-year-tuned data structures + JDK
BigInteger beat cljw's younger implementations. → the lever is collection implementation.

## Decision — the unifying strategy (the 3 routes converge as layers)

1. **Algorithm layer — keep best-of-breed; cljw ALREADY chose right.** Direct code read
   confirms: real **CHAMP** map/set (`data_map`+`node_map` two bitmaps + `@popCount`),
   radix-vector+32-tail, array-map≤8 linear, `std.math.big` (Karatsuba) + i48-immediate
   fast-path. No data-structure rewrite. **RRB-trees REJECTED** (size-table taxes the common
   indexed path; Clojure keeps it out of core — opt-in only for concat-heavy code).
2. **Implementation/layout layer — diverge from Java HERE; this is where Zig structurally
   wins.** Every measured Immer/im-rs win over Clojure/Scala (1.3–6.7× iteration, 3–25×
   equality) comes from **no object headers + tight cache layout**, which Zig gives by
   construction; and cljw's **GC-backed** trie avoids im-rs's per-node atomic `Arc`. So the
   "different path from Java" is at LAYOUT/memory, not algorithm.

## ROI-ordered levers (all implementation/constant-factor; map to the losing benches)

**Tier 1 (do first — biggest, lowest risk, helps real code beyond benches):**
- **L1 — Transients (single-threaded owner-token) + bulk build paths.** cljw's transients
  are a STUB today (vector.zig / map.zig). #1 in both clojure.lang and the industry survey.
  `into`/`vec`/`mapv`/`reduce conj` dominate real scripts. Zig win: owner-token = POINTER
  compare (cheaper than JVM `AtomicReference`); MemoryPool per node size-class. Benches:
  gc_alloc_rate/gc_large_heap/nested_update. **Highest ROI; the recommended first move.**
- **L2 — Chunked seqs on the WALK path.** cljw chunks + fuses only the `reduce` path;
  `map`/`filter` realize one Cons per element via a thunk Fn call on first/rest/seq walks.
  clojure.lang chunks 32-wide. Zig win: chunk = inline 32-slot array, not 32 heap thunks.
  Bench: sieve, map_filter_reduce.

**Tier 2 (medium):**
- **L3 — Keyword-map get fast path (destructure, worst 1.16×):** (a) monomorphic `bits==bits`
  before the dispatch-aware `eqConsult` (900K calls/bench); (b) `@Vector firstIndexOfValue`
  over the ≤8 array-map keys (cljw uses NO SIMD scan today); (c) optional keyword-keyed-map
  threshold 8→64 (clojure's `KW_HASHTABLE_THRESHOLD`). Also audit the analyzer destructure lowering.
- **L4 — Variable-size vector tail + array-indexed size-class free-list.** TailNode is fixed
  32-slot (256B) → a 4-elem vector over-allocates; free_pool is a hashmap (a small-size-class
  array free-list is cheaper). Bench: gc_alloc_rate.

**Tier 3 (smaller / later):**
- **L5 — `big.int.Mutable` + reused limbs_buffer** for in-place factorial multiply (gap already
  1.02× — low priority).
- **L6 — CHAMP canonicalization-on-delete** for fast map `=` (if not already complete).

## Experimentation + regression protocol (how to do this safely)

- **Branch per lever**: `develop/collection-<lever>` off latest main. Experiment-and-revert /
  commit-without-push until a lever PROVES a win; only then merge. A reverted experiment's
  commit may stay in the branch log; never leave a merged branch red.
- **Correctness net (load-independent; collection changes are GLOBAL → run FULL, not smoke)**:
  the F-012 dual-backend diff oracle (`zig build test -Dwasm`) + `corpus_regression` +
  `CLJW_GC_TORTURE`. A semantics-preserving collection change passes these mechanically — this
  is the "tests guard it" safety the change relies on.
- **Perf net (load-robust)**: per lever, the **interleaved cljw-vs-bb A/B + OFF/ON-knob**
  pattern (validated in the D-519 GO) on a quiet-ish Mac; record a baseline first. Keep iff
  diff-oracle-green AND bench win AND no regression on the other 8 ADR-0148 benches.
- **Smell/refactor gate (F-002/F-010)**: each lever held to finished-form; a workaround
  triggers surgery, not a patch.

## Consequences

- Lands cljw as clearly fastest-script (flips the 6 collection losses to wins) AND improves
  real-world code (transients/chunked-seqs are general, not bench-specific).
- Touches collection internals broadly; the diff oracle + corpus are the guard (per-lever full
  run, not smoke). No algorithm rewrite, so behavioural risk is bounded.
- The compute frontier beyond bb (JVM-Clojure territory) remains the SEPARATE JIT unit — not
  in this ADR's scope.

## Alternatives considered (from the 3 surveys, full notes in the proposal record)

- **RRB-tree vector** — rejected (common-path tax; Clojure keeps it contrib-only). Opt-in
  `flex_vector` only if a concat-heavy workload ever justifies it.
- **Full data-structure rewrite** — rejected; cljw's algorithm choices are already best-of-breed
  (CHAMP/radix+tail/array-map). The gap is constant-factor implementation.
- **Touch the VM engine for these benches** — rejected; the engine WINS pure compute 2×. The
  lever is collections; the engine's frontier is the JIT (separate unit).

Survey sources + the full proposal: `private/notes/collection-perf-proposal-20260624.md`,
`private/notes/9.2.S-clean-peer-rerank-20260624.md`, `private/notes/cljw_collection_codetruth.md`.
