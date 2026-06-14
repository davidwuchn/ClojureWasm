# ADR-0138 — `*out*`/`*err*`/`*in*` as first-class cljw writer/reader values

- Status: Proposed → Accepted (2026-06-14)
- Deciders: autonomous loop (Track C, sweep_plan.md §1)
- Supersedes: ADR-0036's `out_writer_method` sentinel fallback (D-434)
- Relates: F-004 (host_instance writer home), F-009 (impl neutrality),
  ADR-0059 / AD-003 (no-JVM, simple class name), F-011 (behavioural
  equivalence), F-002 (finished-form wins), ADR-0126 (host_stream),
  ADR-0127 (print-method writer handle), D-414 (`*in*` reader subsystem),
  D-435/D-436 (大整理 epic)

## Context

cljw's `*out*`/`*err*` roots are keyword **sentinels**
(`:clojure.core/stdout` / `:clojure.core/stderr`, core.clj:46-47), not
Writer objects. Three collaborating mechanisms make print + capture work
around that sentinel:

1. **`out_capture` threadlocal** (core.zig:715, `setOutCapture` 723-727)
   — `with-out-str` and nREPL swap a thread-local Allocating sink that
   `emitToStdout` (729-771) consults *first*, bypassing the `*out*` Var
   entirely. This is a Layer-2 (lang/primitive) threadlocal invisible to
   the Layer-1 (eval) interop dispatch — a cross-zone hack.
2. **D-434 `out_writer_method.zig`** — because `(type *out*)` is a
   Keyword with no `.write`, a Writer-interop dot-call `(.write *out* s)`
   (used by `clojure.data.csv/write-csv`, `clojure.pprint`) has no method
   to dispatch. A shared dispatch-fallback (consulted last in BOTH
   backends, tree_walk.zig:744 + vm.zig:1302) special-cases the sentinel
   and routes `.write`/`.append`/`.flush` through `clojure.core/print`.
   Scope: stdout only; `*err*` interop is unrouted.
3. **`emitToStdout` precedence** — capture threadlocal → a non-keyword
   `*out*` binding (745-757, the half-built writer-value path that already
   calls `writeToWriterValue`) → `rt.stdout`.

The `*in*` side (D-414, already discharged) is cleaner: `*in*` root is
`nil` (uses the Var, no threadlocal), `with-in-str` binds it to a
`host_stream` reader value, `read-line` derefs it. But the reader lacks
`read-char`/`peek-char`/`unread-char`, and the
`clojure.lang.LispReader$StringReader` shim is a free fn + a
`constructInstance` ctor special-case (special_forms.zig:166-175) rather
than an operation on the reader value.

The user flagged (D-436 candidate b) that the sentinel-not-a-writer shape
forces every Writer-interop method to be special-cased forever. JVM
Clojure's `*out*` IS a `java.io.Writer`; `with-out-str` is just
`(binding [*out* (StringWriter.)] …)`. The finished form is the same:
make `*out*`/`*err*`/`*in*` bind to **first-class cljw writer/reader
values** so interop dispatch is the primary `lookupMethod` path and
capture is plain Var rebinding.

## Decision

Introduce a **durable, host_instance-backed Writer value and Reader
value** (F-004's declared writer home; no new NaN-box tag — slots 0-63
are full) in a new neutral module **`src/runtime/io/text_io.zig`**,
distinct from `host_stream.zig` (which keeps owning the `clojure.java.io`
file streams `BufferedReader`/`BufferedWriter`/…).

### Writer value

A `host_instance` with descriptor `fqcn = "Writer"` (simple name per
AD-003; UTF-8 fixed, no Charset/PrintWriter/BufferedWriter hierarchy —
the mandatory DIVERGENCE from JVM). Backed by a `TextWriterState`
carrying a **mode**:

- `.stdout` — writes route to `rt.stdout` (preserving the D-096 single
  offset-tracking interleave with the runner's result-print); `.flush`
  flushes it. Root of `*out*`.
- `.stderr` — writes route to a stderr sink. Root of `*err*` (finally
  wiring `*err*`, which the sentinel never did).
- `.string` — owns a `gc.infra` `ArrayList(u8)` accumulator; backs
  `with-out-str` and nREPL capture. A `(rt/__writer->str w)` accessor
  returns the buffer.

Methods on the descriptor's static `method_table`: `write` (string OR
int-codepoint→char, the latter folding out_writer_method.zig:62-66),
`append` (writes, returns receiver — chainable), `flush`, `close`.

### Reader value

A `host_instance` with descriptor `fqcn = "Reader"`, backed by an
in-memory byte buffer + a read cursor + a 1-slot char pushback. Methods:
`read` (next byte int / -1 — kept for stream compat), `read-char`
(next UTF-8 codepoint as char / -1), `peek-char` (no advance),
`unread-char` (1-slot pushback), `readLine`, `close`. The
`lispStringReader` D-414 shim folds in as a reader operation. `*in*` root
stays `nil` (no process-stdin reader yet); `with-in-str` mints a
`.string` reader.

### Wiring changes

- core.clj: `(def ^:dynamic *out* (rt/__stdout-writer))` /
  `*err* (rt/__stderr-writer)`; `*in*` stays `nil`.
- `emitToStdout` collapses to: render args into a scratch buffer, then
  `writeToWriterValue` on the bound `*out*`. The capture branch and the
  sentinel-fallthrough both disappear.
- `with-out-str` becomes `(binding [*out* (rt/__string-writer)] body
  (rt/__writer->str *out*))` — pure Var rebinding.
- nREPL capture (nrepl.zig:308-322): rebind `*out*` to a string writer
  via a binding frame for the eval, read the buffer after, instead of
  `setOutCapture`.
- **Delete**: `out_capture` threadlocal + `setOutCapture` (core.zig:715-727),
  `out_writer_method.zig` (whole file) + its two consult sites, the
  `:clojure.core/stdout`/`stderr` sentinel + `isStdoutSentinel`.

### Coexistence with writer_value.zig (print-method handle)

`runtime/writer_value.zig` (ADR-0127) wraps a **borrowed, single-print-scoped**
`*std.Io.Writer` for `(defmethod print-method T [o w] …)`. It models a
different lifetime (borrowed vs owned) and stays as-is; both carry
fqcn "Writer" (the class name is cosmetic, dispatch is per-value
`method_table`). Folding the two is a possible later cleanup, not part of
this ADR's finished form (the lifetimes are genuinely distinct).

## Consequences

- `(type *out*)` ⇒ `Writer` (was `Keyword`); `(.write *out* s)` /
  `.append` / `.flush` dispatch on the value's own method_table (primary
  path) — no fallback. `*err*` interop now works.
- D-436(b) discharged; D-434 superseded (file deleted); D-414 reader
  shims folded. D-435 (diff-oracle bootstrap gap) is independent and
  stays on the D-436 epic — but a writer VALUE is directly unit-testable.
- One behavioural divergence (no Charset / no PrintWriter auto-flush
  nuance) derives from no-JVM (ADR-0059) → an accepted divergence, not a
  gap.
- Depth-3/4 surgery: roots, print pipeline, both backend dispatch chains,
  a deleted file. Landed across 3 TDD commits (writer foundation → root
  flip + deletions → reader value).

## Build order

1. **Writer foundation** (additive, no root flip): `text_io.zig` Writer
   value + `.stdout`/`.stderr`/`.string` modes + `__stdout-writer`/
   `__stderr-writer`/`__string-writer`/`__writer->str` prims + the
   write/append/flush/close method_table. Unit tests. `writeToWriterValue`
   already dispatches `.write`, so this rides the existing seed.
2. **Root flip + deletions**: flip `*out*`/`*err*` roots; rewrite
   `emitToStdout` to uniform `writeToWriterValue`; rewrite `with-out-str`
   over `binding`; rewire nREPL; delete `out_capture`/`setOutCapture`/
   `out_writer_method.zig` + consult sites + the sentinel. e2e:
   print/println/with-out-str + `(.write *out* s)` + data.csv write-csv.
3. **Reader value**: `read-char`/`peek-char`/`unread-char` (UTF-8, 1-slot
   pushback); fold `lispStringReader`. e2e: with-in-str + read-line +
   instaparse safe-read-string corpus still green.

## Alternatives considered

(Devil's-advocate fork, fresh context, F-NNN envelope: F-002 finished-form-wins,
F-004 host_instance reuse / no new NaN-box tag, F-009 impl/surface/peer split,
F-011 behavioural equivalence, ADR-0059/AD-003 no-JVM simple class name.)

### Alt 1 — Smallest-diff: extend `host_stream.zig`'s StreamState with `.stdout`/`.stderr`/`.string` writer modes; no new module

Reuse the existing `StreamState` (host_stream.zig:52-65) as the single
writer/reader carrier; add the string sink mode + `append`/int-codepoint +
`read-char`/`peek-char`/`unread-char` to the existing method tables; root flip +
emitToStdout rewrite + nREPL rewire + deletions identical to the draft.

- **Better**: F-009-honest with zero structural churn — host_stream already owns
  the gc.infra accumulator, cursor, finaliser, `__string-reader`, and
  `lispStringReader`; the reader half collapses to "add three methods."
- **Breaks**: `stdout`/`stderr` don't fit StreamState's flush-to-`dest`-file
  contract (host_stream.zig:163-171 writes the whole accumulator to a file each
  flush — wrong for a live stream; it must write-through `rt.stdout` for the
  D-096 interleave). Co-locating a write-through live stream and a
  buffer-to-disk file sink in one method_table means every method grows a mode
  branch. Smallest-diff bias: overloads a type whose invariant is "I am a file
  buffer."

### Alt 2 — Finished-form-clean (DA-RECOMMENDED): the draft's `text_io.zig`, but fold host_stream's file streams onto the same carrier so the durable text reader/writer is defined exactly once

Keep `text_io.zig` owning the durable Writer/Reader value; additionally
re-express host_stream's file streams as `text_io`'s reader+writer *plus a file
dest* (`mode ∈ {stdout, stderr, string, file}`), so `lispStringReader` +
`read-char` family live once; host_stream shrinks to the `clojure.java.io`
open/copy/slurp primitives over the one carrier.

- **Better**: removes the draft's self-deferred two-carrier coexistence
  (TextWriterState beside StreamState, overlapping `write`/`flush`/`close`/
  `read`/`readLine`) — claimed Reservation-as-bias / Smallest-diff smell under
  F-002. Claims a latent F-011 gap: a file `reader` would lack
  `read-char`/`unread-char` that `*in*` has. One finaliser, one
  read-char definition.
- **Breaks**: rewrites the landed ADR-0126 host_stream subsystem (its
  `stream_classes` SSOT, concrete-class `(class …)` faithfulness, protocol_impls
  chains); per-mode fqcn nuance (one struct, four descriptors — simple
  "Reader"/"Writer" for `*in*`/`*out*`, concrete "BufferedReader"/"BufferedWriter"
  for files) must be preserved or `(class …)` regresses.

### Alt 3 — Wildcard: keep the sentinel root, lazily realise + cache a text_io value on first deref

Same text_io value type; `*out*` root stays the keyword sentinel, realised to a
process writer value on first `print`/`read` and cached into the Var root.

- **Better**: sidesteps the bootstrap-ordering question (no host_instance minted
  at core.clj:46); shrinks the root-flip blast radius.
- **Breaks**: permanent-no-op / silent-default-shift smell in a feature costume —
  KEEPS the sentinel (the exact thing D-436(b)/D-434 delete), relocates
  `isStdoutSentinel` to the hot deref path, makes `(type *out*)` only
  *eventually* a Writer (F-011 violation before first print), and resurrects the
  realise-or-fallback branch out_writer_method.zig embodies today. Rejected.

### Three correctness cautions (load-bearing regardless of shape — adopted)

1. **`.stdout` write-through, not buffer-to-disk.** `.stdout`/`.stderr` `write`
   calls `rt.stdout.writeAll`, `flush` flushes `rt.stdout` (runtime.zig:101) —
   NOT host_stream's accumulate-then-`file_io.writeAll`. This is the load-bearing
   reason `.stdout` is a distinct mode; preserves the D-096 offset-tracking
   interleave + per-call write semantics exactly.
2. **nREPL rewire needs no new runtime helper, per-thread isolation preserved.**
   `current_frame` (env.zig:249) is already `threadlocal`, so a
   `binding [*out* string-writer]` frame is per-connection-thread exactly as
   `out_capture` was. nrepl.zig (Layer 3) may push a BindingFrame directly
   (zone-legal); save/restore maps 1:1 to push/defer-pop. An optional
   `rt`-level `withOutCaptured(thunk)` convenience reads cleaner but is not
   required for correctness.
3. **`unread-char` is codepoint-aware**, not a byte decrement: a dedicated
   `pushback: ?u21` field consulted first by `read-char`/`peek-char` sidesteps
   multi-byte codepoint corruption.

### Main-loop decision vs the DA recommendation (non-binding)

**The main loop keeps the draft's two-value-type separation (text_io for
`*out*`/`*err*`/`*in*`; host_stream unchanged for file streams) and REJECTS
Alt 2's carrier fold — on finished-form + F-011 grounds, NOT diff budget.**

Reasoning:

- **Alt 2's headline F-011 argument is backwards.** JVM Clojure's `*in*` is a
  `LineNumberingPushbackReader` (has `unread`/pushback); `(reader "f.txt")` is a
  `BufferedReader` (NO pushback). They are genuinely different class families
  with different method sets. Giving a file reader `unread-char` would make cljw
  *less* JVM-faithful, not more — so there is no parity gap to close, and the
  draft's separation mirrors the JVM class split correctly (simple "Reader" for
  `*in*` with pushback, concrete "BufferedReader" for files without).
- **The invariants are genuinely different**, not duplicated: write-through live
  stream (stdout/stderr) vs buffer-to-disk file vs in-memory string. Folding
  forces a 4-way `mode` branch inside every `write`/`flush`/`close` — the exact
  per-method mode-branch the DA used to reject Alt 1, made worse. Separate value
  types with single-purpose methods is the cleaner finished form here.
- **The DA's *valid* residual concern is mechanism duplication** (byte buffer +
  read cursor + `readLine` + UTF-8 `read-char`). The finished-form answer is a
  **shared low-level helper** (a `ByteCursor`-style struct: buffer + pos +
  `?u21` pushback + readLine/read-char), composed by both `text_io` and
  (optionally) `host_stream` — sharing the *mechanism* without conflating the
  *value types / descriptors / fqcn / flush semantics*. Whether host_stream
  adopts the shared helper is decided at build-step 3 (where pushback logic
  lands); it is a behaviour-preserving refactor, not a value-type merge.

This is not the Cycle-budget defer smell: Alt 2 is declined because its value-type
fold is *less* finished-form-clean (less JVM-faithful, more per-method branching),
and the duplication it correctly identifies is addressed by a shared helper. All
three DA correctness cautions are adopted verbatim.
