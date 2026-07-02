# ADR-0169: Analysis-roots frame — rooting analyze/compile/deserialize-time Values

- Status: Accepted (2026-07-02)
- Deciders: autonomous loop (per CLAUDE.md § ADR-level designs are handled inline)
- Related: ADR-0028 (§5 root sources; amendment 3 gray worklist), ADR-0091
  (thread_roots union walk), ADR-0164/D-519 (alloc-boundary auto-collect),
  D-430, D-531, `.dev/gc_rooting.md`

## Context

GC Values produced BEFORE any frame executes had no root:

- **Analyzer literals** — `makeConstant` stores a freshly-allocated Value
  (string / bigint / regex / tagged / empty-list) in an arena `Node`;
  `analyzeQuote` stores a fully-built quoted structure in a `quote_node`.
- **Compiler constants** — `Compiler.addConstant` appends to an arena
  ArrayList; 7 more `string_mod.alloc` sites feed it.
- **Deserialized AOT constants** — `serialize.deserializeChunk` fills an
  arena slice one `readValue` at a time.
- **Macro-expansion intermediates** — `expandIfMacro`'s `&form` / `&env` /
  arg Values and the expansion result cross between runtime and analysis in
  Zig locals.

`EvalFrame.constants` (D-251) roots a chunk's pool only WHILE `vm.eval` runs.
So any collect in the window between a Value's creation and its execution
swept it: (a) a user-macro expansion mid-analysis runs arbitrary eval (the
minimized repro: `(defmacro m [x] x) (deftype T [] Object (toString [self]
(m 1)))` under `CLJW_GC_TORTURE=1` — the `"toString"` string cell was swept
and recycled as the `"->T"` factory-name string, so extend-type raised
"host-marker method not yet wired" on a fully-wired method); (b) the D-519
alloc-boundary auto-collect fires mid-analysis of any large in-eval load once
the 4MB threshold crosses — instaparse's per-run garbage-bytes symbol
NameError (D-430) and the D-531 "index out of bounds: index 16, len 16"
panic family.

## Decision

A per-thread **analysis-frame chain** (`root_set.AnalysisFrame` +
threadlocal `analysis_frame_head`), the EvalFrame's analysis-side sibling:

1. **Brackets**: every analyze/compile/deserialize→eval seam opens a frame on
   its C stack (`beginAnalysis` / `defer endAnalysis`) and keeps it open
   THROUGH the form's evaluation (also covers tree_walk Node constants,
   which have no EvalFrame pool). Seams bracketed: `driver.evalTopLevelForm`,
   `driver.runEnvelope` (per chunk — keeps the high-water mark at one form's
   constants), `app/repl.zig`, `app/nrepl.zig`, `app/builder.zig` (5 sites),
   `eval/evaluator.zig` (`--compare` oracle twin).
2. **Producers push**: `analyzer.makeConstant`, `special_forms.analyzeQuote`,
   `Compiler.addConstant`, `serialize.deserializeChunk`'s constant loop, and
   `expandIfMacro` (amp_form / amp_env / value_args / expansion result). The
   frame stores the allocator (`gc.infra`) so producer signatures are
   unchanged. Immediates are filtered at push.
3. **Fail-loud tripwire**: `pushAnalysisRoot` asserts a frame is open (safe
   builds). A producer running outside any bracket is a caught bug at the
   source, not a silent unrooted window — future drivers self-announce.
4. **Walker**: a new `.analysis` sub-phase in `ThreadRootsCursor` (after
   `.self_guard`) drains the chain; `ThreadGcContext.analysis_frame_slot`
   (default static null) publishes each worker's chain — the ADR-0091
   union-walk pattern, one new section in `gc_rooting.md`, not one new
   concept.
5. **`macro_root_slot` RETIRED**: it never gained a production writer
   (gc_rooting.md §B), and its declared purpose (macro-expansion
   intermediates) is exactly what the frame now carries — `expandIfMacro`
   pushes them. The walker `.macro` phase, `ThreadRoots.macro`,
   `ThreadGcContext.macro_slot`, and the threadlocal are removed; worker
   registration sites now publish `analysis_frame_head` instead. Net concept
   count in the rooting SSOT: +1 −1.

## Alternatives considered

A fresh-context Devil's-advocate subagent was forked (depth ≥ 2 mandate).
Summary of its findings (near-verbatim; the full text is in the fork's
output, reflected here in condensed form):

- **Premise verified**: ~14 analyzer literal arms + 7 compiler string sites +
  the deserialize loop are unrooted until execution; `maybeAutoCollect` fires
  at the alloc boundary whenever analysis happens inside an outer eval
  (`require`/`load`/`eval` mid-program) — both repro legs structurally
  confirmed. The macro-expansion result Value was flagged as a sibling
  unrooted window to fold into the same change (done).
- **The draft's original `evalTopLevelForm`-only watermark boundary was
  WRONG**: six seams escape it (REPL, nREPL, builder ×N, the `--compare`
  oracle twin, `runEnvelope`, bootstrap AOT), and `deserializeChunk` was a
  missed third producer ON THE DEFAULT STARTUP PATH. This pushed the design
  from an implicit watermark registry to the explicit self-enforcing frame.
- **Alt A (smallest-diff)** — watermark over the existing `permanent_roots`
  pin list: zero new walker code, but the pin list is process-global, so two
  concurrently-analyzing threads' truncates free each other's live pins — a
  knowingly-shipped race under landed Phase-15 concurrency, plus a
  meaning-membrane violation (embedder-pin vs transient). Rejected.
- **Alt B (finished-form-clean, ADOPTED)** — the AnalysisFrame chain as
  described, with the assert-on-unbracketed-producer property converting the
  seam-enumeration failure mode (the same enumeration failure that left
  `macro_root_slot` unwired for its whole life) into a mechanical invariant.
- **Alt C (wildcard)** — no GC allocation at analysis time at all: keep
  literals in the arena and materialize on first `op_const` under the
  already-published EvalFrame root. Eliminates the bug class and pre-pays
  moving-GC checklist item 4 ("literal-copy-to-heap"), but makes the constant
  pool dual-representation, moves data-reader/`#inst` errors from load-time
  to first-eval-time (an F-011 behavioural-equivalence risk needing its own
  audit), and still needs half of Alt B for the macro window. Recorded on
  `gc_rooting.md`'s moving-GC checklist as the noted option, not adopted.
- **Simpler alternatives rejected**: deferring auto-collect during analysis
  (an `analysis_depth` gate) is the cw v0 `suppressCollection` escape hatch
  F-006's history refuses — macro expansion legitimately needs collects and
  torture-mode stays red; extending ADR-0150 fabrication regions is correct
  only for pure-Zig no-reentry code, which analysis is not.
- **Costs verified**: double-rooting is O(1) per already-marked object at
  mark time; retention is bounded by the per-form bracket (same class as
  `EvalFrame.constants` during execution); the bootstrap loads core one form
  at a time so the registry peaks at one form's literal count.

## Consequences

- The D-430 corruption family (garbage-symbol NameError / recycled-cell
  mis-dispatch / D-531 OOB-16 panic class) is closed at the root: no
  analysis/compile/deserialize-time Value is ever collect-exposed.
- A new driver seam that forgets its bracket fails loudly (assert) on the
  first literal it analyzes in a safe build, instead of corrupting under
  load.
- Worker threads that analyze (eval on a future/agent) publish their chain
  via `analysis_frame_slot`; workers that never analyze pay one static null.
- STW-only state like the gray worklist: collects cannot run concurrently
  with a mutating chain (safepoint parks), and the walker reads `items.len`
  at walk time.
- `macro_root_slot` is gone; ADR-0028 §5 row 7's slot is subsumed (recorded
  there via this ADR's cross-reference).

## Affected files

`src/runtime/gc/root_set.zig` (frame + walker + ThreadGcContext; macro slot
removed), `src/eval/analyzer/analyzer.zig` (`makeConstant`),
`src/eval/analyzer/special_forms.zig` (`analyzeQuote`),
`src/eval/backend/vm/compiler.zig` (`addConstant`),
`src/eval/bytecode/serialize.zig` (`deserializeChunk`),
`src/eval/macro_dispatch.zig` (`expandIfMacro`), `src/eval/driver.zig`,
`src/app/repl.zig`, `src/app/nrepl.zig`, `src/app/builder.zig`,
`src/eval/evaluator.zig`, worker registration sites
(`future.zig` / `agent.zig` / `safepoint.zig` / `vm.zig`),
`.dev/gc_rooting.md`, `test/e2e/phase16_gc_torture.sh`
(`analysis_const_root`).

## Verification residuals (landed in the same arc)

Driving the instaparse repro to a deterministic state after the frame landed
exposed two SIBLING unrooted classes (not analysis-window bugs, but the same
"GC Value reachable only through a non-GC container" shape):

1. **formToValue builder accumulators** (`vectorFormToValue` /
   `mapFormToValue` / `setFormToValue` / `listFormToValue` / the `form.meta`
   branch): `out`/`acc` + in-flight elements lived in Zig locals across
   per-element allocs — alloc-torture panicked "@memcpy arguments alias"
   (the swept vector tail was recycled AS the new tail). The Value→Form
   direction (D-253) had frames; the Form→Value direction did not. Fixed
   with the same §C EvalFrame idiom (bracket-independent — formToValue also
   runs at runtime under `read-string`, outside any analysis frame).
2. **`TypeDescriptor` values had no GC trace** (the gc_rooting §C **C8**
   KNOWN-OPEN): the descriptor struct is gpa-owned and never swept, but its
   `method_table[].method_val` (deftype/reify method Functions — often
   reachable ONLY through the descriptor) and `meta` are ordinary GC
   objects. Past the 4MB collect threshold they were swept — instaparse's
   `(set! cached-seq …)` then read its field-name chunk-constant as garbage.
   Fixed: `.type_descriptor` tag trace (the trackHeap'd ref is a persistent
   mark-waypoint, so the trace re-runs every collect) + `markDescriptorValues`
   from both instance traces (typed + reified, parent chain included).

After all three land, the instaparse load/parse is byte-deterministic across
runs (the remaining failure is a plain parity gap at instaparse
`core.cljc:361`, tracked in D-430).

## Revision history

- 2026-07-02: Status: Proposed → Accepted (autonomous-loop self-accept; DA
  fork reflected into Alternatives considered; Alt B adopted over the
  draft's watermark registry after the DA surfaced the six escaped seams +
  the deserializeChunk producer). Same-day: § Verification residuals added —
  the two sibling unrooted classes (formToValue builders; TypeDescriptor
  method-table trace = C8's root cause) found while verifying, fixed in the
  same source commit.
