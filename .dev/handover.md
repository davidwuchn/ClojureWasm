# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; HEAD ≈ `ec2ee67b`, may lag). **NORMAL
  PUSH MODE**: after each unit's smoke-green commit, `git push origin main`
  immediately (Step 6). `build.zig.zon` `.zwasm` is SHA-PINNED to a pushed
  clojurewasm/zwasm commit (`#412966f7…`, `lazy`) — not the local path.
  Per-commit = smoke; full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: the perf campaign's **3-loser runtime
  campaign — sieve first** (ADR-0145, the JIT go/no-go decision). sieve is ~1.5×
  behind Python; v0 won it with **filter-chain collapsing / fused-reduce** (24C.7,
  103×) — a cross-platform, no-machine-code runtime lever. Step 0 survey the lazy
  `filter`/`first`/`rest` walk hot path (`src/lang/clj/clojure/core.clj` filter +
  the lazy-seq machinery; cross-ref O-004 chunked-seq + O-023 fused-reduce); the
  fix is GC-rooting-sensitive (O-005/O-013 class) → torture-gate with
  `CLJW_GC_TORTURE` + `CLJW_GC_TORTURE_ALLOC`. Then nested_update (update-in/assoc-in
  Zig builtins) then regex_count (after a cross-lang equivalence audit). Validate
  each: diff oracle + `clj` corpus (F-011) + bench re-measure (hyperfine ReleaseSafe).
  - **JIT (D-133) is re-sequenced LAST** (ADR-0145): `04_arith_loop` already beats
    Python 1.87× (cold + compute), so the JIT is v0-parity-only at the project's
    highest cost/risk; it touches none of the 3 losers. Re-open only when its ROI
    predicate fires (a hot loop the runtime levers can't reach, OR losers closed,
    OR user re-affirms). Do NOT open the executable-memory/codegen surface now.
  - **SKIP D-386 sub-step 2** (op_top register hoist): LOW-ROI (LOAD-only ~1% noise)
    + blocked on D-244 #4 `gc_self_guard` fabrication rooting. Details in D-386.

- **New this session — validation infra**: alloc-driven GC torture
  (`CLJW_GC_TORTURE_ALLOC=N`, inert-by-default) forces a collect inside `gc.alloc`
  so MID-OP rooting gaps surface deterministically. It already caught a real latent
  gap (`[1 2 3]` panics @memcpy-alias — op_vector_literal's partial is unrooted;
  D-244 #4 work, independent of op_top). Pure-dispatch (fib/tak/arith/str) PASSES.
  Use it when touching any alloc-site rooting (audit: run it over the suite).

- **Forbidden this session**: `git push --force*`; bare `zig build test` WITHOUT
  `-Dwasm` (false fails — memory `zig_build_test_needs_dwasm`); bare `zig build`
  for scripted/probe (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Last landed (git log = SSOT; HEAD `ec2ee67b`, all pushed)

Perf dispatch + GC-validation arc: **O-028** (ip→loop register, fib 536→472) +
**O-029** (alloc-free fixnum arith fast path — `fastBinaryFixnum` returns null on
i48-overflow → slow path; fib 472→420; +the sub-step-2 prerequisite) + the
**alloc-driven GC torture** infra (D-386 / D-244 #4 unblock tool; found the
op_vector_literal rooting gap on first run). Smoke green each commit.

SAFETY: `clj` batches need `-J-Xmx2g` + bounded seqs; `zig build test` needs
`-Dwasm`; name changed e2e steps to `--smoke`; new debt rows via Edit (quoted id,
not `yq +=`). **State**: near-complete (F-015); §9 gap-area model; zwasm SHA-pinned.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** (completion-grade posture) →
**`.dev/decisions/0142_*.md`** (§9 gap-area reframe) → **ROADMAP §9.0** → the
chosen perf unit's `.dev/debt.yaml` row (D-386 dispatch / D-133 JIT) +
`.dev/perf_v0_baseline.md` + memory `perf-campaign-roadmap-9-2-s`. clj oracle =
`~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`). The loop
self-selects the next perf unit (CLAUDE.md § "When the active work unit completes").
