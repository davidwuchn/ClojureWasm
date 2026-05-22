# 0017 — Allocator strategy: per-eval arena + general-purpose + mark-sweep heap

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, allocator, gc, memory, mark-sweep, arena

## Context

JVM Clojure relies on the JVM's generational garbage collector. cw v1
has no built-in GC; allocation strategy is a deliberate design
choice. Three considerations drive it:

1. **Most values are short-lived**: a single REPL evaluation produces
   many transient list / map / closure objects that all die when the
   evaluation completes.
2. **Some values are long-lived**: deftype instances, atom contents,
   namespace bindings, var roots persist across evaluations.
3. **The runtime is batch / REPL oriented**: stop-the-world pauses on
   the order of 100ms are acceptable in exchange for GC simplicity.
   Low-pause behaviour (G1 / ZGC class) is not a requirement.

## Decision

cw v1 uses three allocators with distinct roles:

### Per-evaluation arena (`std.heap.ArenaAllocator`)

Created at the start of each top-level evaluation, freed in bulk at
the end. Backs short-lived values: intermediate seq pipeline output,
ex-info data created mid-evaluation, transient buffers, analyzer
scratch.

Phase 4 entry: the arena pattern is already in use; this ADR
formalizes it as the canonical short-lived path.

### General-purpose allocator (`std.heap.GeneralPurposeAllocator`)

Backs long-lived heap allocations whose lifetime is not tied to a
single evaluation: deftype instances, atom contents, var roots,
namespace bindings.

In Debug builds, the GPA tracks leaks. In Release builds, it falls
back to the page allocator with minimal metadata.

### Mark-sweep GC heap

A subset of long-lived allocations participates in mark-sweep GC. The
heap is a `GcHeap` value: it owns a list of tracked objects, each
carrying a `gc_mark` bit (ADR-0009 `ObjectHeader.gc_and_lock`).
Collection runs when the tracked-object count exceeds a threshold or
when explicitly requested.

Phase 5 brings the mark-sweep implementation online. Phase 4 entry
reserves the bit slot in `ObjectHeader` but does no collection (the
allocator simply allocates).

### Phase staging

- Phase 4 entry: declarations only (`gc_mark` bit reserved in the
  packed header, GcHeap struct exists without a sweep function).
- Phase 5: mark-sweep implementation, threshold-based collection,
  test coverage for unreachable cycles.
- Phase 15+: re-evaluate generational GC based on bench data.

## Alternatives considered

### Alternative A — Generational GC from day 1

- **Sketch**: implement young / old generation.
- **Why rejected**: the per-eval arena already captures most of the
  short-lived population. Generational GC adds card-table complexity
  for a benefit (minor-GC throughput) that arena allocation already
  delivers.

### Alternative B — Reference counting

- **Sketch**: each heap value carries a refcount.
- **Why rejected**: persistent collection structural sharing creates
  long cycles when shared subtrees are released; reference counting
  pays write barriers on every assoc.

### Alternative C — Stop-the-world only, no concurrent GC

- **Sketch**: never run GC concurrently with mutator.
- **Decision**: this is what cw v1 does for Phase 5. Concurrent GC
  is a Phase 15+ re-evaluation if pause time becomes a problem.

## Consequences

- **Positive**: simple three-allocator model with clear lifetimes.
  Short-lived population (the majority) never reaches GC. Long-lived
  population gets mark-sweep, which is simple to implement and audit.
- **Negative**: stop-the-world pause may reach 100ms on large heaps.
  Acceptable for cw v1's batch / REPL workloads.
- **Neutral / follow-ups**: Phase 5 mark-sweep test suite covers
  cyclic references, structural sharing, transient -> persistent
  handoff.

## References

- ROADMAP §9.6 task 4.0 (bench harness will measure pause time)
- Related ADRs: 0009 (ObjectHeader gc_mark slot), 0007
- JVM_TO_ZIG.md §3 (working notes)

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
