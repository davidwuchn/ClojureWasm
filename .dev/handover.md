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

- **First task on resume MUST be**: continue the library-verification campaign —
  probe the next pure-Clojure candidate (ladder rung 7 `clj-yaml-pure`, or a new
  pure lib from `~/Documents/OSS/clojure-corpus/`); if it loads, add a
  `verified_projects/<lib>/` proof, else fix the bounded gap it surfaces. The
  user-directed cleanup + Java campaign + reader subsystem are COMPLETE. NOT the
  first task (deep/latent, see debt.yaml): D-430 (instaparse GLL parse divergence
  — an open-ended GLL-engine debug, NOT a regex gap — terminals compile+match ==
  clj), D-424 (class-resolution two-path seam, latent). Quality-floor tail
  (D-210/232/242-245) is the fallback if no tractable lib remains.

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

handover → `.dev/debt.yaml` (open: D-418 agent-race, D-424 class-resolution seam,
D-430 instaparse GLL; discharged this session: D-414/421-429) →
for the experiment: `private/notes/p14-wasm-component-experiment.md` +
`private/20260613_handover_from_zwasm/handover_v2.md`. zwasm repo =
`~/Documents/MyProducts/zwasm_from_scratch/` (read-only; HEAD ≥ `33e0100c`).
clj oracle = `~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`).

## Stopped — user requested

User instruction (2026-06-14): "キリの良いところで、現在地点の正直な残debtを
表示してとめてください。…アーキテクチャ…意見なども表示して". Honest open-debt
summary + architecture explanation + opinions were delivered in chat. Resume per
the Resume contract (next = library-verification probe; D-430 GLL deferred).
