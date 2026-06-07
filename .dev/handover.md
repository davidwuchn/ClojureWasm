# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. The 2026-06-07 sessions landed (newest last): D-304
  symbol metadata (ADR-0110) · D-306 collection-base deftype supertypes ·
  defn/fn `:pre`/`:post` → **core.cache FULLY LOADS** · D-307 IDeref/IPending ·
  **deps.edn `:mvn`-skip (ADR-0101 am.1)** · **`verified_projects/` mechanism** ·
  **D-309 deps.edn RUN-MODE `-M`/`-X` (ADR-0111)**: `-M:alias` clojure.main
  mini-grammar (`-m ns`→`-main`, `-e`, file, `-h`) + bare `-m` + `-X:alias`
  exec-fn (EDN-typed `:k v` merge); `verified_projects/` flipped to `-M:verify`.
  Full gate 278/0.
- **First commit on resume MUST be: grow `verified_projects/` by one library**
  using the `-M:verify` convention (deps.edn `:paths ["."]` + `:aliases {:verify
  {:main-opts ["-m" "verify"]}}`; verify.clj = `(ns verify …)` + `-main`). Next
  candidate: **clojure.data.zip** (loads, D-299 ns-leniency) or clojure.core.unify
  (both loads-rows in `docs/works/ladder.md`). NOTE data.generators is maven-layout
  (no deps.edn → src/main/clojure), deferred; tools.cli/data.json/data.csv are
  BUNDLED, skip. Add the dir, `bash scripts/verify_projects.sh <lib>`, commit on
  green; reconcile the ladder. A failure IS a coverage gap → fix root-cause
  (definition-derived, F-013) OR improve the deps.edn system (`:git`/`:local`, NOT
  Maven JAR). How-to: `verified_projects/README.md`. SSOT =
  `.dev/convergence_campaign.md` Stage 1.3.
- **deps.edn run-mode remainder = D-310** (ADR-0111 deferral): `*command-line-args*`
  binding + `-i`/`-r`/`--report`/`@resource`/mixed-init-before-main + `-T` tool
  mode. FINISHED-FORM = a `clojure.main`-shaped Clojure grammar fn (DA Alt 3),
  bootstrap-ordering-gated; current Zig source-synthesis migrates cleanly. Not
  blocking verified_projects.
- **Deferred — do NOT re-attempt the naive fix**: D-308 `(instance?
  clojure.lang.IDeref x)` needs a per-interface NATIVE-implementer membership
  table ∪ protocol satisfaction — NOT a `satisfies?` alias (the 2026-06-07 try
  was reverted: it broke `(instance? clojure.lang.IFn :kw)`→true). ADR-level,
  sibling of D-293. · reify protocol_remap (D-280 residual: expandReify lacks the
  rewriteProtocolRemap path) · D-288 deftype `^:volatile-mutable`+set! · D-305
  builtin var :arglists/:doc table (Slice 3). These block core.memoize's deeper
  load (cache loads; memoize advances :36→:67); NOT blocking verified_projects.
- **⚠ USER must act (time-sensitive, NOT AI-doable)**: see
  `private/clojure_conj_2026_cfp/archive/DEFERRED_USER_ACTIONS.md` — (1) Sessionize submit
  by 6/13; (2) v0.1.0 tag/Release + make `cw-from-scratch` default branch;
  (3) edge-demo CRUD `git push` + `fly deploy`.
- **Forbidden**: the 3 USER actions above (credential/product — safety-blocked);
  editing `.claude/rules/*` (permission-blocked → surface as carry-over); the
  naive D-308 `satisfies?`-rewrite; pinning an in-progress zwasm v2 state/tag
  (F-001: v2 ONLY from `zwasm-from-scratch`); trusting `~/Documents/OSS/zig`.

## Just landed (2026-06-07, git log = SSOT)

- **D-309 deps.edn run modes `-M`/`-X` (ADR-0111)**. In-process clojure.main
  grammar (cljw is JVM-less, no second-process). `-M[:alias]` = alias `:main-opts`
  ++ user args (APPEND); `-m ns`→`(requiring-resolve 'ns/-main)`+`(-main args)`,
  `-e` eval+print, bare file load, `-h`; bare top-level `-m` too. `-X[:alias]
  [ns/fn] [:k v]` = `:exec-fn` + `:exec-args` merged under CLI `:k v` (EDN-typed
  via `quote`d data maps; result not printed). New `src/app/deps/run_mode.zig`
  synthesizes a Clojure form → `runner.runSource(print_results=false)`. parse.zig
  Alias gains main_opts/exec_fn/exec_args. 7-case e2e phase14_deps_run_mode. v0's
  3 gaps fixed (args→-main, append, EDN coercion). DA Alt 2/Alt 3 in ADR-0111;
  source-synthesis kept on F-009 (thin Zig; clojure.main is Clojure), Alt 3 = D-310.
  `verified_projects/` (medley/data.priority-map/math.combinatorics/core.cache,
  4/4 green) flipped to `cljw -M:verify`.
- **bench note (user)**: gate bench_regression flags binary_size 2.5x (locked
  1.13MB → 2.86MB) + others — non-blocking; pre-existing project-wide drift (stale
  locked baseline, Phase 6→14), not the ~300-line run_mode. A bench-lock re-take
  may be warranted (user judgement).

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min;
  -P8 over-runs under load). Doc-only / verified_projects-only = no gate. Never
  poll a bg gate.
- `verified_projects` sweep + clj-diff probes are NETWORK / many-`cljw` — never
  run concurrently with the gate (contends with perf-threshold steps).
- clj-diff harness = `scripts/clj_diff_sweep.sh`; per-expr classify. `clj -M -e`
  → `timeout 20` + bound infinite seqs. Speed ONLY via `scripts/perf.sh`.
  Edit/Write TRANSCODES non-ASCII (splice via python). Default backend = VM (F-012).

## Cold-start reading order (tracked-only)

handover → **`.dev/convergence_campaign.md`** (driving SSOT; Stage 1.3 =
verified_projects) → **`verified_projects/README.md`** (the lib-load method) →
`docs/works/ladder.md` (ranked candidates) + `.dev/debt.yaml` + `compat_tiers.yaml`
→ `.dev/decisions/0101_deps_git_fetch.md` (+ amendment 1) → `.dev/project_facts.md`
(F-013/F-010/F-002) → CLAUDE.md (§ Project spirit + The only stop) →
`.dev/principle.md`.
