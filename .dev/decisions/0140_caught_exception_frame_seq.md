# ADR-0140 — caught-exception cljw-shaped frame-seq accessor

- Status: Proposed → Accepted (2026-06-14)
- Deciders: autonomous loop (Track D D2, sweep_plan.md § Track D)
- Relates: ADR-0120 (trace deep-copied onto the ExInfo value), ADR-0059
  (no JVM Throwable / StackTraceElement), AD-024 (user-frames-only),
  AD-003 (simple class name), F-002/F-009/F-011, D-273 (clojure.stacktrace)
- Amends: AD-029 (`[no stack trace available]` marker → cljw-native frames;
  per-frame FORMAT still diverges from JVM)
- Discharges: D-389 (Throwable->map `:trace`/`:at`)
- Adds: AD-033 (Throwable->map `:trace`/`:at` are cljw maps, not JVM 4-vectors)
- Fixes: the dangling **D-232** cross-reference (AD-029 / D-389 / sweep_plan
  named the validation-campaign row D-232 as the frame-accessor owner; that
  owner row never existed — this ADR + D-438 are it)

## Context

A caught exception in cljw is an ExInfo value (ADR-0059: no JVM Throwable).
The frames ARE on the value — `StackFrame{ns, fn, file, line, column}`,
deep-copied at throw time (ADR-0120), rendered as the live-stderr `Trace:`
section + EDN `:trace`. But there was **no Clojure-level accessor** to pull
frames off a caught `e`, so `clojure.stacktrace/print-stack-trace` degraded to
`[no stack trace available]` (AD-029) and `Throwable->map`'s `:trace`/`:at`
were omitted (D-389 PARTIAL). AD-029 / D-389 / sweep_plan all named **D-232**
as the owner of this surface, but D-232 is the validation campaign — a
dangling reservation (Reservation-as-bias), no real owner row existed.

## Decision

Add a cljw-original primitive **`(stack-trace e)`** (`lang/primitive/error.zig`,
auto-referred like `ex-message`/`ex-data`/`ex-cause`) returning a vector of
**`{:ns :fn :file :line :column}` maps**, **innermost-first** (clj's `:trace`
convention; `info.trace` is innermost-last push order, so reverse). `:fn` is the
**bare** fn name, `:ns` separate (the renderer combines `<ns>/<fn>`). A
non-ex_info OR a never-thrown ex-info (no captured trace) → an **empty vector**.

Consumers:
- `clojure.stacktrace/print-stack-trace` iterates `(stack-trace tr)` and prints
  `<ns>/<fn> (<file>:<line>)` per frame; a frame-less exception keeps the AD-029
  marker. New `print-trace-element` formats one frame map.
- `clojure.core/Throwable->map` fills `:trace` (root cause's frames) + per-`:via`
  `:at` (each link's top frame) from `(stack-trace …)`, as the SAME maps — closing
  D-389. Omitted (absent, never empty) when an exception is frame-less.

The frame shape is a map, not a JVM `StackTraceElement` 4-vector — class/method
are fictions cljw won't fake (ADR-0059/AD-003); the map keeps `column` (a
4-vector drops it) and matches cljw's native `StackFrame` + SCI's interpreter-
frame map precedent. AD-024 (user-frames-only) holds free (elision at push time).

## Alternatives considered (Devil's-advocate fork, fresh context)

The DA fork ran within the F-NNN envelope. Verbatim-digested:

- **Alt 1 (smallest-diff) — no new var; populate `Throwable->map :trace`/`:at`
  as 4-vectors, drive clojure.stacktrace off `(:trace (Throwable->map e))`** (cw
  v0's choice). Better: one surface, no new symbol, matches clj's documented
  vector shape. Breaks: carrying `ns/fn` in `[class method …]` slots is a
  JVM-lie or a mislabel (AD-003 rejects); drops `column`; opaque per-frame
  access. REJECTED.
- **Alt 2 (finished-form-clean, ADOPTED) — `(stack-trace e)` → maps, AND
  `Throwable->map :trace`/`:at` as the SAME maps** (one shape everywhere).
  Better: one shape, no map↔vector projection to sync (Option C's hedge is the
  Smallest-diff-bias smell); honest at every surface; keeps `column`; matches
  native `StackFrame` + SCI. Breaks: `Throwable->map :trace`/`:at` diverge from
  clj's documented vector → ONE recorded AD (AD-033) — consistent with the
  already-accepted AD-007 (cljw's whole `#error{…}` trace representation
  diverges). No F-NNN violated.
- **Alt 3 (wildcard) — a printer primitive reusing `error/print.zig`'s `Trace:`
  renderer; no Clojure data shape; `:trace` stays omitted (permanent AD).**
  Better: single trace-format source (live stderr == clojure.stacktrace by
  construction). Breaks (decisive): no DATA accessor — blocks datafy + any
  programmatic frame consumer (a real pending need); optimizes the print path at
  the cost of the data path (violates F-002 cleanest-complete-form). REJECTED.

DA answers to the sub-questions:
- **Naming**: `(stack-trace e)` — verified clj has NO `stack-trace` core fn (no
  collision); `ex-trace` rejected (invents a non-existent `ex-*` clj member);
  `cljw.error/frames` rejected (needlessly buried — frames are a first-class
  property like message/data/cause). A named accessor IS the finished form (vs
  Alt 1's "frames only via Throwable->map") — minimize-surface points the wrong
  way here (F-002).
- **Map keys**: `:fn` **bare** ("boom") with `:ns` separate (the native struct
  carries them separately; combine at print time) — corrects the survey's
  qualified-`:fn` example. `:fn` over `:name` (cljw-native vocabulary; `:name`
  noted as the SCI-tooling-interop alternative).
- **AD-029**: **amend, not remove** — the marker is gone for caught exceptions,
  but the per-frame FORMAT still diverges (cljw `ns/fn` vs JVM `class.method`,
  no demunge; ADR-0059). Removing it would assert non-existent parity.
- **D-389 `:trace`/`:at`**: fill THIS cycle, as the same maps (not deferred, not
  projected to vectors) — leaving them split from `(stack-trace e)` would be the
  "two ways, different shapes" inconsistency.

The main loop adopted the DA recommendation verbatim (Alt 2 + the four answers).

## Consequences

- `clojure.stacktrace/print-stack-trace`/`print-cause-trace` print real
  cljw-native frames for caught exceptions; `Throwable->map` is complete
  (`:cause`/`:via`/`:trace`/`:data`, per-via `:at`). datafy's Throwable path is
  unblocked on the `:trace` axis (other datafy blockers remain — D-271).
- A frame-less (never-thrown) ex-info keeps the honest marker / omitted keys —
  AD-029's honest-degradation invariant survives for that case.
- Divergence recorded: AD-033 (map-shaped `:trace`/`:at`).
- The D-232 dangling reference is fixed; D-438 is the real frame-accessor row
  (discharged on landing this cycle).

## Affected files

- `src/lang/primitive/error.zig` — `stackTrace` primitive (+ `stack-trace` entry).
- `src/lang/clj/clojure/stacktrace.clj` — `print-trace-element` + frame-printing
  `print-stack-trace`; header/ns-doc updated.
- `src/lang/clj/clojure/core.clj` — `Throwable->map` `:trace`/`:at` (PROVISIONAL
  marker removed; triad discharged).
- `test/e2e/phase15_clojure_stacktrace.sh` (+frame cases),
  `test/e2e/phase14_throwable_map.sh` (+caught `:trace`/`:at` cases).
- `.dev/accepted_divergences.yaml` (AD-029 amend + AD-033), `feature_deps.yaml`,
  `.dev/debt.yaml` (D-389 discharge, D-438), `.dev/sweep_plan.md`.
