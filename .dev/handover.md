# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (see `git log`). All work happens on `main`; commit + `git
  push origin main` is the atomic Step 6 (`git push --force*` is deny-listed).
  Gate cadence (ADR-0107): per-commit **smoke** (background, don't block); batch
  the full gate ALONE (`timeout 900 bash test/run_all.sh --serial-e2e`) at the
  ≤5 ceiling / boundary. **Perf is measured ONLY on a Release binary via
  `scripts/perf.sh` / `bench/`, NEVER `time zig-out/bin/cljw` (Debug)** —
  `.claude/rules/perf_measure_release.md`.
- **First commit on resume MUST be: the performance-tuning campaign
  (ROADMAP §9.2.S), run continuously and autonomously — user-directed
  2026-06-11. Only an explicit user stop halts it (CLAUDE.md § The only stop);
  unit / boundary transitions roll straight into the next unit.** Three axes:
  **execution speed, startup speed, binary size.**
  1. **Build / confirm the experiment → measure → keep-or-revert loop first**:
     baseline with `scripts/perf.sh` (Release) + `bench/run_bench.sh` +
     `bench/compare_langs.sh`; make ONE change; re-measure; keep if faster, else
     `git` revert. **Measure the FOCUSED target only** — `bash bench/run_bench.sh
     --quick --bench=<name>` (3 runs / 1 warmup, low-noise); run the FULL suite
     (no `--bench`) only for regression once a real win lands, not every iteration.
     Each unit is its own commit (revert-friendly); log every
     speed-for-simplicity trade in [`.dev/optimizations.md`](./optimizations.md)
     (O-NNN SSOT) + a `// PERF:` marker; the naive form stays the F-011 contract
     (observably equivalent vs `clj`).
  2. **Then ROI-ordered units** (impact × frequency / effort · risk), bench-driven
     from the slowest / most-global spots. **Algorithmic-pathology vein is now
     largely mined** (O-007…O-013 landed 2026-06-11 — see Just landed). The
     remaining big lever is **per-element interpreter overhead** (D-133
     superinstruction / fusion): fib ~107 ns/call, map/filter ~150 ns/elem; the
     trace machinery (`calleeFrame`/`pushFrame`, macOS `__tlv_get_addr`) is
     ~7-14% but resists clean shaving (a frame-init opt is GC-UNSAFE — see the
     O-005 lesson below). That is F-010-deferred architecture; for unattended
     runs prefer continued algorithmic probing (probe lazy-seq / list inputs,
     not `.range`, to expose `nth`-in-loop O(n²)) over the JIT. **D-140 startup
     is a non-issue** — Release cold-start is ~5 ms, warm <1 ms (the old 0.48 s
     was Debug). binary-size axis: O-008 strip landed (3.39 MB).
  - **Do NOT touch zwasm** — it stays as a long-lived branch for the CFP.
    Optimize cljw's own Clojure processing only. Step-0 survey may reference cw v0
    (`~/Documents/MyProducts/ClojureWasm/`: `Meta.range` / `fusedReduce` /
    incremental-trie transients — re-derive cljw-appropriately per F-004, not
    copy), other reference clones, and web search.
  - This supersedes the §9.2.P clj-parity / Phase-A "resume here" markers for
    this session (user re-prioritization 2026-06-11).
- **Forbidden this session**: editing zwasm; `git push --force*`. Run
  continuously per CLAUDE.md § The only stop.

## Just landed — perf campaign 2026-06-11 (pushed to `main`)

Wins (O-NNN SSOT in `.dev/optimizations.md`, each clj-corpus-verified + `PERF:`
marked): **O-009 `reductions`** O(n²)→O(n) lazy JVM shape (103.68 s→0.04 s +
fixed infinite-seq & `reduced` latent bugs); **O-011 `map-indexed`/`keep-indexed`**
O(n²)→O(n) on lazy/list sources (4.6 s→0.02 s); **O-012 `string/join`** O(n²)→O(n)
(100k 3.16 s→0.07 s); **O-007 `(sort coll)`** native stable sort (0.39 s→~0 ms);
**O-010 `(sort-by f coll)`** native key sort (0.79 s→0.01 s); **O-008** strip
release binaries (3.93→3.39 MB).
- **Reverted (correctness > perf)**: **O-005** frame nil-init — GC UAF: the VM
  roots the WHOLE `callMethodImpl` `locals` slice, so an `undefined` tail is
  traced under torture → SIGSEGV. **O-013** concat right-nest — stack-overflowed
  `interleave` (deep 2-arg recursion). Both have regression tests + RETIRED
  ledger rows. **Lesson: `callMethodImpl.locals` is shared with the VM frame;
  any frame-init / nesting change must hold under `CLJW_GC_TORTURE` + deep
  recursion.**
- **CFP** (`private/clojure_conj_2026_cfp/`, USER-OWNED): SUBMISSION.md draft,
  paused on the user.

## Cold-start reading order (perf campaign)

handover → ROADMAP §9.2.S (campaign + resume D-163) → `.dev/optimizations.md`
(O-NNN SSOT) → `scripts/perf.sh` + `.claude/rules/perf_measure_release.md` (how to
measure) → `bench/run_bench.sh` / `bench/compare_langs.sh` (ROI from the slow rows)
→ cw v0 `~/Documents/MyProducts/ClojureWasm/` (perf precedent).
