# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; HEAD ≈ `ec2ee67b`, may lag). **NORMAL
  PUSH MODE**: after each unit's smoke-green commit, `git push origin main`
  immediately (Step 6). `build.zig.zon` `.zwasm` is SHA-PINNED to a pushed
  clojurewasm/zwasm commit (`#412966f7…`, `lazy`) — not the local path.
  Per-commit = smoke; full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **regex_count** — the last & biggest open
  Python-loser. GOAL (user-affirmed 2026-06-15): beat Python on EVERY bench via
  Zig-backed equivalent-semantics impls (memory `perf-beat-python-every-bench`).
  **Current Python-losers (re-measured 2026-06-15, post-O-030/031/032/033):
  regex_count 1.74× + bigint_factorial 1.26×** — sieve + nested_update are now
  cljw-FASTER (CLOSED this session). regex first step = the **cross-lang
  equivalence audit** ADR-0145 mandates BEFORE engine work (cljw's own regex engine
  `src/runtime/regex/{compile,match}.zig`; `#"…"` literals compile once, the cost is
  the match-engine walk + per-match String alloc + re-seq lazy nodes). Then PROFILE
  (engine vs String-alloc vs lazy-seq split) before touching the engine. Reference
  impls clonable per user direction (`reference_clones.md` § Perf-reference):
  `openjdk24/` java.util.regex, clone CPython `sre` / RE2. Scoped in
  `private/notes/9.2.S-regex-count-lookahead.md`. **bigint** is DEFERRED (profiled:
  no cheap touchpoint — cost is the inherent std.math.big mul + per-step alloc, not
  dispatch; only lever is a BigInt-reduce-accumulator, involved + modest;
  `private/notes/9.2.S-bigint-factorial-lookahead.md`).
  - **JIT (D-133) re-sequenced LAST** (ADR-0145). **D-445** = fused-reduce 正しい姿
    (reduce path), open. **D-446** = arity-divergence audit (user-directed). **D-244 #4
    capstone** = gc_self_guard fabrication-site rooting (below).

- **Validation infra + the D-244 #4 gap**: alloc-driven GC torture
  (`CLJW_GC_TORTURE_ALLOC=N`) validates MID-ALLOC rooting; the O-032/O-033 producers
  are SAFEPOINT-torture-validated (the primary eval-reentry hazard) but ALLOC-torture
  is BLOCKED on a pre-existing fabrication-rooting bug: op_vector_literal/set/map
  folds + the `vector` builtin build a partial collection in an unrooted Zig local →
  mid-alloc collect sweeps it (`@memcpy alias` / `integer overflow`). `fromSlice`
  does NOT sidestep it (its `tail`→`newVector` intermediate is also unrooted →
  silent corruption — tried+reverted). PROPER FIX = wire `gc_self_guard`
  (GcHeap.pin/unpin exist; the per-fabrication-site set/clear is unwired) — an
  involved GC-infra capstone, own focused session;
  `private/notes/9.2.S-d244-4-alloc-torture-finding.md`. KEY LESSON: diff oracle
  (TreeWalk≡VM) is necessary but NOT sufficient; clj corpus + torture + direct probe
  are the backstops.

- **Forbidden this session**: `git push --force*`; bare `zig build test` WITHOUT
  `-Dwasm` (false fails — memory `zig_build_test_needs_dwasm`); bare `zig build`
  for scripted/probe (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Last landed (git log = SSOT; HEAD `3469c0f0`, all pushed)

**Perf campaign — 2 losers CLOSED + a broad call-system win this session:**
**O-030** fixnum mod/rem/quot intrinsic (sieve 1.40→1.23×) · **O-031** fixnum not=
intrinsic + the bootstrap re-cache for `.clj`-defined arith ops + fixing not='s
0-arg clj-divergence (`(not=)` now throws an arity error) — **sieve CLOSED** (cljw
0.96×) · **O-032** in-Zig chunk-map/filter producer — **chunked map/filter
2.16-2.5×** (reduceFn O-004's producer-side mirror; the closure-floor touchpoint —
the raw call path was already fast, the cost was the `.clj` chunk-arm loop) ·
**O-033** in-Zig update-in (3-arg vector path) — **nested_update CLOSED** (cljw
1.18×). All: diff oracle + clj corpus + CLJW_GC_TORTURE=1. Also: ADR-0146
filter-chain NO-GO (sieve is fn-call-bound, not depth-bound — measured+reverted).

SAFETY: `clj` batches need `-J-Xmx2g` + bounded seqs; `zig build test` needs
`-Dwasm`; name changed e2e steps to `--smoke`; new debt rows via Edit (quoted id,
not `yq +=`) AND in the **active:** list (not discharged — D-445 was misfiled, fixed).
**State**: near-complete (F-015); §9 gap-area model; zwasm SHA-pinned.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** (completion-grade posture) →
**`.dev/decisions/0142_*.md`** (§9 gap-area reframe) → **ROADMAP §9.0** → the
chosen perf unit's `.dev/debt.yaml` row (D-386 dispatch / D-133 JIT) +
`.dev/perf_v0_baseline.md` + memory `perf-campaign-roadmap-9-2-s`. clj oracle =
`~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`). The loop
self-selects the next perf unit (CLAUDE.md § "When the active work unit completes").
