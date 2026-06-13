# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ `0c1a4e30`+). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed).
  Full-gate baseline 334 pass (2026-06-13); 1 known load-flaky (D-418, green
  standalone). Build config UNIFIED (ADR-0133): every e2e/bench/probe uses
  `zig build -Dwasm -Doptimize=ReleaseSafe` — bare `zig build` = Debug and
  Debug-overwrites zig-out, so it is for hand experiments only.

- **First task on resume MUST be**: the loop self-selects the next normal-dev
  unit (finished-form first, F-002) via Step 0.5 debt sweep → highest-value
  coverage/quality. Concrete standing candidates: the component experiment's
  next layer (require-as-namespace — see below; the user's active track), D-419
  (data.finger-tree method-under-foreign-interface-header, niche/D-415-adjacent),
  D-418 (agent send/await `#<promise>` race — needs an under-load reproducer),
  or a library-conformance re-probe.

- **Component experiment (push-suppressed, in `git stash@{0}`)**: zwasm REQ-7
  LANDED (pin `33e0100c`; channel `private/20260613_handover_from_zwasm/
  handover_v2.md` COMPLETED — root cause was input-buffer lifetime, not
  relocatability; the opened handle now owns its bytes). Instance caching is
  RE-LANDED + VALIDATED: `(wasm/load-component p)` + `(wasm/component-call h …)`
  — greet roundtrips across calls AND the resource chain works (ctor own-handle
  → method borrow: counter 5 → increment 6 → get 6). The D-404 / ADR-0135
  substrate is proven. Stashed to keep the tree clean (relative-path zon is
  push-forbidden). Next layer = require-as-namespace (one callable per export —
  needs a closure/Var-interning design) + dropResource GC-finaliser (D-325 also
  fixed at zwasm `65a760e2`). Re-land: pop the stash, flip zon relative, build
  `-Dwasm`. Notes: `private/notes/p14-wasm-component-experiment.md`.

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0 milestone) ~95%. Conformance: 17 corpora golden.

- **Forbidden this session**: pushing the component-experiment artifacts or a
  relative-path `build.zig.zon` (experiment is local-only); `git push --force*`;
  bare `zig build` for any scripted/probe path (ADR-0133).

## Just landed (2026-06-14, on `main`)

D-421 `(resolve 'Class)` → class value: extracted analyzeSymbol's class-value
arm into shared `analyzer.resolveClassValue`, called from `core.resolvePrim` on
Var/ns miss (DRY); unblocks `when-available` → numeric-tower `round`. D-420
math.numeric-tower fully closed: full-surface `verify.clj` green; floor/ceil-on-
ratio Long-vs-BigInt classified as AD-031 (F-005 narrow-when-fits). e2e
phase14_var_resolve 11-15. D-418 / D-419 still open.

## Cold-start reading order (resume)

handover → `.dev/debt.yaml` (D-418 / D-419 open; D-416 / D-417 / D-420 / D-421
discharged) →
for the experiment: `private/notes/p14-wasm-component-experiment.md` +
`private/20260613_handover_from_zwasm/handover_v2.md`. zwasm repo =
`~/Documents/MyProducts/zwasm_from_scratch/` (read-only; HEAD ≥ `33e0100c`).
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`).
