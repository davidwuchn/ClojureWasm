# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ `550ff3a3`+). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed).
  Full gate 351/351 + verify_projects 17/17 (2026-06-14, all validated). Build
  config UNIFIED (ADR-0133): every e2e/bench/probe uses `zig build -Dwasm
  -Doptimize=ReleaseSafe` — bare `zig build` = Debug and overwrites zig-out, so
  it is for hand experiments only.

- **First task on resume MUST be**: **D-431** — operationalise the F-014 / ADR-0136
  goal line's per-class completeness as a REAL gate (the DA-corrected mechanism =
  oracle-derived per-class method corpus). Step 1: verify the `clojure-corpus`
  method-frequency data exists in usable form (`docs/works/` / `00a_frequency_overview.md`);
  then build `test/diff/class_corpus/<Class>.txt` for String + Object first (most-used,
  currently `methods:`-bare), gate via the EXISTING `clj_diff_sweep.sh` +
  `check_corpus_regression.sh`. Big-bang per class (clj_diff_sweep.md Discipline 2).
- **Resume PRIORITY SEQUENCE** (so the goal + opinion-residuals resolve by
  `/continue` alone, finished-form-first): (1) D-431 completeness gate; (2) then
  pure-lib verification per F-014 clause 3 (grow `verified_projects/`, stop-chasing
  rule = blocker has a class_corpus home); (3) quality-floor drain (D-210 clj-parity
  / D-232 conformance / D-242-245). DEFERRED-DEEP, NOT until a consumer/window:
  D-430 (instaparse GLL parse divergence — NOT regex, terminals == clj), D-424
  (class-resolution seam, latent), D-432 (seq-key hash-by-identity residual, low-freq).

- **Directed work DONE (2026-06-14, comprehensively validated)**: (1) finished-form
  cleanup — the whole reify/instance-seq asymmetry class CLOSED: D-422 (count
  Counted-vs-walk + self-seq print segfault), D-423 (reify qualified protocol_remap),
  D-426 (reify equiv construction + keys/vals map-routing), D-427 (element-wise `=`
  for Sequential deftypes). (2) Java surface (D-425) complete. (3) The `*in*` /
  LispReader$StringReader reader subsystem (D-414 DISCHARGED) + qualified user-deftype
  resolution (D-428) + String.subSequence (D-429) — instaparse now LOADS + runs its
  grammar compiler into the GLL engine (blocked only at D-430). 5 libraries newly
  verified (finger-tree, flatland.ordered, data.generators, tools.cli + the 12 prior).

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

## Just landed (2026-06-14, on `main`) — cleanup + reader subsystem + instaparse chain

reify/instance-seq class CLOSED (D-422 count Counted-vs-walk + self-seq print;
D-423 reify qualified-remap; D-426 reify equiv ctor + keys/vals map-gate; D-427
element-wise `=` for Sequential deftypes, GC-rooted realize). `*in*` reader
subsystem (D-414): `*in*`+read-line+with-in-str, runtime/string_escape factor,
clojure.lang.LispReader$StringReader shim + java.util.LinkedList. Qualified
user-deftype resolution (D-428); String.subSequence (D-429). instaparse advanced
4 blockers → D-430 (deep GLL parse divergence, documented). 5 libs verified.
AD-031/032. Filed D-424/430 (open); D-414/421-429 discharged.

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-014** (scope goal line, user-owned) +
**ADR-0136** (its operationalisation) → `.dev/debt.yaml` (next: D-431 completeness
gate; open: D-418/424/430/432; discharged this session: D-414/421-429) →
for the experiment: `private/notes/p14-wasm-component-experiment.md` +
`private/20260613_handover_from_zwasm/handover_v2.md`. zwasm repo =
`~/Documents/MyProducts/zwasm_from_scratch/` (read-only; HEAD ≥ `33e0100c`).
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`).

## Stopped — user requested

User instruction (2026-06-14): "今引いたゴールと…意見についての残件的なやつが、
新たなクリアセッションからcontinueするだけで逐次解消していけるように…配線、参照
チェーン監査を再度行ってください。そしたら止めてください". Done: drew the scope
goal line (F-014 + ADR-0136, DA-corrected), then audited the resume wiring —
ref-integrity clean (check_debt_id_refs green; a stray comm hit was the
Unicode-version string UCD-16.0.0, not a debt ref), filed D-431 (completeness
gate) + D-432 (seq-key hash residual,
was buried in D-427), and rewired this handover's first-task + PRIORITY SEQUENCE
so a fresh `/continue` resolves the goal + residuals finished-form-first.
Resume per the Resume contract above (first = D-431).
