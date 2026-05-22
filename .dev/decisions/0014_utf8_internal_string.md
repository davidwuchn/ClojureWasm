# 0014 — UTF-8 as the internal string representation

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, string, utf-8, encoding, char

## Context

JVM Clojure inherits Java's UTF-16 internal string representation.
This forced JVM Clojure into a `char` data type that is a 16-bit
code unit, sometimes splitting a Unicode code point across two
chars (the surrogate pair issue). Many user APIs (`(.length s)`,
`(subs s i j)`) operate in those 16-bit units.

cw v1 has no compelling reason to inherit UTF-16: the runtime is
native, the I/O layer (ADR-0015) is UTF-8 by default, Zig's
`std.fs` / `std.io` deliver bytes, and Babashka — the existing
JVM-free Clojure precedent — likewise uses UTF-8 inside.

## Decision

cw v1 stores strings internally as UTF-8. String length, indexing,
and iteration operate on either bytes or code points depending on
the API; the difference is documented per function in the host
stdlib (ADR-0011).

Mapping to the user-facing Clojure API:

- `(count s)` returns the number of **code points** (Clojure-compatible
  observable behavior).
- `(.length s)` mirrors `(count s)`. On the JVM `.length` reports
  16-bit code units; on cw v1 it reports code points. This is a
  documented deviation in `DIFFERENCES.md` (Tier A with a footnote)
  rather than a separate Tier C: well-behaved Unicode-aware code is
  unaffected; only code that relies on surrogate-pair quirks
  diverges.
- `(.charAt s i)` returns the i-th **code point** as a single
  `cljw.host.java.lang.Character`. Surrogate pairs are not exposed.
- `(.getBytes s)` is the byte view (UTF-8); `(.toCharArray s)` is
  the code-point view.

Conversion at the boundary uses `std.unicode` (Zig stdlib).

## Alternatives considered

### Alternative A — UTF-16 internal (JVM compatibility)

- **Sketch**: store strings as `[]u16`.
- **Why rejected**: surrogate pairs add complexity throughout. Zig's
  I/O layer is UTF-8 native, so every read / write would pay a
  conversion.

### Alternative B — UTF-32 (code-point arrays)

- **Sketch**: store strings as `[]u32`.
- **Why rejected**: 4x memory overhead for ASCII-dominated text.
  Tradeoff against rare random-access does not favor it.

## Consequences

- **Positive**: matches Zig stdlib and the I/O layer (ADR-0015). No
  surrogate-pair pitfalls in cw native code. ASCII-heavy strings
  carry no overhead.
- **Negative**: JVM Clojure code that uses `.length` as a 16-bit
  code-unit count produces a different value on cw. This is a
  documented Tier A footnote, not a Tier C divergence.
- **Neutral / follow-ups**: `cljw.host.java.lang.Character` is the
  cw representation of a single code point. Phase 5+ string
  primitives operate on either bytes or code points; documentation
  per function.

## References

- ROADMAP §6 (Tier system)
- Related ADRs: 0011, 0015

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
