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

- **zwasm CM-API COMPLETED 2026-06-13** (marker:
  `private/20260613_handover_from_zwasm/handover.md`, COMPLETED). All 6 cw
  requests landed at zwasm pin `5795c3d0` (branch zwasm-from-scratch): REQ-1
  unified `comp.open`→`Opened`, REQ-2 enum/variant/flags VALUE labels, REQ-3
  public `resolveFuncSig`/`WitType` (replaces the hand-rolled TypeCtx), REQ-4
  budget threading, REQ-5 `dropResource` (caveat: guest destructor traps,
  zwasm D-325, doesn't block), REQ-6 typed-invoke diagnostics.

- **First task on resume MUST be: adopt the new zwasm CM-API in the D-404
  component EXPERIMENT** (push-suppressed) per
  **`private/notes/p14-wasm-component-experiment.md`**. Mode = EXPLORATION:
  build.zig.zon flipped to relative-path `../zwasm_from_scratch` LOCALLY
  (local zwasm HEAD ≥ 5795c3d0; uncommitted; `git stash` it before any tracked
  commit), **do NOT push experimental artifacts**. The 手元 component.zig
  (Opened union + TypeCtx + lower/lift) is in a `git stash`
  ("wasm-component-experiment"); pop it and REWRITE to use `comp.open` +
  `resolveFuncSig` + label-carrying lift (enum→keyword, flags→set, variant→
  tagged map per ADR-0135). Breaking: ComponentValue.@"enum"/.flags are now
  structs. Probe: greet + typed_payload (working pre-adoption) + resource_counter.

  **Queue after (or interleaved when blocked)**: library conformance track-1
  (Maven-layout deps fix 345b1947 unblocked old contrib libs — re-probe);
  instaparse blocked (D-414 LispReader frontier); cuerdas (D-410); the
  host_interface S1 yaml/zig consolidation (D-415, focused small ADR).

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0 milestone) ~95% done. §9.16: 14.12 (component
  build) now UNBLOCKED (zwasm CM-API complete → the experiment adopts it);
  14.14 (exit-smoke + tag) user-deferred. Conformance: 17 corpora 100% golden
  (+ flatland.ordered, data.generators this session).

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

re-matcher/Matcher (`379c0e9e`) + ADR-0035 D9 refer-precedence; regex `(?x)`
+ `\<non-alnum>` escape + deps absolute-`:paths` (`c7845f53`); flatland.ordered
17/17 + deftype-set contains? (`35159f41`); Maven-layout git-dep resolution +
data.generators 20/20 (`345b1947`); bare `Counted` supertype (`6865b3c0`).
D-415 host_interface finished-form right-sized to S1 (per-section attribution
proven correct); D-414 instaparse/D-416 `(Object.)` frontiers filed.

## Cold-start reading order (resume)

handover → **`private/notes/p14-wasm-component-experiment.md`** (active task:
adopt the new zwasm CM-API) → `private/20260613_handover_from_zwasm/handover.md`
(the 6 COMPLETED APIs) → `.dev/decisions/0135_*.md` (WIT↔clj mapping) →
`.dev/debt.yaml` D-404. zwasm repo = `~/Documents/MyProducts/zwasm_from_scratch/`
(read-only here; HEAD ≥ pin 5795c3d0). clj oracle = `~/Documents/OSS/clojure/`
+ `clj -J-Xmx2g -M` (`timeout 60`, bound seqs).
