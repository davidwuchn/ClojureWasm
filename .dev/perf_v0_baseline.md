# Perf v0-parity campaign — mined baseline (seed for the optimization campaign)

> Created 2026-06-11 (user-directed). The cljw-vs-v0 perf-parity campaign's
> data-driven starting point: WHICH optimizations made cw v0 fast, mined from
> v0's own `bench/history.yaml` + `git log`, so v1 re-implements proven winners
> instead of trial-and-error + revert. v0 clone:
> `~/Documents/MyProducts/ClojureWasm/`. Re-derive cljw-clean (F-004; NEVER
> verbatim-copy per `.claude/rules/no_copy_from_v1.md`).

## The gap (cold-start ms: v0 → current v1 → Python; lower better)

v0 beat Python **17/20**; current v1 lost most of that (it deferred v0's VM
optimizations — D-133). v1 is roughly at v0's *pre-24A* level.

| bench             | v0 final | v1 now | Python | note                     |
|-------------------|----------|--------|--------|--------------------------|
| arith_loop        | **4–5** | 170    | 53.8   | 34× regression — worst |
| fib_recursive     | 16       | 67     | 20.8   |                          |
| sieve             | 5–7     | 35     | 15.1   |                          |
| map_filter_reduce | 6        | 27     | 16.4   |                          |
| lazy_chain        | 5–7     | 28     | 19.6   |                          |
| nested_update     | 12       | 56     | 15.3   |                          |
| tak               | 8        | 20     | 15.4   |                          |

Already beating Python in v1: fib_loop / map_ops / list_build / atom_swap /
multimethod_dispatch / vector_ops.

## Which v0 optimizations moved the needle (from `bench/history.yaml`)

Each row = a v0 phase id + reason; arrows = the big measured drop it caused.
Read the matching v0 commit/phase, then re-derive in v1.

| v0 phase  | what                                               | measured drop                                     |
|-----------|----------------------------------------------------|---------------------------------------------------|
| 24A.3     | fused reduce + dispatch + stack array              | lazy_chain 21375→7356, mfr 4013→1287            |
| **24A.9** | **arith fast-path + IReduce**                      | **fib 502→28**                                   |
| 24C.1     | fix fused reduce (restore `__zig-lazy-map` meta)   | lazy_chain 6655→17, mfr 1293→179                |
| 24C.4     | vector geometric COW + collection ops              | mfr 179→14                                       |
| **24C.7** | **filter-chain collapsing + active VM call**       | **sieve 1698→16**                                |
| 27.3e     | NaN boxing (Value 48B→8B)                         | broad: lazy 16→9, mfr 17→10 — *v1 already has* |
| 32        | build-time bootstrap cache                         | lazy_chain 9→5 — *v1 already has (ADR-0056)*    |
| **37.2**  | **superinstructions (fuse common opcode seqs)**    | arith 53→40, fib 19→16                          |
| **37.3**  | **fused branch + loop superinstructions**          | arith 40→31                                      |
| **37.4**  | **JIT PoC — ARM64 hot-loop native codegen (D87)** | **arith 31→3**                                   |
| 83E-v2    | all-Zig macro migration                            | lazy_chain 6→2                                   |

So the lever order roughly: (1) arith/fib fast-paths + IReduce (24A.9),
(2) fused-reduce / filter-chain collapse for lazy/mfr/sieve (24A.3/24C.1/24C.7),
(3) **superinstructions** (37.2/37.3 — cross-platform-safe, no machine code),
(4) **hot-loop JIT** (37.4 — the last-mile arith 10×). v1 already has NaN-box +
AOT bootstrap, so skip those.

## v0 full optimization catalog (the re-derivation worklist)

From v0 `.dev/optimizations.md` (its authoritative catalog; numbers are v0's).
**KEY INSIGHT: almost the entire win is interpreter / runtime work —
cross-platform, NO machine code. The JIT is ONLY the last arith lever.** So the
campaign is overwhelmingly low-risk re-derivation; the JIT is optional polish.

Proven winners, biggest-first (re-derive cljw-clean per F-004):

| v0 task | technique                                   | v0 gain                          |
|---------|---------------------------------------------|----------------------------------|
| 24A.4   | **arithmetic fast-path inlining**           | fib_recursive 502→41ms (**12×**) |
| 24C.5b  | two-phase bootstrap (D73)                   | transduce 2134→15ms (142×)       |
| 24C.2   | multimethod 2-level cache                   | multimethod 2053→14ms (147×)     |
| 24C.1   | fix fused reduce (`__zig-lazy-map`)         | lazy_chain 6655→17ms (391×)      |
| 24C.7   | filter-chain collapsing (D74)               | sieve 1645→16ms (103×)           |
| 24A.3   | fused reduce (lazy-seq collapse)            | sieve 2152→40ms (54×)            |
| 24C.3   | string stack-buffer fast path               | string_ops 398→28ms (14×)        |
| 24C.4   | vector geometric COW + Cons cells           | vector_ops 180→14ms (13×)        |
| 24C.5   | GC free-pool recycling                      | gc_stress 324→46ms (7×)          |
| 24A.1   | switch dispatch + batched GC                | fib_loop 1.8×                    |
| 24A.5   | monomorphic inline cache                    | protocol_dispatch               |
| 24C.9   | Zig builtins for update-in/assoc-in         | nested_update 1.7×               |
| 37.2/3  | superinstructions + compare-branch fusion   | arith_loop 53→31ms (1.71×)       |
| 37.4    | ARM64 hot-loop JIT (D87)                    | arith_loop 31→3ms (10.3×)        |

**DECIDED-AGAINST in v0 (do NOT spend effort here):** tail-call dispatch
(0% on Apple M4, measured 45.3), RRB-Tree vectors (rarely sliced), SmallString
widening (`asString()` lifetime), string interning (string_ops bottleneck is
alloc, not comparison), wasmtime-as-library.

**v0 never did (open frontier if the above isn't enough):** escape analysis
(local-only GC elision), generational GC, SmallVector (inline 2-3 elts), closure
stack allocation, profile-guided polymorphic IC.

## Benchmark equivalence (v0 already audited this — F121)

`history.yaml` header documents F121 (2026-02-09): pre-F121 the OTHER languages
used easier algorithms, unfair to cljw — C used a plain array where cljw used a
hash map (map_ops), C/Py/Ruby/Zig/Java used standard Eratosthenes where cljw
used filter-based (sieve), C/Zig used struct field access (keyword_lookup),
Python used deque (list_build), etc. F121 made them EQUIVALENT. So v0's 17/20 is
post-equivalisation. **Audit task for v1: diff each `bench.{c,go,py,rb,js,java}`
against v0's post-F121 versions — confirm v1 did not regress the equivalence
(no language handed a leg-up). No cheating the other direction either.**

**Audit result (2026-06-11): PASS.** `diff -rq bench/benchmarks` v1 vs v0 shows
the v0-inherited benchmark sources are **byte-identical** to v0's F121-equalized
versions — every slow benchmark the campaign targets (fib/tak/arith_loop/sieve/
nqueens/lazy_chain/transduce/keyword_lookup/nested_update/string_ops/
real_workload/gc_*/bigint_factorial) is unchanged from v0, so no language is
handicapped. arith_loop spot-checked: cljw/`bench.c`/`bench.py` all do the same
`sum += i` loop to 1e6 — the 170 ms vs v0's 5 ms is a GENUINE interpreter
regression, not benchmark unfairness. (v1-only benches not in v0 — sort /
regex_count / destructure / edn_roundtrip / stm_refs — would need their own
equivalence check before being used as a cross-lang optimization target.)

## JIT constraints (user-directed 2026-06-11) — before writing any codegen

- **Cross-platform from day one**: ARM64 (mac) AND x86_64 (ubuntu) both correct,
  no platform-specific bugs. v0 shipped JIT bugs it had to fix later —
  `b4c7077` "Fix JIT register clobbering: use only caller-saved registers",
  `6ce917a` "JIT arch guard + test path fix", `v0.4.0-fix` JIT register fix.
  Learn from those; gate both arches (ubuntunote for x86_64).
- **Non-ad-hoc / consolidated**: decide the LAYER first (an ADR) — where the JIT
  lives, its boundary with the VM, how hot paths are detected/dispatched — so it
  is one cohesive module, not scattered codegen. Likely under
  `src/eval/backend/` beside the VM. Superinstructions (37.2/37.3, pure
  bytecode, no machine code) are the lower-risk precursor and may get most of
  the win before the JIT is needed.
- Every step: F-011 (clj-equivalent, corpus) + **GC-torture safety** (the
  O-005/O-013 reverts — interpreter-frame / dispatch changes must hold under
  `CLJW_GC_TORTURE` + deep recursion).

## v1 architecture bridge — where the levers land in THIS codebase

Mapping v0's proven winners onto v1's actual structure (from a v1 source read):

- **#1 lever — arith intrinsic opcodes (v0 24A.1 + 24A.4, fib 12×).** v1's VM
  has **no arithmetic opcodes**: `(+ a b)` compiles to `op_invoke_builtin`
  (0x0E in `src/eval/backend/vm/opcode.zig`) → a full builtin dispatch per
  operation. v0 had direct `op_add/op_sub/op_mul/op_lt/op_eq…` intrinsics with
  an integer fast path. Adding them to v1 is the single biggest fib/arith/tak
  win. **Dual-backend change** (ADR-0036 `dual_backend_parity.md`): new opcode →
  compiler arm + VM dispatch arm + TreeWalk parity + ≥1 diff_test case, one
  commit. Integer-overflow must still auto-promote to bigint (F-005) — the fast
  path checks for overflow and falls back, never silently wraps.
- **Superinstructions (v0 37.2/37.3) are already mapped to v1's Phase 17
  `super_instruction.zig`** (per `vm/peephole.zig` header — peephole is
  removal-only "110% tier"; fusion is the planned "100% tier"). The campaign
  activates that planned module rather than inventing a new home.
- **`vm/peephole.zig` already exists** (removal-only: pure-push+op_pop elision).
  Recur-loop fusion (v0 37.4 prelude) + compare-branch fusion (v0 37.3) extend
  the same compile-time `finalize` pass.
- The JIT (v0 37.4) is the only piece needing the cross-platform + ADR-layer
  discipline above; everything else is portable bytecode/runtime work.

## Measurement cadence (user-directed 2026-06-11 — keep iteration FAST)

Balance optimization throughput against test cost. Do NOT full-gate or
full-bench every iteration; do NOT bug the program for a perf change either.

- **Per optimization iteration**: confirm cljw-self improvement with a
  **focused quick bench only** — `bash bench/run_bench.sh --quick --bench=<name>`
  (3 runs / 1 warmup, low-noise). That is enough to see "did this get faster".
- **Do NOT compare against Python every iteration.** The lever's effect is
  already estimated; just accumulate the cljw-self speedups. Only once several
  wins have **solidified** do you run the FULL bench + the cross-language full
  bench (`bench/compare_langs.sh --cold`) and update the markdown
  (`bench/README.md` regenerate + `bench/RELEASE_METRICS.md` if shifted).
- **Commit gate = ONE smoke** (`bash test/run_all.sh --smoke <changed-step>`,
  background, don't block). ADR-0107: up to 5 smoke commits ride before a full
  gate is owed; batch the full gate at that ceiling / when wins solidify, not
  per optimization.
- **Correctness spot-check, not full gate**: a bench-driven change must not
  break behaviour. Spot-run the impact area — the changed e2e step's smoke +
  the targeted clj corpus (`scripts/clj_diff_sweep.sh`) + for any
  interpreter-frame / dispatch change, `CLJW_GC_TORTURE=1` on the changed path
  (the O-005/O-013 lesson). If the impact area is clean, continue; no full gate.
- **Solidify → heavy validation → markdown**: when a batch of speedups settles,
  run the full gate + full bench + cross-lang full bench once, regenerate the
  tables, commit. That is the only point the Python-comparison + README refresh
  is paid for.

## v0 artifacts to read (Step 1 of the campaign)

- `~/Documents/MyProducts/ClojureWasm/bench/history.yaml` — the full timing log.
- `…/.dev/optimizations.md` — v0's optimization catalog (what worked + why).
- `…/.dev/decisions.md` — D87 (JIT) and the VM-opt decisions.
- `…/ARCHITECTURE.md` — pipeline / Value repr / backends / GC / JIT layering.
- `…/src/engine/{vm/jit.zig, vm/vm.zig, compiler/, evaluator/tree_walk.zig}`.
- `…/git log` perf phases: 36.11 / 37.1 / 37.2 / 37.3 / 37.4 / Phase 37 / 79A.
