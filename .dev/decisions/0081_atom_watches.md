# ADR-0081 — Atom watches via an appended `watches` field (Phase 15 entry)

**Status**: Proposed → Accepted (2026-06-03, Phase 15 concurrency entry / D-157)

## Context

`add-watch` / `remove-watch` (Clojure atom watchers) were unimplemented
(debt row D-157) — `(add-watch a :k f)` → cljw `name_error` / clj registers a
watcher fired on every `swap!`/`reset!`/`compare-and-set!` change with
`[key ref old new]`. This is the first task of Phase 15 (concurrency); the
runtime is single-threaded, so **synchronous** notification (fire in the
swapping call, after the in-place mutation) is the correct finished form —
clj also fires watches in the swapping thread.

`src/runtime/atom.zig`'s `Atom` is an `extern struct { header, _pad[6], current }`.
Its header comment notes watches/validator are Phase-15 deferrals and that —
per F-003 / the Reservation-as-bias smell — **no watches field was reserved**.
So adding watches is a genuine structural decision, handled with the mandatory
Devil's-advocate fork (depth ≥ 2).

clj semantics (verified): watches fire on EVERY change including `old == new`
(no equality short-circuit); `add-watch` with an existing key REPLACES; order
is unspecified (map-iteration order); `compare-and-set!` fires only on success.

## Decision

**Alt 2 (DA-recommended): append a `watches: Value` field to the `Atom` extern
struct, holding `nil` (zero-watch atoms — no allocation) or a persistent map
`{key → fn}`.**

- `add-watch` = `assoc` into the watches map (or a fresh empty map); `remove-watch`
  = `dissoc` — reusing the existing persistent-map machinery gives clj-faithful
  key-replace + remove-absent-is-no-op for free.
- `traceGc` gains a one-line `mark(watches)` — the map traces its keys + fns
  transitively. GC-correct by the same "reachable through the atom" invariant
  the existing `current`-trace embodies; when the atom is swept, its watches map
  becomes unreachable and is collected (no leak / dangling-key class that the
  side-table alternative suffers).
- Notify (synchronous, in `swap!`/`reset!`/`compare-and-set!` after the in-place
  set, success-only for CAS): snapshot the watches map, iterate via
  `map.keys` + `map.get` (works for any map kind), call each fn `[key ref old new]`
  through `rt.vtable.callFn`. Fires on every change incl. `old == new`.
- **`validator` is NOT added now** (F-003): set-validator! lands its own field by
  the same one-line repetition when that task arrives. The extern-struct shape
  (`header` at offset 0, `current` traceable) is preserved; appending after
  `current` keeps the comptime asserts valid.

F-004 untouched (atom is one `.atom` NaN-box slot; this changes the pointed-at
heap struct, not the 64-slot layout). F-006 honored (watches traced). F-011
(behavioural equivalence vs clj).

## Alternatives considered

(Devil's-advocate fork, fresh context — verbatim summary.)

**No F-NNN block.** Alt 2 lives within F-004/F-006/F-002/F-011/F-003.

- **Alt 1 — SMALLEST-DIFF: Runtime side-table `AutoHashMap(*Atom, WatchList)`.**
  No struct change. BREAKS: GC correctness — the side-table holds Values the GC
  must trace but it is not a heap value with a trace hook, and (fatal) when an
  atom is swept its entry is never cleaned → the table grows monotonically,
  keeps watch fns alive forever, and the `*Atom` key dangles (re-alloc at the
  same address aliases a dead atom's watches onto a new atom). Fixing it needs
  GC finalization cw lacks. Validator would be a second side-table with the same
  disease; threading makes the global table a contention point. Reject (smallest-
  diff bias the finished-form owner would unwind).

- **Alt 2 — FINISHED-FORM: append `watches: Value` (a persistent map).** GC-correct
  by construction (reachable through the atom, collected with it); reuses map
  `assoc`/`dissoc` (clj-faithful key-replace/remove, almost no new data-structure
  code); extends to `validator` by literal one-field repetition; heap-local field
  is threading-friendlier than a global table (future per-atom lock attaches to
  the cell). Risks: struct size changes (re-confirm the `@offsetOf(header)==0` /
  `@alignOf>=8` asserts — they hold; only `atom.zig` + `primitive/atom.zig` touch
  the struct, both via accessors); notify site must thread `rt`+`env` to `callFn`
  (available; `resetFn`/`compareAndSetFn` drop their `_ = rt; _ = env;`). Recommended.

- **Alt 3 — WILDCARD: a dedicated `AtomWatches` heap block** (watches + validator
  + future agent/meta in one lazily-created side-block pointed to by one atom
  field). BEST for "lots of reference metadata" + cache-local, GC-correct. But it
  reinvents map key-handling as bespoke array code (more surface, diverges from
  clj's "watches IS a map" model) and is F-003 over-reservation — it builds a
  metadata container for imagined agents/meta that are not this task. Reject on
  F-003 grounds (not diff size).

**DA recommendation (non-binding): Alt 2.** Implementation notes adopted: keep
`watches = nil` for zero-watch atoms (no empty-map alloc); remove the
`_ = rt; _ = env;` discards at the notify sites. The main loop accepts Alt 2.

## Consequences

- `add-watch`/`remove-watch` land for atoms (the IRef family present today);
  `swap!`/`reset!`/`compare-and-set!` fire watches synchronously.
- A re-entrant `swap!` inside a watch fn reads the already-committed value
  (in-place `setCurrent` happened before notify) — matches clj.
- A future `set-validator!` + threading attach to the same cell with no re-lay.
- Affected files: `src/runtime/atom.zig` (field + accessors + trace),
  `src/lang/primitive/atom.zig` (notify + add/remove-watch + wire swap/reset/CAS),
  corpus `test/diff/clj_corpus/atom_watch.txt`, e2e `phase14_atom_watch.sh`.
