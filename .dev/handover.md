# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (host-interface substrate + prefer-method fn + edge-doc
  positioning fixes + a reference-chain audit, all pushed). Gate cadence: per-commit
  **smoke** (`bash test/run_all.sh --smoke <step>`); **batch the full gate**; verify
  manual probes on a **ReleaseSafe** binary (`zig build -Doptimize=ReleaseSafe
  -Dcpu=baseline`), not Debug.
- **First on resume MUST be: D-373 in FINISHED-FORM** (user-directed 2026-06-10 —
  NOT the workaround). **Read `private/notes/D373-macros-that-should-be-fns.md`
  FIRST** (the full design + clj-comparison audit + edge cases + DA-fork brief).
  Summary: `instance?` is a cljw MACRO (auto-quotes the class symbol) so it can't be
  passed higher-order — `(condp instance? obj Map$Entry …)` (ordered.map) evals it to
  nil. Finished form = complete the class-symbol-as-value surface (ONE
  `class_name.isKnown`-driven analyzer arm, analyzer.zig:609-674, replacing the
  scattered Object/Number/IFn/opaque arms) + **UNIFY with D-293's classDescriptor**
  (rename rt.exceptionDescriptor → kind-tagged classDescriptor; 9 sites / 3 files) +
  make `instance?` a real fn (drop expandInstanceQ). Map$Entry = a 1-line FQCN_MAP
  add. The sibling `prefer-method` was the trivial half (LANDED). spike-first
  (ADR-0089) + DA-fork (depth-3). Verify the FULL ordered.map chain after.
- **THEN FREEZE** (user-directed): once D-373 lands, do **NOT** self-select the next
  F-010 unit — stop and wait for an explicit human go. The loop's usual "self-select
  + keep going" is suspended for one unit by this directive (see § Stopped below).
- **Forbidden**: pushing to `main`. The fly demos (D-362) are DONE + live.

## Just landed

- **Host-interface convergence substrate** (the F-010/F-013 deftype-load path for the
  196 corpus libs declaring clojure.lang.* supertypes): **D-365 residual** (serializer
  CHUNK completeness gate), **D-286 / ADR-0102 am1** (editable/transient family +
  D-286b sectionNeedsRemap guard), **ADR-0127 / D-370** (`print-method` multimethod,
  A2 writer + B2 consult), **D-371** (`.valAt`/`.cons`/… on native colls → clojure.core),
  **D-372 / ADR-0102 am2** (map-side aliases + valAt; java.util-method grouping
  accept-and-dropped, AD-027). `(ordered-set 3 1 2 1)` → `#ordered/set (3 1 2)` (full);
  ordered.map parses past the ENTIRE host-interface surface to D-373 (a class/instance?
  gap — a DIFFERENT subsystem). Unlocks the 15+ data-structure libs (finger-tree/
  core.cache/rrb-vector/avl/priority-map/int-map/gvec).
- **prefer-method → fn** (D-373 macro→fn audit; the trivial sibling of instance?).
- **Edge-positioning doc fixes** (CFP): docs/landscape.md + docs/works/demos.md drop
  edge/serverless-as-current-strength wording (FIX_DOCS git-tracked subset). NOTE:
  FIX_DOCS §7 binary-size claim is wrong — landscape "~2 MB" MATCHES the
  RELEASE_METRICS SSOT (default cljw ReleaseSafe stripped 2.24 MB); 4.3 MB is the
  -Dwasm demo build. Left ~2 MB unchanged (honest).
- **Reference-chain audit** (this turn): removed a duplicate D-292 row (the open copy
  of the already-DISCHARGED multi-protocol-extend-type debt); corrected D-373's barrier
  (was a stale type-hint mis-diagnosis) + wired it to D-293 + the design note.

## Follow-ups tracked

D-369 (transient dispatch, off critical path) · D-238 (bindable `*out*`) · D-293
(classDescriptor unify — D-373's target) · D-275 slice2 / D-276 (class-value markers).
quality_floor rows = the standing correctness-first drain.

## Cold-start reading order

handover → `private/notes/D373-macros-that-should-be-fns.md` (D-373 finished-form
design, READ FIRST) → `.dev/debt.yaml` D-373 + D-293 → CLAUDE.md § Autonomous Workflow.

## Stopped — user requested

User instruction (2026-06-10, verbatim): 「クリアセッションから続行 D-373 を
finished-form で続けて、そこでしばらく freeze（人間が明示するまで進めない）という予定で、
配線・参照チェーンを監査して止めてください。」
→ Audit done (this turn). Plan: a CLEARED session resumes **D-373 in finished-form**
(read the design note first); **after D-373 lands, FREEZE** — do not self-select the
next unit, wait for an explicit human go. This directive applies until the human lifts
it; it is the one sanctioned suspension of the loop's self-select rule.
