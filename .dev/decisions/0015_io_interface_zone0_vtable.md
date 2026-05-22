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
