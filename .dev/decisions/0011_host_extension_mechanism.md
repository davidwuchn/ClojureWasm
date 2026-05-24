# 0011 — Host extension mechanism via `src/runtime/host/` directory layout

- **Status**: Superseded by ADR-0029 (2026-05-24)
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, host, extension, java-stdlib, directory-layout, superseded

## Context

The corpus references 578 distinct `java.*` classes; the top 40 alone
cover most production Clojure I/O, time, networking, and data
formatting. cw v1 cannot pretend these do not exist — even Babashka
provides cw-native equivalents for `UUID`, `Date`, `Pattern`, `Path`,
`File`, etc.

cw v0 hard-coded seven Java equivalents in `src/lang/interop/class_registry.zig`
(~221 lines). Adding new ones required editing that file. cw v1 needs
a layout that admits incremental additions without central
modification.

## Decision

Host-stdlib equivalents live under `src/runtime/host/` mirroring the
Java package structure:

```
src/runtime/host/
├── lang/        Object, String, Long, Math, System, Thread
├── io/          File, PrintWriter, ByteArrayInputStream, ...
├── util/        UUID, Date, Random, Locale, regex/Pattern
├── time/        Instant, LocalDate, LocalDateTime, Duration
├── net/         URL, URI, Socket (Phase 14+)
├── nio/         file/Path, file/Files, charset/Charset
├── math/        BigInteger, BigDecimal
├── security/    MessageDigest, SecureRandom (Phase 14+)
├── sql/         Connection, Statement, ResultSet (Phase 14+)
├── text/        SimpleDateFormat, DecimalFormat (Tier B)
├── reflect/     Method, Field (thin, via TypeDescriptor)
└── concurrent/  atomic.*, locks.* (Phase 15)
```

Each `.zig` file under `src/runtime/host/` exports a
`___HOST_EXTENSION` declaration (a `host.Extension` struct value).
A single `_host_api.zig` aggregates all entries via comptime
introspection, so a new host class plugs in with just a new file
under the right subdirectory.

User code reaches each entry through a mirrored cw namespace:
`(:require [cljw.host.java.util :refer [UUID]])`.

## Alternatives considered

### Alternative A — cw v0 `class_registry.zig` pattern

- **Sketch**: a central registry file enumerating every host class.
- **Why rejected**: every addition forces a central file edit. The
  layout signal (Java package mirror) is lost.

### Alternative B — Externally configurable host registry

- **Sketch**: load host classes from a YAML at runtime.
- **Why rejected**: Zig favors compile-time wiring; comptime
  introspection of the directory delivers the same plug-and-play
  effect without runtime configuration.

## Consequences

- **Positive**: a `java.util.OptionalInt` becomes a single new file
  under `src/runtime/host/util/optional_int.zig`. The directory
  structure itself documents the compatibility surface.
- **Negative**: discoverability depends on the discipline of placing
  the file in the right Java-package subdirectory. The
  `host_extension_layout.md` rule enforces this.
- **Neutral / follow-ups**: `compat_tiers.yaml` `host_classes`
  section enumerates every entry by FQN and target Phase. Tier
  classification per entry per ADR-0013.

## References

- ROADMAP §9.6 task 4.20 (host directory + _host_api.zig)
- ROADMAP §6.5 (Tier data source)
- Related ADRs: 0013, 0015
- Rule: `.claude/rules/host_extension_layout.md`

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
- 2026-05-24: Status: Accepted -> Superseded by ADR-0029. The
  `___HOST_EXTENSION` marker pattern (distributed registration
  replacing a central registry) carries forward, but the
  registration root moves from `runtime/host/_host_api.zig` to
  `runtime/java/_host_api.zig`, and the reserved 13
  `runtime/host/<pkg>/_placeholder.zig` files are removed. Java
  surfaces now live at `runtime/java/<pkg>/<Class>.zig`; cljw-native
  surfaces at `runtime/cljw/<area>/<Item>.zig`. Rationale: see
  ADR-0029 Context. Triggered by user-directed structural session
  (2026-05-24).
