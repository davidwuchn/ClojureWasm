# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT; ≈ `4f7cb796`+). All work on `main`;
  commit + `git push origin main` is the atomic Step 6 (`--force*` deny-listed).
  Full gate 351/351 + verify_projects 19/19 (2026-06-14, all validated; data.json
  + data.csv newly verified). Build config UNIFIED (ADR-0133): every e2e/bench/probe
  uses `zig build -Dwasm -Doptimize=ReleaseSafe` — bare `zig build` = Debug and
  overwrites zig-out, so it is for hand experiments only.

- **First task on resume MUST be**: **D-434** — the `*out*` writer-interop gap.
  cljw's `*out*`/`*err*` root is the keyword SENTINEL `:clojure.core/stdout`, not a
  Writer, so `(.write *out* s)` / `.append` / `.flush` fail (`.write` on a Keyword) —
  blocking any lib that writes to `*out*` via the Java Writer interface (surfaced by
  clojure.data.csv `write-csv` to `*out*`; likely clojure.pprint too). Fix is
  cross-zone (dot-call dispatch = Layer-1 eval; emitToStdout + the `out_capture`
  threadlocal = Layer-2 core.zig): relocate `out_capture` to an rt field + add a
  Layer-1 dot-call arm that routes `.write/.append/.flush` on the *out*/*err*
  sentinel to rt.out_capture→rt.stdout. ADR-level (DA fork) — the sentinel +
  emitToStdout precedence (core.zig:740) is deliberate. Pairs with D-105 (time/io
  build-out) + the pprint writer surface.

- **D-431 per-class completeness CLOSED** (the prior directed task — DONE this
  session): mechanism wired + **18 built+deterministic+touched classes** corpus'd
  (String/Object/Throwable/Pattern/Matcher/Math/ArrayList/HashMap/StringBuilder/
  Long/Integer/Double/Boolean/Character/UUID/Random/URI/Date), gaps fixed same-cycle.
  Remaining is NOT more of this sweep: the over-claimed unbuilt surfaces (java.time
  D-105/D-243, BigDecimal, Arrays) are feature-builds; the ADR-0137 sharpenings
  (generated `methods:` index + mechanical lib stop-chasing) are the residual. See
  `test/diff/class_corpus/README.md` for the full map + the over-claim finding.
- **Resume PRIORITY SEQUENCE** (finished-form-first): (1) D-431 completeness gate
  — **per-class coverage CLOSED** (18 classes); residual = the ADR-0137 sharpenings
  (generated `methods:` index + mechanical lib stop-chasing) + feature-builds for
  the over-claimed classes. (2) pure-lib verification (F-014 clause 3) — **all
  LOCALLY-available org.clojure pure libs now verified** (data.json + data.csv
  added; sweep 19/19); the rest need network fetches or feature-builds (D-105 time,
  D-434 *out*, BreakIterator for cuerdas). (3) quality-floor drain — common surface
  confirmed clj-parity this session (host classes + clojure.string + set/walk/edn,
  modulo AD-001 set-order); the deep campaigns remain (D-242-245 concurrency/GC,
  D-232 validation). DEFERRED-DEEP, NOT until a consumer/window: D-430 (instaparse
  GLL parse divergence — NOT regex), D-424 (class-resolution seam), D-432 (seq-key
  hash residual), D-433 (exception str/pr one-liner).

- **Prior-session landings (git log is the SSOT)**: reify/instance-seq asymmetry
  class (D-422/423/426/427), Java surface D-425, the `*in*`/LispReader$StringReader
  reader subsystem (D-414) + D-428/429. This session: D-431 (above) + D-433/D-434
  filed. Discharged: D-414/421-429; open: D-418/424/430/432/433/434.

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
**ADR-0137** (its operationalisation; 0136 = sibling host-frontier ADR) → `.dev/debt.yaml` (next: D-431 completeness
gate; open: D-418/424/430/432; discharged this session: D-414/421-429) →
for the experiment: `private/notes/p14-wasm-component-experiment.md` +
`private/20260613_handover_from_zwasm/handover_v2.md`. zwasm repo =
`~/Documents/MyProducts/zwasm_from_scratch/` (read-only; HEAD ≥ `33e0100c`).
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`).
