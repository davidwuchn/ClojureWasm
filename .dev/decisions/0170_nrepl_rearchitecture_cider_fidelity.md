# ADR-0170: nREPL server re-architecture — base-protocol fidelity (CIDER end-to-end)

- **Status**: Accepted
- **Date**: 2026-07-13
- **Related**: ADR-0015 am2 (F142 re-introduction), ADR-0048 (nREPL state chart),
  ADR-0138 (`*out*` capture via binding frame), ADR-0019 (exit/error policy),
  D-117 (nREPL polish), D-118 (out/err capture), F-002 / F-009 / F-011 / F-014

## Context

The row-14.10 minimal nREPL server (`src/app/nrepl.zig`, one file, 7 ops)
predates most of the runtime's current capabilities. A CIDER field report
(REPL buffer RET dead, no completion, bare `NameError` errors) triggered an
empirical probe of the live server (two independent bencode replay drivers,
2026-07-13). Confirmed defects:

1. **Read-loop stranding**: the session loop does one `fillMore()` →
   one `decode` → one op per iteration, so it *blocks for new socket
   bytes even when complete bencode dicts already sit buffered*.
   Pipelined requests strand off-by-one (probe: of 2 requests written
   in one TCP segment, the second is answered only after a *third*
   write arrives). CIDER overlaps requests during connect (init eval +
   capability probes), so the init eval's `done` strands → the REPL
   prompt marker never renders → RET inserts a newline forever.
   `C-c C-e` works because it is a lone in-flight request.
2. **4 KiB frame ceiling**: `decode` sees at most the fixed 4096-byte
   stream buffer; a larger message can never decode → `catch break`
   closes the connection (probe: 10.6 KiB eval → connection reset).
   `C-c C-k` (load-file) on any real file kills the connection.
3. **Session identity broken**: every `clone` returns the *same*
   connection-constant id, and every reply stamps that constant
   instead of echoing the request's `session`. CIDER clones two
   sessions (main + tooling) over one socket and relies on distinct
   ids (nrepl-client.el:619-639; the CIDER mock server echoes the
   request session and mints a fresh `new-session` per clone).
4. **Error replies malformed × 4**: (a) `err` text is the raw Zig
   `@errorName` (`"NameError"`) instead of the rich caret rendering
   the CLI already produces via `error_render.zig`; (b) `err` and
   `status ["error" "eval-error" "done"]` ride ONE dict, which
   CIDER's mutually-exclusive response `cond` mis-routes
   (nrepl-client.el:744-770); (c) a second bare `done` follows
   (double-done per request); (d) evaluation *continues* past a
   failing form (JVM nREPL stops).
5. **Missing ops**: no `completions`/`complete` (CIDER gates
   completion on these being advertised — cider-completion.el:136-142),
   no `lookup`/`info`/`eldoc` (eldoc + doc popups dead).
6. **describe lies**: `versions` hardcodes `"0.1.0-pre"` (real version
   = `build_options.version` = the `build.zig.zon` value, currently
   1.1.0); ops list is hand-maintained separately from the dispatch
   chain (drift by construction).

The runtime meanwhile grew the exact capabilities the server lacks:
`error_render.zig` (rich caret rendering, EDN mode "for CIDER /
editors" per its own doc comment), `line_editor.zig::handleTab`
(Env-wide completion-candidate enumeration), `Var.meta`
(`:arglists`/`:doc` for `clojure.repl/doc`). The single-file server
simply never re-consumed them — the textbook early-asset inertia
F-002 exists to overrule.

**Reference precedent**: babashka.nrepl (`~/Documents/OSS/babashka.nrepl`)
is the JVM-less nREPL that drives CIDER fully. Its load-bearing idioms:
a single `response-for` choke point that stamps *every* reply with the
request's `session`+`id`; sessions as plain fresh-UUID tags; op
multimethod with `:default` → `unknown-op`; the 3-message error
protocol (`err` → `ex`/`root-ex`/`eval-error` → `done`); `completions`
+ `lookup`/`info`/`eldoc` built from interpreter introspection. Its
compromises (no stdin op, no mid-eval interrupt, no cider-nrepl
extension middleware) are CIDER-graceful and adopted here.

## Decision

Rewrite the server as a package under `src/app/nrepl/` (precedent:
`src/app/repl/` for the line editor), with one shared introspection
module extracted to the runtime layer:

| File                       | Responsibility                                                                                                                                                                                                                                                                                                                                          |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `src/app/nrepl.zig`        | Thin entry: bootstrap + `.nrepl-port` + sequential accept loop (concurrency model unchanged; CIDER uses one socket).                                                                                                                                                                                                                                       |
| `src/app/nrepl/transport.zig` | Framing + reply choke point. Growable receive buffer; decode **all** buffered messages before blocking (`bencode.DecodeError.UnexpectedEof` = truncated → wait for bytes; other decode errors = protocol error → close); message size cap. Every reply passes through `responseFor`, which echoes the request's `session` + `id` — ops cannot mis-stamp. |
| `src/app/nrepl/session.zig`   | Registry: `clone` → fresh unique id; `close`; `ls-sessions`. Per-session state: current-ns name + `*1`/`*2`/`*3`/`*e` Values, registered as permanent GC roots (`.dev/gc_rooting.md` discipline) and released on close.                                                                                                                                   |
| `src/app/nrepl/ops.zig`       | `comptime` StaticStringMap op → handler. `describe` **derives** its ops list from the same table (drift impossible) and reports `versions` from `build_options.version`. Unknown op → `status ["error" "unknown-op" "done"]`.                                                                                                                            |
| `src/app/nrepl/eval.zig`      | Eval engine: per-form read/analyze/eval; honors the request `ns` key (binds the session ns; `status ["namespace-not-found" "done" "error"]` on miss); per-form `*out*` capture (ADR-0138 shape); updates `*1`/`*2`/`*3`/`*e`; **stops on first error** (JVM parity); errors render via `error_render` into `err`, then `{ex, root-ex, status [eval-error]}`, then `done` — three separate dicts, exactly one `done` per request. |
| `src/app/eval_session.zig`    | **Shared REPL eval engine** (DA deepening (a)): per-form read/analyze/eval with the D-430 AnalysisFrame bracket, `*out*` **and `*err*`** capture, `*1`/`*2`/`*3`/`*e` rotation over the interned dynamic Vars, stop-on-first-error, error rendering through `error_render` — driven through caller-supplied sinks. Consumers: `nrepl/eval.zig` (bencode sinks) and `repl.zig` (terminal sinks — the CLI REPL gains `*1`..`*e` in the same cycle; duplicating the rotation would be the F-011 violation the DA flagged).                    |
| `src/runtime/introspect.zig`  | Shared introspection: completion-candidate enumeration (extracted from `line_editor.zig::handleTab`'s collect* fns — same-layer move, Env is layer 0), returning **typed** candidates `{name, ns?, kind}` (fn/macro/var/namespace — the completions op needs the type; the line editor ignores it) + var-meta lookup (`:arglists`/`:doc` + macro flag from `Var`). Consumers: line editor (candidate cap 64), nREPL `completions`/`lookup`/`info`/`eldoc`, future `--list-vars`.                        |

**Op surface** (all advertised by the derived `describe`): `clone`,
`close`, `describe`, `eval`, `load-file`, `interrupt`, `ls-sessions`,
`completions`, `complete`, `lookup`, `info`, `eldoc`.
Response shapes mirror babashka.nrepl (CIDER-proven):
- `completions`/`complete` → `{completions: [{candidate, type, ns?}…], status [done]}`
  (`type` from Var flags: macro / function / var; namespace candidates → namespace).
- `info` → flat `{ns, name, arglists-str, doc?, file?, line?}` + done;
  `lookup` → the same map nested under `info`; `eldoc` →
  `{ns, name, eldoc [[arg…]…], type, docstring?}` + done, `no-eldoc`
  status on miss.

**Core surface addition**: `*1` / `*2` / `*3` / `*e` are interned in
`clojure.core` as dynamic vars in the upstream core.clj shape (JVM
parity — today they don't resolve at all, which is itself a gap;
interning is also what makes `(inc *1)` *analyzable*, so a
session-struct-only shape would silently not resolve). Both REPLs
bind and rotate them via `eval_session.zig` in this cycle.

**Session state rooting**: each session's held Values (`*1`..`*e`)
are rooted via `GcHeap.pin`/`unpin` (the existing `permanent_roots`
embedder surface — no new root class), swapped on rotation and
released on session close; the `GC-ROOT:` marker + `.dev/gc_rooting.md`
row land in the same commit per that SSOT's discipline.

**Transport memory contract** (DA finding #5): the pre-ADR server fed
every decode/encode/print into the process-lifetime arena — unbounded
growth over a long editor session. `transport.zig` owns a per-message
scratch arena (bencode decode + reply encode + value-print buffers,
reset after each reply flushes); reader forms / analysis nodes stay on
the persistent node arena as today (they can be referenced by
persisted defs — F-006's allocator layering). The bencode codec
needs NO change: `DecodeError.UnexpectedEof` fires only on truncation
(→ buffer more, up to the size cap), other decode errors are protocol
errors (→ close). The size cap is load-bearing: a huge declared
string length (`999999999:…`) reads as truncation forever without it.

**describe versions**: `{cljw: <build_options.version>, nrepl:
{version-string: "1.3.1"}}` — deliberately **no** `clojure` key.
This is the exact babashka shape (its describe payload is
`{"versions" {"babashka" <ver>, "babashka.nrepl" <ver>}}`, no
`clojure` key). CIDER keys its runtime detection on
`versions.clojure`; claiming it flips CIDER to 'clojure runtime and
triggers cider-nrepl middleware-missing warnings on every connect.
'generic runtime (like let-go before its upstream CIDER patch)
degrades gracefully while all op-gated features (completion, eldoc)
work. Upstreaming a `cljw` runtime key to CIDER is a
separately-tracked idea, not a blocker.

## Principled compromises (recorded, babashka-matching)

| Compromise | Rationale | Tracking |
|---|---|---|
| No `stdin` op | single-threaded `read-line` semantics need the concurrency area | D-117 residual |
| No mid-eval `interrupt` (acks `done`+`session-idle`) | a hung eval owns the only thread; true interrupt = thread-per-session (gap area I) | D-117 (a) |
| No cider-nrepl extension middleware (debugger/inspector/test-runner/apropos ops) | separate ~15 kLOC JVM-introspection project; CIDER degrades gracefully | out of scope (F-014 goal line) |
| `out`/`err` streamed per top-level form, not per write | **A divergence FROM babashka** (bb's proxy Writer pushes an `out` response per write, mid-eval — the DA corrected the draft's "bb-proven" claim). ADR-0138 capture shape; user-visible symptom: a long-running form's prints arrive only when the form returns | D-118 re-narrowed to this |

## Consequences

- CIDER works end-to-end against the base protocol: REPL buffer
  evaluation, streaming out, completion, eldoc, doc lookup, load-file
  of real-size files, rich error text identical to the CLI.
- `test/e2e/phase14_nrepl.sh` grows CIDER-replay coverage: distinct
  clone ids, session echo, pipelined burst, >4 KiB frames, the error
  triple, completions/lookup shapes, describe derivation. The old
  single-session happy-path e2e was green while CIDER was broken —
  the proxy-test lesson (memory `verify_actual_pattern_not_proxy`).
- The CLI REPL gains `*1`/`*2`/`*3`/`*e` in the same cycle via the
  shared `eval_session.zig` engine (the F-011 dividend that proves the
  extraction earned its keep).
- D-117 is re-narrowed by code-truth (its "CIDER ops LANDED" claim was
  false — only load-file had landed); D-118's remaining gap narrows to
  per-write streaming.
- `structure_plan.md`'s single-file `nrepl_server.zig` note and the
  `runtime/cljw/repl/NReplServer.zig` reservation are superseded by
  this package shape (reservations are memos, F-002); if a
  `(cljw.repl/start-server!)` Clojure surface ever lands, the
  app-layer engine is reachable via the `driver.installVTable`
  precedent — no code now.
- `line_editor.zig` sheds its private candidate enumeration for the
  shared `runtime/introspect.zig` (behaviour-preserving extraction,
  cap 64 kept at the caller).
- The stale `"0.1.0-pre"` version lie is structurally impossible
  (single source: `build_options.version`).

## Alternatives considered

(Devil's-advocate subagent output, fresh-context fork 2026-07-13,
reflected per CLAUDE.md § ADR-level designs. Its leading finding: no
F-NNN blocks any shape. Its fact-checks — the draft's "per-form out is
bb-proven" claim was FALSE (bb streams per write), `*err*` capture was
missing, the "runs before bootstrap" argument for Zig-side introspection
was factually wrong (the server is always post-bootstrap; the real
argument is the keystroke path + F-011), the arena-growth gap, and the
bencode-already-distinguishes-truncation observation — are folded into
Context/Decision above.)

**Alternative 1 — smallest-diff (fix-in-place, one file).** Keep
`nrepl.zig` single-file (~900 LOC): growable buffer, per-clone counter,
3-message errors, stop-on-error, `build_options.version`, completions
via `pub`-ing `line_editor`'s collect fns. Better: zero structural
churn, each fix independently verifiable. Breaks: sharing completion
logic by exposing private methods of a raw-terminal line editor is the
ad-hoc coupling F-011 forbids; an app-layer home forecloses any future
Layer-2 surface; the if-else op chain keeps the describe-drift class.
DA verdict: "reaches a different, worse finished form — disqualified
under F-002 since the probe evidence shows five orthogonal concern
clusters (framing, sessions, ops, eval, introspection)".

**Alternative 2 — finished-form-clean (draft + four deepenings) —
RECOMMENDED and ADOPTED.** (a) Extract the shared eval-session core
NOW: once `*1`..`*e` are interned dynamic Vars, the rotation logic is
identical for both REPLs; deferring it is "the Cycle-budget-defer smell
wearing a 'correct sizing' costume" — nREPL-only `*1` (works in CIDER,
absent in `cljw repl`) is indefensible under F-011. (b) Session state
rooted via the existing pin surface + gc_rooting.md row, not a new root
class. (c) `runtime/introspect.zig` with typed candidates; cite F-011
commonization + the zone graph (NOT F-009, whose out-of-scope clause
covers env.zig). (d) Transport scratch-arena split + `*err*` capture +
honest per-form-out divergence row. Cost: substantially larger diff
(repl.zig + bootstrap + gc_rooting.md ride along) — recommended anyway
per F-002; the risk (eval-extraction disturbing the AnalysisFrame
bracket placement, D-556 class) is covered by the existing smoke +
phase14 e2e.

**Alternative 3 — wildcard: Clojure-side ops (the literal bb
transplant).** Implement completions/lookup/info/eldoc in `.clj`
(bb's `impl/sci.clj` shape) — maximum Clojure-level commonization,
dogfoods cljw, no new Zig surface. Breaks: the line editor's TAB path
would either eval per keystroke inside a raw-mode terminal (GC +
output-capture + error isolation on the keystroke path) or keep its
Zig walk — recreating the duplication across a language boundary where
drift is harder to see; needs a generic Value→bencode walker; a throw
inside a completions eval must not rotate the session's `*e`. DA
rating: "the right *eventual* direction for lookup-class ops
(data-shaped, latency-tolerant), wrong today for keystroke-shared
completion enumeration" — recorded as a forward note: lookup-class ops
MAY migrate to `.clj` when a `cljw.repl` ns lands (F-014 clause 4
would accept a `(cljw.repl/start-server!)` surface; the app-layer
engine would then be reached via the `driver.installVTable` precedent).

Judgment-call stress-tests adopted from the DA: transport owns the
session/id echo with the clone edge (echo the parent session, emit the
fresh `new-session`); the op table + describe derive from ONE comptime
tuple (StaticStringMap does not iterate cleanly); aliases are separate
entries pointing at one handler so describe advertises them all;
`interrupt` acks `["done" "session-idle"]` when idle (spec) instead of
bare done; per-session state is kept (JVM nREPL sessions are per-session
binding maps — the F-011 oracle; bb's global `set!` across id-tags is
bb's simplification and would let tooling-session evals rotate the
user's `*1`).

## Revision history

- 2026-07-13: Proposed.
