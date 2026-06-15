# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT). **NORMAL PUSH MODE** (user 2026-06-15:
  local-accumulation LIFTED). After each unit's smoke-green commit, `git push origin
  main` immediately (Step 6). `build.zig.zon` `.zwasm` is **SHA-PINNED** to a pushed
  clojurewasm/zwasm commit (`#412966f7…` + content `.hash`, `lazy`) so others build
  reproducibly — NOT the local `../zwasm_from_scratch` path (advance-pin procedure: zwasm `docs/consuming_prerelease_zwasm.md`).
  Per-commit = smoke; `-Dwasm` now fetches zwasm from git (default build is
  zwasm-lazy, untouched). NOTE: reproducibility-for-others also needs read access to
  the (currently pre-tag) clojurewasm/zwasm repo — user's external action.

- **First task on resume**: **drain `.dev/debt.yaml` `active:` TOP-DOWN.** The
  2026-06-15 ledger audit re-ordered `active:` EASIEST-FIRST (quick-wins → PERF
  cluster → large) and split the never-closing trackers + defer-bucket into a new
  `standing:` section. **The loop is FULLY AUTONOMOUS — no open user-judgment items**
  (all reflected this session). Standing user decisions (durable: memory
  `debt-ledger-audit-decisions`):
  - **work order** = quick-wins (trivial/small) → then **perf 専念** (D-386 dispatch →
    narrow ARM64 JIT, beat-Python north-star); the `active:` order encodes this.
  - **future bucket** (broad JIT / CLJS→JS / C-FFI / gen-GC / virtual-threads /
    out-of-proc isolation / wasm structural-future) = **defer INDEFINITELY** — NEVER
    auto-start; lives in `standing:`.
  - **debt.yaml** = `active:`(drain easiest-first) / `standing:`(NOT drained) /
    `discharged:`. Self-select drain-units from `active:` ONLY; correctness/clj-parity
    floor outranks coverage.
  **First task on resume: open the PERF cluster — D-386 (per-instruction dispatch)
  → narrow ARM64 JIT, the beat-Python north-star.** The actionable clj-parity
  quick-wins are now drained: **D-321** (FileNotFoundException leaf Kind), **D-322**
  (classpath-aware REPL, all 3 entry paths), **D-314** (extend-via-metadata dispatch,
  ADR-0144) all discharged 2026-06-15. Explicit low-priority defers (NOT reflexive —
  reasons on each row, revisit if a real consumer hits them): **D-433** (exception
  str vs pr — user-confirmed LOW), **D-374** (top-level `(do …)` unroll — realistic
  `(ns …)`/separate-form code already works; only the `-e '(do (import) (use))'`
  bundle diverges), **D-319** (Object-extension fallback — current behaviour CORRECT,
  perf-cliff only, deferred-optimization envelope), **D-442/D-444** (concurrency —
  infra-gated `future-cancel` / non-deterministic `:volatile-mutable` race; do when a
  real workload appears). The remaining `active:` rows (D-327/338/343/348/353/376/413)
  carry unmet barriers (blocked-by / forward-looking security). So next = PERF: read
  `.dev/perf_v0_baseline.md` + memory `perf-campaign-roadmap-9-2-s` + D-386, measure
  via `scripts/perf.sh` (Release, never Debug).
  - **GUARDRAIL (user 2026-06-15, durable)**: do NOT defer under progress pressure.
    Re-evaluate every candidate-defer against finished-form / あるべき論. If unifying
    REDUCES a parity gap AND does not scatter the design, DO it even if laborious
    (D-317 was a wrongly-deferred parity gap this session — reversed + landed). Genuine
    defers are fine, but make the **do/don't EXPLICIT** with a reason — avoid vague
    "workload-gated" defer-residue (see the D-246/D-240 re-barriers for the shape).
  - **Reads: `.dev/project_facts.md` F-015 + ADR-0142 + ROADMAP §9.0 + debt.yaml header
    + `active:` top rows** + memory `debt-ledger-audit-decisions`. Discharging a row =
    MOVE to `discharged:` (don't inline-discharge), or let D-175 batch-relocate.

- **Last session landed (git log = SSOT, HEAD `01e700b5`, all pushed)** — clj-parity
  quick-wins drained + perf grounded: **D-321** (FileNotFoundException leaf Kind),
  **D-322** (classpath-aware REPL ×3 entry paths), **D-314** (+ADR-0144,
  extend-via-metadata dispatch) discharged; full gate **358/358**. Perf: **hyperfine
  installed** (was missing — bench prerequisite), fib baseline **29ms**, (b)
  poll-batching empirically ruled out (the D-386 row carries the grounding + the
  precise (a) op_top-inline UAF invariant + sub-steps).

  SAFETY: `clj` batches need `-J-Xmx2g` + bounded seqs; `zig build test` needs
  `-Dwasm` (memory `zig_build_test_needs_dwasm` — bare drops the bootstrap_core embed
  → ~7 false fails); name changed e2e steps to `--smoke`; new debt rows via Edit.
  **State**: near-complete (F-015); §9 gap-area model; zwasm SHA-pinned. Normal push.

- **Forbidden this session**: `git push --force*`; bare `zig build test` WITHOUT
  `-Dwasm` (false fails); bare `zig build` for scripted/probe (ADR-0133 — ReleaseSafe).

## Stopped — user requested

User instruction (2026-06-15): 「さて、キリの良いところで、次のクリアセッションから
continueだけで引き続き継続していけるだけの配線・参照チェーン監査をして止めてください。」
Done: the wiring / reference-chain audit is CLEAN — tree clean + HEAD `01e700b5` ==
origin/main (pushed); debt.yaml parses + no dup ids; `check_debt_id_refs` → "all cited
debt IDs resolve"; D-321/322/314 present in `discharged:`; ADR-0144 + `src/runtime/meta.zig`
+ the two new e2e scripts tracked; all 3 new e2e steps registered in run_all.sh; no
untracked non-ignored files. This stop applies to THIS session only; the next
`/continue` resumes the loop normally (delete this section on resume) — take the
**First task on resume** above (D-386 (a) op_top dispatch inline, the grounded focused
cycle; D-413/D-374 are clean smaller alternatives).

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** (the completion-grade posture — read
FIRST) → **`.dev/decisions/0142_*.md`** (the §9 gap-area reframe; supersedes the
old phase-queue model) → **ROADMAP §9.0** (the gap-area model + the
phase-number→gap-area redirect) → the chosen gap area's draining `.dev/debt.yaml`
rows. Track R (D-440) substantive arc is DONE; the loop self-selects the next
gap-area unit (CLAUDE.md § "When the active work unit completes"). clj oracle =
`~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`). SAFETY: bounded seqs
+ `-J-Xmx2g`; name changed e2e steps to `--smoke` (unnamed e2e are NOT run);
register new e2e in run_all.sh same-commit; new debt rows via Edit (quoted id),
NOT `yq +=` (yaml_ssot_yq.md Golden-rule #4).

