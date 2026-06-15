# ADR-0144 — `defprotocol :extend-via-metadata true` dispatch

- **Status**: Proposed → Accepted (2026-06-15)
- **Amends**: ADR-0008 (protocol dispatch unify) — adds a metadata-fallback
  precedence step to the protocol-fn dispatch path. ADR-0068 (protocol_impls
  SSOT) is untouched: metadata extension is per-VALUE, not a declared interface.
- **Debt**: D-314 (discharged by this ADR's implementation).
- **Devil's-advocate**: `private/notes/D314-da-structural.md` (full output;
  alternatives reflected below).

## Context

Clojure's `(defprotocol P :extend-via-metadata true (m [x]))` lets a value
supply a protocol-method impl through its **metadata**: a fn stored under the
protocol-defining-ns-qualified method **symbol** (e.g. `user/m`) dispatches when
the protocol method is called on that value. Used by honeysql (the InlineValue /
`sqlize` protocol) and clojure.datafy (Datafiable / Navigable).

cljw PARSED the option (the protocol loads) but DROPPED the flag (D-314): it was
never threaded to the protocol descriptor, and dispatch never consulted receiver
metadata, so a value carrying `^{user/m fn}` hit `protocol_no_satisfies`.

### clj contract (oracle-verified 2026-06-15)

- **Key = namespaced method SYMBOL** (`user/sized`), NOT a keyword. A keyword key
  does not match (clj raises "No implementation").
- **Precedence**: on-interface-instance > **receiver-metadata** > registered
  extend-type/Object impl > no-method. i.e. **metadata beats extend-type** (looser
  than D-314's original "fall back when no impl" wording).
- **`satisfies?` / `extends?` IGNORE metadata** → `false` for a meta-only
  extension (they read the descriptor's impl SSOTs, not the value's meta).

## Decision

**Alt 1 — metadata-dispatch as a Layer-0 helper invoked from the protocol-fn
dispatch entry.**

1. Add `extend_via_metadata: bool` to `ProtocolDescriptor` (consumes one of the 6
   reserved `_pad` bytes — ABI-clean, F-004). Threaded: `expandDefprotocol` emits
   a 3rd arg to `rt/__make-protocol!` when `:extend-via-metadata true` is parsed;
   the primitive `makeProtocol` accepts 2-or-3 args (default false for the 2-arg
   bootstrap forms); `runtime/protocol.zig::makeProtocol` sets the field.
2. Extract the unified meta read into a Layer-0 `runtime/meta.zig::metaOf`
   (the switch currently in `lang/primitive/metadata.zig::metaFn`, all of whose
   reads are Layer-0); `metaFn` delegates to it (F-011 commonization — one meta
   read, not two). This gives the Layer-0 dispatch path a meta reader without the
   Layer-2 `metadata.zig` (zone_deps: Layer 0/1 must not import Layer 2).
3. Add `dispatch.metaDispatch(rt, env, descriptor, receiver, method_name, args,
   loc) anyerror!?Value` (Layer 0): when `descriptor.extend_via_metadata`, read
   `meta.metaOf(receiver)`; if it is a map, build the qualified method symbol
   (`symbol.intern(rt, defining_ns, method_name)`, `defining_ns` = the
   descriptor fqcn's prefix before the last `/`); `map.get` it; if a callable
   value, invoke via `rt.vtable.callFn` and return it. Else `null` (fall through).
4. `tree_walk.callProtocolFn` calls `metaDispatch` **before** `dispatch.dispatch`:
   `if (try dispatch.metaDispatch(...)) |v| return v;`. Both backends route
   protocol-fn calls through `callProtocolFn` (VM wires `.callFn =
   tree_walk.treeWalkCall`, vm.zig:1391), so this single site serves both.

### Precedence (matches clj)

`callProtocolFn` runs `metaDispatch` first, so **metadata beats extend-type**
(metaDispatch returns before `dispatch.dispatch`'s type-impl / Object-default /
raise chain). Gated on the flag → non-metadata protocols pay nothing. Minor
divergence: clj's on-interface (a JVM-interface-implementing class) beats
metadata; cljw has no generated JVM interface, so a deftype that BOTH
inline-implements the protocol AND a specific instance carries an overriding
`^{ns/m fn}` would let metadata win where clj's on-interface would not. This is a
pathological corner (no realistic code) — documented, not chased.

### Cache-bypass (load-bearing correctness)

The per-`CallSite` cache keys on the receiver's **TypeDescriptor** (per-TYPE);
metadata is **per-VALUE** (two instances of one type carry different/no meta; a
`(with-meta {} {…})` map shares its TD with every map). `metaDispatch` runs as a
separate branch that returns on hit **without** calling `dispatch.dispatch`/
`dispatchOrNull`, so a meta hit never writes the per-type cache slot (which would
poison every other value of that type). Pinned by a unit test: two instances of
one deftype — one with meta, one without — dispatch differently in either order.

### `satisfies?` unchanged

cljw `satisfies?`/`extends?` read the descriptor's impl SSOTs, not the value's
meta, so a meta-only extension reports `false` — matches clj for free. Pinned by
an e2e case so a future change can't make `satisfies?` peek at meta.

## Alternatives considered (Devil's-advocate, fresh context)

The DA's leading finding: `dispatch.dispatch`'s SIGNATURE carries only strings,
but `callProtocolFn` (its descriptor-holding caller) already holds
`pfn.descriptor` and throws it away as `.fqcn()`. So no registry is needed for
the `(m x)` path. The DA enumerated:

- **Alt 1 (chosen) — flag on descriptor, metadata probe at the protocol-fn
  entry.** Zero new Runtime state; the flag rides the descriptor; cache-bypass
  natural (probe before `dispatch.dispatch`).
- **Alt 2 (DA-recommended) — thread the `descriptor` into Layer-0
  `dispatch.dispatch`** so the whole precedence lives in one function (DA cited
  F-011/DRY). Cost the DA surfaced: callers without a descriptor need one.
- **Alt 3 (rejected by DA) — name→descriptor registry on `rt`.** Pays a
  per-dispatch hash lookup to recover a pointer the caller already held; the
  reusable index it builds is D-443 (reflection) forward-debt, not D-314's need.

**Why the main loop chose Alt 1 over the DA's Alt 2 (NOT a cycle-budget
decision):** verification (not available to the DA) showed `dispatch.dispatch`
has **18+ callers** — the polymorphic primitives (`sorted.zig`, `sequence.zig`,
`collection.zig`) dispatch built-in protocols (`Associative`, `Sorted`,
`IPersistentCollection`, `Seqable`, …) by hardcoded string with **no
descriptor**. None of those built-in protocols are extend-via-metadata, and a
user-defined extend-via-metadata protocol dispatches ONLY via `callProtocolFn`.
So Alt 2 would force a `null`/descriptor argument across 18+ sites to thread a
flag meaningful to exactly **one** caller — noise, not unification, and it would
need a "well-known-descriptor set on Runtime" for the built-in-protocol callers
(a back-door registry, the very thing Alt 3 was rejected for). The metadata
step's semantic scope **is** the protocol-fn path; placing the logic in a Layer-0
helper (`dispatch.metaDispatch`, co-located with dispatch policy in
`dispatch.zig`) invoked from `callProtocolFn` keeps the policy in Layer 0 (the
DA's F-011 spirit) without polluting the shared `dispatch.dispatch` hot path.
This choice survives an equal-diff-size test (Alt 1 scopes the metadata step
correctly even if Alt 2 were the same size), so it is finished-form-grounded.
Alt 3 rejected on F-002 (premature reflection registry = D-443 scope-bleed).

## Consequences

- `(defprotocol P :extend-via-metadata true …)` now dispatches via receiver
  metadata under the namespaced method symbol key, matching clj, including
  metadata-beats-extend-type precedence and `satisfies?` ignoring metadata.
- `runtime/meta.zig` is the new Layer-0 SSOT for "a value's metadata map";
  `metaFn` (the `(meta x)` primitive) delegates to it — one meta read.
- Existing protocols (flag unset) are unaffected: `metaDispatch` returns `null`
  immediately, no meta read, no hot-path cost.
- The deftype-inline-vs-metadata pathological corner is a documented minor
  divergence (no AD row — not realistically constructible; revisit only if hit).

## Affected files

- `src/runtime/protocol.zig` — `ProtocolDescriptor.extend_via_metadata` + `makeProtocol` param.
- `src/runtime/meta.zig` — NEW: Layer-0 `metaOf` (extracted from `metaFn`).
- `src/lang/primitive/metadata.zig` — `metaFn` delegates to `meta.metaOf`.
- `src/runtime/dispatch.zig` — `metaDispatch` helper.
- `src/eval/backend/tree_walk.zig` — `callProtocolFn` calls `metaDispatch` first.
- `src/lang/macro_transforms.zig` — `expandDefprotocol` emits the flag arg.
- `src/lang/primitive/protocol.zig` — `makeProtocol` reads `args[2]`.
- `test/e2e/phase16_extend_via_metadata.sh` — the behavioural pins.
