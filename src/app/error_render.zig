// SPDX-License-Identifier: EPL-2.0
//! Top-level error rendering for `cljw` CLI sessions. Pulls the
//! threadlocal `Info` populated by `runtime/error/catalog.zig::raise`
//! and formats it via `runtime/error/print.zig`; falls back to bare
//! `@errorName(err)` so an unwired catch site still produces some
//! output instead of swallowing the failure.
//!
//! Row 8.1 (D-031) extracted these four fns from `src/main.zig` so
//! `main.zig` shrinks to a thin entry-point dispatcher. The exit-code
//! mapping (per ADR-0019) lives in `kindToExitCode`; per-Kind
//! dispatch is intentional so future Kinds (`overflow_error`,
//! `permission_error`, ...) pick their exit codes without touching
//! the catch sites.

const std = @import("std");
const Writer = std.Io.Writer;

const error_mod = @import("../runtime/error/info.zig");
const error_print = @import("../runtime/error/print.zig");
const Runtime = @import("../runtime/runtime.zig").Runtime;

/// Render a caught error to stderr. Prefers the structured threadlocal
/// `Info` (when populated by `setErrorFmt`); falls back to bare
/// `@errorName(err)` so an unwired call site still produces *some*
/// output instead of swallowing the failure.
pub fn renderError(stderr: *Writer, ctx: error_print.SourceContext, err: anyerror) Writer.Error!void {
    if (error_mod.getLastError()) |info| {
        try error_print.formatErrorWithContext(info, ctx, stderr, .{});
    } else {
        try stderr.print("{s}: error: {s}\n", .{ ctx.file, @errorName(err) });
    }
    try stderr.flush();
}

/// Map a `Kind` to the process exit code per ADR-0019. The catalog
/// `internal_error` Code is the sole exit-70 path; every other Kind
/// is a user-facing catalog error and exits 1.
pub fn kindToExitCode(kind: error_mod.Kind) u8 {
    return switch (kind) {
        .internal_error => 70,
        else => 1,
    };
}

/// Peek the threadlocal `Info` (without consuming it), pick the
/// matching exit code per ADR-0019, render the error, then exit.
/// Centralises the "catch site exits the process" pattern so future
/// Kinds need only update `kindToExitCode`.
pub fn renderAndExit(stderr: *Writer, ctx: error_print.SourceContext, err: anyerror) noreturn {
    const code: u8 = if (error_mod.peekLastError()) |info|
        kindToExitCode(info.kind)
    else
        1;
    renderError(stderr, ctx, err) catch {
        // stderr write failed (closed pipe?); proceed to exit anyway —
        // the alternative is swallowing the failure silently.
    };
    std.process.exit(code);
}

/// Registry-aware variant of `renderAndExit`. ADR-0035 D7: looks up
/// `info.location.file` in `rt.source_registry` for the per-file
/// source-line preview; falls back to `default_ctx` when the location
/// is unknown or not registered.
pub fn renderAndExitRegistry(
    stderr: *Writer,
    rt: *Runtime,
    default_ctx: error_print.SourceContext,
    err: anyerror,
) noreturn {
    const code: u8 = if (error_mod.peekLastError()) |info|
        kindToExitCode(info.kind)
    else
        1;
    if (error_mod.getLastError()) |info| {
        error_print.formatErrorWithRegistry(info, rt, default_ctx, stderr, .{}) catch {};
        stderr.flush() catch {};
    } else {
        stderr.print("{s}: error: {s}\n", .{ default_ctx.file, @errorName(err) }) catch {};
        stderr.flush() catch {};
    }
    std.process.exit(code);
}
