// SPDX-License-Identifier: EPL-2.0
//! Source-runner for `cljw` — the read/analyse/eval/print loop +
//! the surrounding Runtime / Env / backend / bootstrap setup. Called
//! by `app/cli.zig::dispatch` once it has resolved `source_text` from
//! one of `-e <expr>` / `<file.clj>` / `-` (stdin).
//!
//! Row 8.1 (D-031) extracted this body from `src/main.zig` so the
//! entry point shrinks to a thin argv-dispatcher. The function is
//! intentionally allocator-explicit (`io` / `gpa` / `arena` passed
//! in rather than re-deriving from `std.process.Init`) so future
//! callers (= nREPL session loop at Phase 10, build-runner at
//! Phase 12) can call `runSource` with their own allocators without
//! re-implementing the bootstrap chain.

const std = @import("std");
const Writer = std.Io.Writer;

const Reader = @import("../eval/reader.zig").Reader;
const analyzeForm = @import("../eval/analyzer/analyzer.zig").analyze;
const macro_dispatch = @import("../eval/macro_dispatch.zig");
const driver = @import("../eval/driver.zig");
const Runtime = @import("../runtime/runtime.zig").Runtime;
const Env = @import("../runtime/env.zig").Env;
const Value = @import("../runtime/value/value.zig").Value;
const primitive = @import("../lang/primitive.zig");
const macro_transforms = @import("../lang/macro_transforms.zig");
const bootstrap = @import("../lang/bootstrap.zig");
const error_print = @import("../runtime/error/print.zig");
const print = @import("../runtime/print.zig");

const error_render = @import("error_render.zig");

/// Run `source_text` to completion, printing each form's value to
/// `stdout` and renderng any error to `stderr` before exiting via
/// `error_render.renderAndExit*` (= the process terminates on the
/// first error). Sets up its own Runtime / Env / macro_table /
/// bootstrap-loaded clojure.core surface; teardown lives on the
/// caller's defer chain (`rt.deinit()` etc.) — see `app/cli.zig`.
pub fn runSource(
    io: std.Io,
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    stdout: *Writer,
    stderr: *Writer,
    source_text: []const u8,
    source_label: []const u8,
) !void {
    const ctx = error_print.SourceContext{ .file = source_label, .text = source_text };

    // --- Runtime + Env + backend setup ---
    var rt = Runtime.init(io, gpa);
    defer rt.deinit();

    var env = try Env.init(&rt);
    defer env.deinit();

    driver.installVTable(&rt);
    bootstrap.installEmbeddedResolver(&rt);
    try primitive.registerAll(&env);

    // Bootstrap macros (Phase 3.7): intern `let` / `when` / `cond` /
    // `->` / `->>` / `and` / `or` / `if-let` / `when-let` as macro
    // Vars and populate the analyzer's MacroTable. Lives long enough
    // for the entire eval loop; no per-form re-construction.
    var macro_table = macro_dispatch.Table.init(gpa);
    defer macro_table.deinit();
    try macro_transforms.registerInto(&env, &macro_table);

    // Stage-1 prologue (Phase 3.13): read+analyse+eval the embedded
    // `clj/clojure/core.clj`. Errors here use the synthetic
    // `<bootstrap>` source label and are routed through the same
    // catch path as user input — a broken prologue surfaces as a
    // diagnostic, not a panic.
    // ADR-0035 D7 / D-058 closure: bootstrap-time errors render via
    // `rt.source_registry`, which `bootstrap.loadCore` populates per
    // file. `bootstrap_ctx` remains the fallback for the first-file
    // case where the registry has not yet been populated.
    const bootstrap_ctx = error_print.SourceContext{ .file = bootstrap.SOURCE_LABEL, .text = bootstrap.CORE_SOURCE };
    bootstrap.loadCore(arena, &rt, &env, &macro_table) catch |err| {
        error_render.renderAndExitRegistry(stderr, &rt, bootstrap_ctx, err);
    };

    // --- Read - Analyse - Eval - Print loop ---
    var reader = Reader.init(arena, source_text);
    while (true) {
        const form_opt = reader.read() catch |err| {
            error_render.renderAndExit(stderr, ctx, err);
        };
        const form = form_opt orelse break;

        const node = analyzeForm(arena, &rt, &env, null, form, &macro_table) catch |err| {
            error_render.renderAndExit(stderr, ctx, err);
        };

        var locals: [driver.MAX_LOCALS]Value = [_]Value{.nil_val} ** driver.MAX_LOCALS;
        const result = driver.evalForm(&rt, &env, &locals, arena, node) catch |err| {
            error_render.renderAndExit(stderr, ctx, err);
        };

        try print.printValue(stdout, result);
        try stdout.writeByte('\n');
    }
    try stdout.flush();
}
