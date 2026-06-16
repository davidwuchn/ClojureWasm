# ADR-0152 — `:volatile-mutable` deftype fields get cross-thread happens-before

- **Status**: Proposed → Accepted (2026-06-16)
- **Context drivers**: D-444 (gap area I — Concurrency, F-015), un-accepts AD-018.
- **Supersedes**: AD-018 (the "unified assignable flag while single-threaded" accept).

## Context

On the JVM, `deftype`'s two mutable-field keywords differ only in cross-thread
memory visibility: `^:volatile-mutable` compiles to a `volatile` field (JMM
happens-before ordering); `^:unsynchronized-mutable` compiles to a plain field
(no ordering — sharing it across threads without external synchronisation is a
data race = undefined under the JMM).

cljw collapses both into one "assignable" flag: a plain in-place slot write
(`TypedInstance.setField`, ADR-0104) + a plain read. AD-018 accepted this on the
rationale "cljw is single-threaded." **That rationale is now false** — future /
agent drainers run user code on real OS threads (F-015 / ADR-0142). A deftype
instance with a `:volatile-mutable` field can be shared (in an atom / ref /
agent) and mutated via a method on one thread while read on another, so the
missing happens-before is a real correctness bug, not a dormant divergence.

## Decision

Un-accept AD-018 and make the keyword distinction **observably real**:

- `:volatile-mutable` field READ → `@atomicLoad(.acquire)`; WRITE → `@atomicStore(.release)`.
- `:unsynchronized-mutable` field → unchanged plain slot access (this is the
  JVM-faithful behaviour: a plain field shared across threads is a data race
  on the JVM too, so leaving it plain is parity, **not** a hole).

Mechanism: thread the field KIND (volatile vs unsynchronized) from the deftype
macro's keyword parse onto a per-field flag on `TypeDescriptor`'s field-entry,
and branch the read + `set!` accessor on it. Both backends (tree_walk + vm)
route through one accessor so the branch lives in a single place.

### Memory ordering: acquire/release, uniform with cljw's volatile-grade substrate

cljw's entire lock-free substrate uses `.acquire`/`.release` (CAS: `.acq_rel`/
`.acquire`), never `.seq_cst`: `atom.zig`, `volatile.zig` (whose docstring
already calls a volatile "JMM-volatile"), `iref.zig`, `agent.zig`.
`:volatile-mutable` **joins that convention** rather than becoming a `.seq_cst`
outlier stronger than its own siblings.

The DA fork (below) correctly notes that literal JMM `volatile` is sequentially
consistent *across independent volatile accesses* (the IRIW / two-independent-
volatiles total-order property), which `.acquire`/`.release` does **not** give —
acquire/release synchronises a release-store with the acquire-load that *reads
that value*, but imposes no total order over independent locations. So
acquire/release is exactly sufficient for the dominant single-field
publish/consume pattern (≥99.9% of real code) and weaker than the JVM only for
the pathological multi-volatile cross-thread-relative-ordering case.

This residual is **consciously elected** (not a cycle-budget defer): cljw's
finished form is a *uniform* acquire/release volatile-grade ordering across all
its concurrency cells, with the IRIW cross-cell total-order gap recorded once as
an accepted sub-divergence (AD-034) that covers atom / volatile / iref / agent /
volatile-mutable alike. A lone `.seq_cst` for `:volatile-mutable` (or a
project-wide `.seq_cst` sweep for a guarantee no real Clojure code depends on)
would be the *less* clean finished form — internal inconsistency, or a fence
tax everywhere for an unused property.

Note: a naturally-aligned 8-byte `Value` (NaN-boxed u64) load/store is already
hardware-atomic on aarch64/x86_64 — the atomic builtin is needed only for the
ordering fence + to stop the compiler reordering/coalescing the access.

## Testability

Happens-before is non-deterministic and has no sound deterministic test (a
missing fence manifests only probabilistically under contention, and never on
strongly-ordered x86_64). The honest coverage ceiling — the same epistemic
status the existing atom/agent code lives with — is:

1. **By-construction wiring**: a unit test that a `:volatile-mutable` field
   routes through the atomic accessor and `:unsynchronized-mutable` through the
   plain one.
2. **Single-threaded preservation**: the existing deftype-mutable e2e/pin stays
   green (atomic ops on an uncontended word = ordered plain ops).

A probabilistic N-thread stress test is **NOT** gate-added (flaky, false-green
on x86_64; a future Layer-7 Concurrency on-demand harness per test_taxonomy.md).

## Alternatives considered (Devil's-advocate fork, fresh context — verbatim digest)

- **Alt 1 — smallest-diff (keep AD-018, doc-only warning)**: zero cost / zero
  blast radius / honest about the testability ceiling. REJECTED — F-011-non-
  compliant: a silently-stale cross-thread read is a correctness bug a warning
  does not fix (Defer-to-amnesia / Smallest-diff-bias smell). Leading rejected
  alternative.
- **Alt 2 — finished-form (per-field flag + atomic accessor, RECOMMENDED by DA
  and CHOSEN)**: correct JMM parity for the publish/consume case; makes the
  keyword distinction observably real; keeps `:unsynchronized-mutable` plain
  (= JVM parity, not a hole); single-threaded behaviour bit-for-bit preserved.
  Costs a `FieldEntry` flag + a predictable per-access branch.
- **Alt 3 — wildcard (route ALL mutable fields through acquire/release, no
  per-field flag)**: simplest runtime surgery, never under-orders. REJECTED —
  over-orders `:unsynchronized-mutable` (a guarantee the JVM does not give +
  re-erases the keyword distinction = a flavour of AD-018 reopened) and taxes
  the exact tight-loop use-case the keyword exists to make cheap.
- **Ordering — seq_cst vs acquire/release**: DA's literal-JMM recommendation was
  `.seq_cst` (IRIW total order) with a follow-on to upgrade the sibling cells.
  This ADR instead elects uniform acquire/release + AD-034 for the IRIW gap, on
  internal-consistency + real-code-irrelevance grounds (see Decision). The DA's
  caveat — "do not pick acquire/release silently on cycle-budget grounds" — is
  honoured: the election is on finished-form/consistency grounds, recorded here.

## Consequences

- `:volatile-mutable` fields now have cross-thread happens-before (publish/
  consume); `:unsynchronized-mutable` unchanged (JVM-faithful plain access).
- New **AD-034**: cljw volatile-grade cells use acquire/release; the JMM
  cross-independent-volatile (IRIW) total order is not guaranteed (derives from
  this ADR's uniform-acquire/release election; real Clojure code does not depend
  on it). `pin`: the by-construction wiring test.
- AD-018 removed from the ledger (un-accepted → fixed).

## Affected files (implementation plan)

- deftype macro (`src/lang/.../macro_transforms.zig`) — parse `^:volatile-mutable`
  vs `^:unsynchronized-mutable`, carry the kind.
- `src/runtime/type_descriptor.zig` — per-field volatility flag on the field
  entry + `setFieldVolatile`/`getFieldVolatile` (`@atomicStore(.release)` /
  `@atomicLoad(.acquire)`).
- `src/eval/backend/tree_walk.zig` + `src/eval/backend/vm.zig` — field read +
  `set!` route a volatile field through the atomic accessor.
- `.dev/accepted_divergences.yaml` — remove AD-018, add AD-034.
- tests — by-construction wiring unit test + keep the deftype-mutable e2e pin.
