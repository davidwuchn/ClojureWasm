# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ 9e802816+). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed)
  — EXCEPT the component experiment below, which is push-suppressed by user
  directive. Full gate green 334/0 (2026-06-13). Build config is UNIFIED
  (ADR-0133 Rev 1+2): every e2e/bench/perf builder + manual probe uses
  `zig build -Dwasm -Doptimize=ReleaseSafe` (bare `zig build` = hand
  experiments only; it Debug-overwrites zig-out). Bench re-baselined under the
  unified config (bench/cross-lang-latest.yaml, 39 benches; D-411 discharged).

- **zwasm-watch FIRED 2026-06-13**: the readiness predicate is satisfied —
  zwasm ADR-0184 Implemented (zwasm `8579285e`) AND `exportedFuncs`
  interface-nested enumeration landed + CWFS-closed (`af112e9a`/`475fba54`).
  Per the user's second directive the loop switched to the experiment.

- **First task on resume MUST be: the D-404 ADR-0135
  Wasm-component-as-namespace EXPERIMENT** per
  **`private/notes/p14-wasm-component-experiment.md`** (full wiring + step
  plan). Mode = EXPLORATION (exploration_vs_done.md): flip build.zig.zon to
  relative-path `../zwasm_from_scratch` LOCALLY (uncommitted; `git stash` it
  before any tracked landing), experiment in private/ scratch, **do NOT push
  experimental artifacts**. Steps: zon flip build check → introspect a zwasm
  fixture component → minimal lift/lower roundtrip → import-component Var
  intern skeleton. Tracked landings resume the normal gate + atomic push once
  stable AND the zon is back on a tag pin.

  **Queue after (or interleaved when blocked)**: instaparse end-to-end —
  re-matcher LANDED (`379c0e9e`, e2e phase14_re_matcher.sh green; refer
  override per ADR-0035 D9 third amendment); next blocker = cljw's require
  resolver ignores deps.edn `:paths` dirs for a probe project
  (`Could not locate 'instaparse.core'` — see
  `private/notes/p14-instaparse-campaign.md`); then verified_projects corpus;
  flatland.ordered corpus registration; cuerdas blocked on D-410.

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0 milestone) ~95% done. Both open §9.16 rows
  BLOCKED — 14.12 (component build, zwasm-CM-gated → D-404, now the active
  experiment) + 14.14 (exit-smoke + tag, user-deferred); operate in
  §1.5/quality-loop mode. Conformance ladder: 15 corpora 100% golden.

  **Paused (not abandoned)**: the §9.2.S perf campaign — resume ONLY on
  explicit user direction; state in `.dev/perf_v0_baseline.md` +
  `.dev/perf_campaign_essence.md`. NOTE for it: edn_roundtrip drifted
  ~23→~31ms between 2026-06-11 and 06-13 in BOTH build configs (real
  post-06-11 code change, not -Dwasm) — a lead worth tracing when perf resumes.

- **Forbidden this session**: pushing the component-experiment artifacts or a
  relative-path build.zig.zon (user-directed: experiment locally first);
  re-opening the §9.2.S perf campaign as the resume DEFAULT; editing zwasm
  except via the F-001 finding-handling policy; `git push --force*`; bare
  `zig build` for any scripted/probe path (ADR-0133 Rev).

## Just landed (2026-06-13, on `main`)

Build-config unification (ADR-0133 Rev 1+2): 310 e2e fallbacks + 9 bench/perf
builders → `-Dwasm -Doptimize=ReleaseSafe`; bench cw column re-baselined
(A/B: -Dwasm ~cost-free). instaparse substrate batch (d6c84985: *out*/*err*
D-238 LANDED, IObj/IMeta, Character statics). Earlier same day: D-405 harness
15 corpora, ADR-0136 boundary, D-407 proofs, Unicode D-057/D-409.

## Cold-start reading order (resume)

handover → **`private/notes/p14-instaparse-campaign.md`** (the active task:
re-matcher design + oracle table) → (when zwasm-watch fires)
`private/notes/p14-wasm-component-experiment.md` + `.dev/decisions/0135_*.md`
(WIT↔clj mapping, FROZEN) + `.dev/debt.yaml` D-404.
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`,
bound seqs); zwasm repo = `~/Documents/MyProducts/zwasm_from_scratch/`
(read-only here; readiness check via its git log per the watch predicate).
