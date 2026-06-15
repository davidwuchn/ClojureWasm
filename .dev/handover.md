# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: after each
  unit's smoke-green commit, `git push origin main` immediately (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`). Per-commit = smoke;
  full gate batches at ceiling / boundary / pre-tag.

- **First commit on resume MUST be**: **regex_count** — the last open Python-loser.
  GOAL (user 2026-06-15): beat Python on EVERY bench via Zig-backed
  equivalent-semantics impls (memory `perf-beat-python-every-bench`). Current losers:
  **regex_count 1.74× + bigint_factorial 1.26×** (sieve + nested_update CLOSED this
  session). The ADR-0145 cross-lang equivalence audit is DONE (GO): 48-golden
  `test/diff/clj_corpus/regex_equivalence.txt` committed = the F-011 lock.
  **The APPROACH = ADR-0147** (user: do it properly — "腰を据えて…工夫をしっかり
  入れ込む", not just barely-beat-Python). Stay Pike-NFA (ReDoS-immune, ADR-0031);
  incorporate the fast-regex techniques in STAGES, each equivalence-locked (corpus
  48/48 + diff oracle) + measured: **S1** seen-gen counter (`match.zig` `tryMatchAt`,
  45→41.5ms) + `rt/re-find-all` Zig prim backing `re-seq` (kills the ~10ms `.clj`
  layer); **S2** the literal/first-byte/class PREFILTER in `findFrom` (the
  beat-Python lever for `\d+`; borrow the SIMD byte-scan from `~/Documents/OSS/
  ezi-gex/src/engine/memmem.zig` + `backends/literal.zig`); **S3** the lazy DFA
  (ADR-0031's reserved `dfa.zig`; the "incorporate properly" goal — ezi-gex's
  `auto`/`dfa` is the blueprint; captures stay two-pass via the Pike VM). NO-GO:
  backtracking + machine-code JIT. **Read the refs DIRECTLY (no survey/DA fork) +
  measure-first** (ADR-0146 lesson + user pref; memory `direct-explore-fork-mechanical`).
  Refs: ADR-0147 + the audit note `private/notes/9.2.S-regex-equivalence-audit.md`,
  `ezi-gex` (cloned blueprint — 0.17-dev, won't compile on 0.16), burntsushi
  regex-internals, RE2. Parity gaps = **D-447**.
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
