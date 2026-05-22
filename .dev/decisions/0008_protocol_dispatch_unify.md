# 0008 — Unify `.method` and protocol dispatch through TypeDescriptor

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, dispatch, protocol, dot, host-interop

## Context

The corpus carries 5,901 distinct `.method` patterns (top 15 alone:
`.get` 1,126; `.write` 1,094; `.getName` 791 …). Constructor shorthand
`(ClassName. ...)` and `(new ClassName ...)` add several thousand more
occurrences. Threading macros (`->`, `->>`, `..`, `doto`) compound the
total.

On the JVM these reach `VarHandle`, `MethodHandle`, and ultimately
`invokevirtual` with C2's polymorphic inline cache. cw v1 has no JVM
and no JIT (Phase 17 go / no-go), so the dispatch strategy must be
designed up front.

## Decision

Every `.method` call dispatches through the same path: locate the
`MethodEntry` on the receiver's `TypeDescriptor.method_table` (a
slice sorted by interned method-symbol pointer) and invoke its
function pointer.

`(.method obj arg)` is analyzed into a call that:

1. Resolves the method symbol once at compile time.
2. Looks up `obj.typeDescriptor().lookupMethod(method)`.
3. From Phase 7 onward, a per-call-site `CallSite` cache stores the
   last `(TypeDescriptor*, method_fn)` pair for a monomorphic fast
   path.

`(ClassName. args)` is rewritten by the reader to `(new ClassName args)`.
`new` is a special form whose analyzer resolves `ClassName` to a
`TypeDescriptor` and invokes its constructor.

Host-imported types (UUID, Date, File, …) get the same machinery: a
host module under `src/runtime/host/` registers a `TypeDescriptor`
whose `method_table` points at native Zig functions. From the user's
perspective the dispatch is identical.

`import`, `doto`, and `..` are pure macros in `clojure.core.clj` and
need no special-form support beyond what `new` and `dot` already
provide.

## Alternatives considered

### Alternative A — Reflective dispatch (JVM style)

- **Sketch**: at runtime, look up method by name through a global
  registry.
- **Why rejected**: this is the path that produced JVM's
  `Reflector.java` and the corresponding performance pain. cw v1
  has no JIT to dig out from under it.

### Alternative B — Direct vtable indexing per method

- **Sketch**: assign each method-name a global integer slot; types
  store a sparse vtable indexed by slot.
- **Why rejected**: works for closed worlds, not for Clojure's
  open-world dispatch (protocols extend after the fact).

## Consequences

- **Positive**: a single dispatch path covers cw-native and
  host-imported types. `MethodEntry` is small (interned symbol + fn
  pointer). `CallSite` cache yields monomorphic dispatch hot loops.
- **Negative**: megamorphic dispatch (10+ types at one site) reverts
  to binary search through `method_table`. Acceptable for cw v1's
  target workloads; revisit at Phase 8+ if benchmarks flag a
  hotspot.
- **Neutral / follow-ups**: ADR-0007 carries the `TypeDescriptor`
  shape; ADR-0011 covers how `host` module entries register.

## References

- ROADMAP §9.6 task 4.18 (protocol dispatch table skeleton),
  task 4.25 (method_table + CallSite cache skeleton)
- Related ADRs: 0007, 0011

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
