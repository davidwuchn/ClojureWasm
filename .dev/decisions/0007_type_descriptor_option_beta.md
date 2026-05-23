# 0007 — TypeDescriptor (Option β) for the cw class system

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, class-system, type-descriptor, dispatch, option-beta

## Context

A corpus audit of 165 mainstream Clojure libraries found `deftype`
1,514, `defrecord` 1,375, `reify` 1,471, and `definterface` 103
occurrences — together with `class` / `instance?` / `type` dispatch
that pervades Clojure code. Without a Class-like construct, the
ecosystem largely does not run.

cw v1 has three logical options:

- **α** (no Class concept) — keyword-only `type`, no `deftype`. Drops
  most of Clojure.
- **β** (cw TypeDescriptor) — a Zig-native struct that plays the role
  JVM's Class plays for Clojure, without inheriting JVM's design
  (no bytecode generation, no reflection runtime).
- **δ** (full JVM Class emulation) — same path cw v0 took and got
  stuck on.

Babashka follows path β successfully. cw v1 commits to the same
direction at design level, while implementing differently to exploit
Zig's comptime and packed-struct strengths.

## Decision

cw v1 adopts Option β. The runtime carries a `TypeDescriptor` struct
that:

- Holds `fqcn` (interned symbol), `kind`
  (`native | deftype | defrecord | reify_anon`), optional
  `field_layout`, `protocol_impls`, `method_table`, optional `parent`,
  and `meta`.
- Lives in the namespace it is registered into (lifetime tied to the
  namespace).
- Backs `(class x)`, `(instance? T x)`, and `(type x)` dispatch.

`TypedInstance` (`deftype` / `defrecord` runtime value) holds a
pointer to its `TypeDescriptor` and an inline `field_values` slice
sized by `field_layout.len` at creation time.

`reify` produces an anonymous `TypeDescriptor` (no `fqcn`) whose
`method_table` is populated from the form. Closed-over locals live in
`ReifiedInstance`.

Field layout is determined at analyzer time. Zig's `comptime` is used
where the field count and types are known statically (specialised
deftype emit); otherwise a runtime `[]Value` slice carries the data.

## Alternatives considered

### Alternative α — No Class system

- **Sketch**: drop `deftype`/`defrecord`/`reify`, return `keyword`
  from `(class x)`, no per-call-site dispatch cache.
- **Why rejected**: corpus audit shows 4,463 occurrences across the
  major libraries; the ecosystem would not run.

### Alternative δ — JVM Class emulation

- **Sketch**: implement Class hierarchy, reflection runtime, bytecode
  generation.
- **Why rejected**: cw v0 fell into this trap (89K LOC, F140-F144).
  Out of scope for cw v1.

## Consequences

- **Positive**: 4,463 corpus occurrences become reachable. `class` /
  `instance?` / `type` work. `deftype` / `defrecord` / `reify` /
  `definterface` work. The cw v1 runtime stays small.
- **Negative**: a `TypeDescriptor` is not a JVM `Class`. Code that
  passes `Class` objects through `java.lang.reflect.*` will not work;
  this is covered under Tier D in ADR-0013.
- **Neutral / follow-ups**: ADR-0008 wires `.method` dispatch on top
  of `TypeDescriptor.method_table`. ADR-0012 finalizes the `ValueTag`
  slots that reference `TypeDescriptor` / `TypedInstance` /
  `ReifiedInstance`. The concrete Zig struct layout lives in the cw
  runtime source.

## Phase 5+ migration note (amendment 1)

The Phase 4 skeleton (task 4.17) declares `TypeDescriptor` /
`TypedInstance` / `ReifiedInstance` structs without operations.
Phase 5 entry activation includes a rewrite, not just adding:

- `TypeDescriptor.lookupMethod` / `register` / `new` implementation
  lands.
- Existing Phase 1-3 primitives in `src/runtime/collection/*.zig`
  (`string` / `list` / `keyword` / `symbol`) and the Value model gain
  a back-pointer (or `ValueTag` route) to a native `TypeDescriptor`
  registered at runtime init. The primitive struct shape changes;
  this rewrites code already written in Phase 1-3.
- `(class x)` / `(instance? T x)` / `(type x)` switch from the
  Phase 3 keyword-only `type` dispatch to `TypeDescriptor`-based
  dispatch.

The rewrite is expected, not technical debt, per ROADMAP §A25.
principle.md depth 3 (cross-file refactor) is the typical depth;
depth 4 only if the Value model itself needs a new ADR.

## References

- ROADMAP §A11 (Day-one enum reservation)
- ROADMAP §A25 (Existing code is mutable)
- ROADMAP §9.6 task 4.17 (TypeDescriptor skeleton)
- ROADMAP §9.7 (Phase 5 entry — Skeletons to activate)
- Related ADRs: 0004, 0008, 0012, 0013
- Babashka precedent: sci.impl.records / sci.impl.types

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
- 2026-05-23 (amendment 1): Added "Phase 5+ migration note" section
  to narrate the rewrite scope when task 4.17 skeleton activates
  in Phase 5 (per ROADMAP §A25).
