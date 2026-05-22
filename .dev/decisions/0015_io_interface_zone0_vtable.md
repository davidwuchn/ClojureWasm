# 0015 — `io_interface.zig` as a Zone 0 vtable abstraction

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, io, zone-0, vtable, std-io-drift

## Context

cw v0 disabled five features (F140-F144: HTTP server, HTTP client,
nREPL, line editor, `cljw build` self-bundle) when the Zig 0.15→0.16
migration reshaped `std.Io`. Recovery is open-ended because every
recovered feature must follow the moving `std.Io` shape. The same
class of regression will recur with Zig 0.17 / 0.18 unless the
runtime insulates itself.

## Decision

cw v1 introduces `src/runtime/io_interface.zig` at Zone 0 (the
lowest zone — no upward imports). It exposes a vtable-style abstraction
for `Reader`, `Writer`, `Net`, and `Process` so that the rest of the
runtime depends on the abstraction, not on `std.Io` directly.

```zig
// src/runtime/io_interface.zig
pub const Writer = struct {
    vtable: *const VTable,
    ctx: *anyopaque,
    pub const VTable = struct {
        write_all: *const fn (*anyopaque, []const u8) anyerror!void,
        flush:     *const fn (*anyopaque) anyerror!void,
        close:     *const fn (*anyopaque) anyerror!void,
    };
};

pub const Reader = struct { ... };
pub const Net    = struct { ... };
pub const Process = struct { ... };
```

A concrete `runtime/io_default.zig` (Zone 1) wires the abstraction
to whatever `std.Io` ships in the current Zig version. When `std.Io`
changes, only `io_default.zig` needs revision.

`main()` constructs the default and injects it into the runtime.

### Two-tier strategy (per amendment 1)

The vtable is split into **two tiers** so that consumer code never
imports `std.Io` directly:

- **Tier 1** (`runtime/io_interface.zig`, Zone 0): the vtable
  declarations only. No `std.Io` import. Public API is `Reader` /
  `Writer` / `Net` / `Process` structs that carry a `*const VTable`
  + `*anyopaque` context. Consumer code (analyzers, REPL,
  primitives) imports this file.
- **Tier 2** (`runtime/io_default.zig`, Zone 1): the actual `std.Io`
  attachment. Constructs concrete vtable instances from `std.Io.File`,
  `std.Io.Dir`, `std.Io.Writer` etc., and exposes
  `defaultReader()` / `defaultWriter()` etc. so `main()` (Zone 3)
  injects them.

When Zig stdlib reshapes `std.Io` (the F140-F144 failure mode in
cw v0), only Tier 2 changes. Tier 1 is invariant under stdlib
churn. Consumer code never recompiles for the API surface; it only
recompiles if its own logic changed.

### File layout

```
src/runtime/
  io_interface.zig    ← Tier 1, Zone 0, no `std.Io` import
  io_default.zig      ← Tier 2, Zone 1, the only file that
                        imports `std.Io` directly for I/O ops
                        (other zones get I/O via injection)
```

Each `Tier 1` struct has a doc-comment declaring its semantic
contract (what the caller expects: blocking semantics, ownership,
error set). The `Tier 2` implementation must honour that contract;
re-implementing for a future Zig version is a Tier-2-only change.

## Alternatives considered

### Alternative A — Use `std.Io` directly throughout

- **Sketch**: the cw v0 path.
- **Why rejected**: F140-F144 cautionary precedent.

### Alternative B — Per-feature abstraction (HTTP wrapper, line editor wrapper, etc.)

- **Sketch**: each feature carries its own abstraction.
- **Why rejected**: duplication. A central vtable in Zone 0 covers
  every consumer.

## Consequences

- **Positive**: a Zig stdlib reshape affects one file. The five
  disabled v0 features can be re-implemented above this abstraction.
- **Negative**: an indirection cost per I/O call (function pointer).
  Negligible vs. system call costs.
- **Neutral / follow-ups**: clojure.java.io's `(reader x)` /
  `(writer x)` / `(input-stream x)` / `(output-stream x)` are
  implemented in `cljw.host.java.io` against the abstraction.

## References

- ROADMAP §9.6 task 4.13 (io_interface.zig Zone 0)
- ROADMAP §A1 (Zone discipline)
- cw v0 disabled features F140-F144

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
- 2026-05-23 (amendment 1): Added "Two-tier strategy" section
  documenting the Tier 1 (Zone 0, no `std.Io` import) and Tier 2
  (Zone 1, the only `std.Io`-importing file) split. Source:
  zwasm v1 D135 + `private/research-2026-05-23/INSIGHTS_ZWASM_V1.md`
  observation that Tier 2 isolation makes Zig stdlib reshape a
  one-file change instead of a project-wide recovery.
