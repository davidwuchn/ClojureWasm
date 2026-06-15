# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **self-selected next quality unit** — the
  ADR-0147 regex arc is COMPLETE. S1 (O-034/O-035) + S2 (O-036 leading-byte prefilter) are
  WIRED + winning (regex_count CLOSED, ~tie/win vs Python; sparse ~27× via prefilter). S3
  (Alt-2 forward+reverse lazy DFA, `dfa.zig`) is BUILT + equivalence-locked but **NOT
  wired** — measurement (ADR-0147 § Stage 3 measured outcome) showed wiring REGRESSES perf
  (regex_count 17→23ms, sparse 0.05→0.47s) because the DFA forward scan lacks the S2
  prefilter + the reverse pass is uncached; the **S2-prefiltered Pike VM is the finished-
  form default matcher**. DFA = correct RESERVED engine, **D-449** (re-wire needs prefilter-
  integration + reverse-cache + a huge-input gate, else remove as dead code). Also fixed
  this session: the Pike-VM **leftmost-FIRST** bug (cut-on-match, `a|ab`→"a"; was leftmost-
  longest — a false-positive 2026-06-01 discharge); **D-448** = nested-empty-quantifier
  capture divergence (silently-wrong, deferred). regex correctness floor is solid (full
  corpus 3120/3120). GOAL (`perf-beat-python-every-bench`): regex CLOSED, bigint_factorial
  DEFERRED (no cheap touchpoint) → the "beat Python" targets are met/deferred; self-select
  the next unit (gap-area / debt floor, highest-value first — NEVER ask). NO-GO:
  backtracking + machine-code JIT. Parity gaps = **D-447**.
  - **bigint** DEFERRED (profiled: no cheap touchpoint — inherent std.math.big mul +
    per-step alloc, not dispatch; only lever = a BigInt-reduce-accumulator, involved;
    `private/notes/9.2.S-bigint-factorial-lookahead.md`).
  - **JIT (D-133)** re-sequenced LAST (ADR-0145). **D-445** fused-reduce 正しい姿
    (reduce path). **D-446** arity-divergence audit. **D-244 #4** capstone below.

- **Validation infra / D-244 #4 gap**: `CLJW_GC_TORTURE_ALLOC=N` validates MID-ALLOC
  rooting; the O-032/O-033 producers are SAFEPOINT-torture-validated (the primary
  hazard) but ALLOC-torture is BLOCKED on a pre-existing fabrication-rooting bug
  (op_vector_literal/set/map folds + the `vector` builtin build a partial collection
  in an unrooted Zig local → mid-alloc collect sweeps it). `fromSlice` does NOT
  sidestep it (tried+reverted). FIX = wire `gc_self_guard` (GcHeap.pin/unpin exist;
  per-site set/clear unwired) — an own-session GC-infra capstone;
  `private/notes/9.2.S-d244-4-alloc-torture-finding.md`. LESSON: diff oracle is
  necessary but NOT sufficient; clj corpus + torture + direct probe are the backstops.

- **Forbidden**: `git push --force*`; bare `zig build test` WITHOUT `-Dwasm` (false
  fails — memory `zig_build_test_needs_dwasm`); bare `zig build` for scripted/probe
  (ADR-0133 — ReleaseSafe). Measure perf only ReleaseSafe.

## Stopped — user requested

User instruction (2026-06-15): "次のクリアセッションから腰を据えて…zigライブラリを
直接使うのではなくこのシステムにうまく馴染ませるために拝借して高速性を（…工夫を
しっかり入れ込むのをゴールにする）、再度、情報伝達、配線、参照チェーン監査をして
止めて". Done: the regex perf APPROACH is elevated + made durable as **ADR-0147**
(borrow-and-adapt the prefilter + lazy-DFA into cljw's Pike-NFA, staged,
equivalence-locked; goal = incorporate the optimizations properly). `ezi-gex` cloned
as the Zig blueprint; **D-447** = regex parity gaps. **Resume = ADR-0147 Stage 1→3**
(read refs directly + measure-first, no survey/DA fork). Earlier this session the
regex fork was stopped + REVERTED (had only S1, 45→41.5ms) — tree clean, all pushed.
Re-audit verdict (info-transfer / wiring / reference-chain): RESOLVES — the durable
load-bearing direction now lives in TRACKED git (ADR-0147 + the 48-golden corpus +
D-447 + reference_clones.md ezi-gex entry), not only the gitignored audit note. A
fresh `/continue` reaches the regex approach via handover → ADR-0147 → the refs (a
fresh clone re-clones ezi-gex per reference_clones.md).

## Last landed (git log = SSOT; HEAD `fd2c9ca1`+, all pushed)

Perf: **O-030** mod/rem/quot intrinsic · **O-031** not= intrinsic + bootstrap
re-cache + not= 0-arg clj-divergence fix → **sieve CLOSED** (0.96×) · **O-032**
in-Zig chunk-map/filter producer → **map/filter 2.16-2.5×** (closure-floor
touchpoint) · **O-033** in-Zig update-in → **nested_update CLOSED** (1.18×). All
diff-oracle + clj-corpus + CLJW_GC_TORTURE=1. ADR-0146 filter-chain NO-GO (sieve is
fn-call-bound). SAFETY: `clj` needs `-J-Xmx2g` + bounded seqs; new debt rows via Edit
(quoted id) in the **active:** list. State: near-complete (F-015); §9 gap-area model.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** → **ADR-0142** (§9 gap-area) → **ROADMAP
§9.0** → the regex unit: **ADR-0147** + ADR-0031 + the audit note + the 48-golden
corpus + `ezi-gex`. memory `perf-beat-python-every-bench` + `perf-campaign-roadmap-9-2-s`
+ `direct-explore-fork-mechanical`. clj oracle = `clojure -J-Xmx2g -M -e` (timeout 60).
