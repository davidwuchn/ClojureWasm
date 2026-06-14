# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT). **PHASE MODE = LOCAL ACCUMULATION
  (NO push), wasm = RELATIVE-path zon** — user override 2026-06-14. Commit each
  unit locally; do NOT `git push` (ignore the push reminders this phase); keep
  `build.zig.zon` `.zwasm = .{ .path = "../zwasm_from_scratch" }` (push-forbidden;
  the local zwasm HEAD has REQ-7). SSOT: memory `local-accumulation-sweep-phase`
  + `.dev/sweep_plan.md` § Phase mode. Per-commit = smoke (default build is
  zwasm-lazy-safe); wasm work also runs `-Dwasm`.

- **First task on resume MUST be**: **Track D D1 — seq-as-map-KEY content hash
  (D-432 + D-408), Option A** (sweep_plan.md § Track D — the user-directed
  2026-06-14 divergence-burden queue; READ IT). Survey done
  (`private/notes/p14-seq-key-hash-survey.md`): make the key-hash path rt-aware via
  the existing ADR-0129 `current_env` ambient threadlocal; realize lazy/range/
  Sequential-instance keys → `seqHash`. First red: `(get {(map inc [0 1 2]) :x}
  '(1 2 3))` → `:x`. Then Track D D2 (D-232/AD-029 frame accessor, post-M), then
  D3 (AD-018 volatile, GATED on Phase 15). #2/#5 were RESOLVED by the audit (no
  re-chase). Track S/W per sweep_plan after Track D.

- **Track C DONE (ADR-0138, steps 1-3, this session — LOCAL commits)**: `text_io.zig`
  durable Writer VALUE (`.stdout`/`.stderr`/`.string`, fqcn "Writer") + Reader VALUE
  (fqcn "Reader", `?u21` codepoint pushback: `.read`/`.peek`/`.unread`/`.readLine`).
  `*out*`/`*err*` roots → writer values; `*in*` (`with-in-str`) → text_io Reader;
  `lispStringReader` folded in. `emitToStdout` pushes to bound `*out*`; `with-out-str`
  = defmacro over `binding`; nREPL capture rebinds via threadlocal BindingFrame.
  DELETED: sentinel + `out_capture` + `out_writer_method.zig` + consult sites +
  native with-out-str macro + host_stream's lispStringReader. host_stream stays the
  file BufferedReader/Writer (distinct from text_io — JVM class-family faithful).
  Discharges D-436(b); supersedes D-434; folds D-414 shims. D-435 (diff-oracle
  full-runtime gap) stays open on the D-436 epic. e2e text_writer(9)+text_reader(6).

- **Track W (wasm north-star, F-014.4) — W0 RE-LANDED this session**: the
  instance-caching component work is un-stashed (relative zon, local-only):
  `(wasm/load-component p)` + `(wasm/component-call h …)` + component-exports/invoke;
  `-Dwasm` builds green against the REQ-7 zwasm. Next = W1 enrich (require-as-
  namespace: one Var per export; dropResource GC-finaliser D-325). [D-404/ADR-0135;
  zwasm handover `private/20260613_handover_from_zwasm/handover_v2.md` COMPLETED]

- **D-431 per-class completeness CLOSED** (the prior directed task — DONE this
  session): mechanism wired + **18 built+deterministic+touched classes** corpus'd
  (String/Object/Throwable/Pattern/Matcher/Math/ArrayList/HashMap/StringBuilder/
  Long/Integer/Double/Boolean/Character/UUID/Random/URI/Date), gaps fixed same-cycle.
  Remaining is NOT more of this sweep: the over-claimed unbuilt surfaces (java.time
  D-105/D-243, BigDecimal, Arrays) are feature-builds; the ADR-0137 sharpenings
  (generated `methods:` index + mechanical lib stop-chasing) are the residual. See
  `test/diff/class_corpus/README.md` for the full map + the over-claim finding.
- **Prior-session landings (git log is the SSOT)**: reify/instance-seq asymmetry
  class (D-422/423/426/427), Java surface D-425, the `*in*`/LispReader$StringReader
  reader subsystem (D-414) + D-428/429. This session: D-431 (above) + D-433/D-434
  filed. Discharged: D-414/421-429; open: D-418/424/430/432/433/434.

  SAFETY: every `clj` oracle batch needs `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit.

  **State**: Phase 14 (v0.1.0 milestone) ~95%. Conformance: 17 corpora golden.

- **Forbidden this session**: pushing the component-experiment artifacts or a
  relative-path `build.zig.zon` (experiment is local-only); `git push --force*`;
  bare `zig build` for any scripted/probe path (ADR-0133).

## Stopped — user requested

User instruction (2026-06-14): 「それらは #1〜#5すべて対応したいです。…今の
取り組みのあとか、途中でも、continueするだけで具体的に取り組めるよう、配線・
参照チェーンを監査して止めてください…取り組みやすい順番に並べて、良い配線を」.
Done: audited the 2026-06-14 chat's divergence-burden list (#1–#5) against the
SSOTs — found **#2 (`+'`/`*'`, D-260) and #5 (VM-default, D-196) ALREADY
RESOLVED**, **#4 (AD-018 volatile) GATED on Phase 15 concurrency** — and wired the
actionable, ease-ordered queue into `sweep_plan.md § Track D` (D1 → D2 → D3) with
grounded reads + self-locating debt cross-refs (D-432/D-408). Resume = Track D D1.
The directive applied to THIS session; the next `/continue` resumes the loop
normally (delete this section on resume per handover_framing).

## Cold-start reading order (resume)

handover → **`.dev/sweep_plan.md` § Track D** (the resume queue D1→D2→D3) →
`private/notes/p14-seq-key-hash-survey.md` (D1 survey) → `.dev/debt.yaml`
(D-432/D-408 [D1], D-232 [D2], AD-018/D-288 [D3]) → `.dev/accepted_divergences.yaml`
(AD-008/018/024/029 — the kept/gated divergences) + `.dev/project_facts.md` F-014 +
ADR-0137/0129. clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M`
(`timeout 60`). SAFETY: bounded seqs + register new e2e in run_all.sh same-commit.
