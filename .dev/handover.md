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

- **First task on resume MUST be: the ADR-0135 Wasm-component-as-namespace
  EXPERIMENT (D-404, now UNBLOCKING)** — the north-star differentiator, opened
  by the user 2026-06-13: zwasm's embedding API is ready except
  interface-internal function enumeration (zwasm ADR-0184, lands next zwasm
  session). Full wiring + the zwasm-side report verbatim + step plan:
  **`private/notes/p14-wasm-component-experiment.md`**. Mode = EXPLORATION
  (exploration_vs_done.md): flip build.zig.zon to relative-path
  `../zwasm_from_scratch` LOCALLY (uncommitted; `git stash` it before any
  tracked landing), experiment in private/ scratch, **do NOT push experimental
  artifacts**. Start with: design / EDN↔WIT mapping / require-macro skeleton
  against introspect + typed invoke + resources; the enumeration-dependent
  wiring waits for zwasm ADR-0184 landed (check the zwasm repo's git log).
  Tracked landings resume the normal gate + atomic push once stable AND the
  zon is back on a tag pin.

  **Queue after (or interleaved when blocked on zwasm)**: re-matcher +
  java.util.regex.Matcher host_instance — design + oracle table pre-laid in
  `private/notes/p14-instaparse-campaign.md` (incl. the StringBuilder
  int-capacity-ctor bug Segment.toString hits); then instaparse end-to-end →
  verified_projects corpus; flatland.ordered corpus registration; cuerdas
  blocked on D-410.

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

## Stopped — user requested

User instruction (2026-06-13): 「週次 rate limit が近いので、次のクリア
セッションが /continue だけで継続できるよう配線・参照チェーンを監査して停止」
+ 同日追記でベンチ再ベースライン実行と component 実験の配線を指示。Wiring
audited: Resume contract above; experiment wiring in
`private/notes/p14-wasm-component-experiment.md`; debt rows
D-404 (UNBLOCKING) / D-411 (discharged) / D-238 (LANDED) synced; bench
baseline committed. Resume = `/continue` (this section is history — the next
session deletes it per handover_framing.md).

## Cold-start reading order (resume)

handover → **`private/notes/p14-wasm-component-experiment.md`** (the active
experiment wiring) → `.dev/decisions/0135_*.md` (WIT↔clj mapping, FROZEN) →
`.dev/debt.yaml` D-404 → (queue) `private/notes/p14-instaparse-campaign.md`.
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`,
bound seqs); zwasm repo = `~/Documents/MyProducts/zwasm_from_scratch/`
(read-only here; ADR-0184 landing check via its git log).
