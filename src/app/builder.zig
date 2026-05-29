// SPDX-License-Identifier: EPL-2.0
//! `cljw build` — compile a Clojure source to a serialized bytecode
//! payload envelope (D-100(b), ADR-0034 amendment 1 Alt B). Each
//! top-level form compiles to one `BytecodeChunk`; the chunks are framed
//! by `serialize.serializeEnvelope`. This module is the **compile core**:
//! it turns already-bootstrapped runtime state + source text into the
//! payload bytes. The Deno-style binary trailer (runtime + payload +
//! `"CLJC"` footer) and the `cljw build app.clj -o app` CLI dispatch
//! layer above this in later steps.
//!
//! Backend: surface-only (Layer 3 → eval/runtime impl). Impl deps:
//! serialize, vm/compiler, analyzer. Clojure peer: none.
//!
//! F-009 note: `runner.runSource` already owns the bootstrap chain
//! (Runtime / Env / macro_table / loadCore) and is documented as the
//! shared entry for "the build-runner"; this core takes that state as
//! parameters rather than re-deriving it, so the eventual CLI path wires
//! the same setup once and feeds both run and build.

const std = @import("std");
const Runtime = @import("../runtime/runtime.zig").Runtime;
const Env = @import("../runtime/env.zig").Env;
const Reader = @import("../eval/reader.zig").Reader;
const analyzeForm = @import("../eval/analyzer/analyzer.zig").analyze;
const macro_dispatch = @import("../eval/macro_dispatch.zig");
const vm_compiler = @import("../eval/backend/vm/compiler.zig");
const serialize = @import("../eval/bytecode/serialize.zig");
const BytecodeChunk = @import("../eval/backend/vm/opcode.zig").BytecodeChunk;

/// Compile every top-level form in `source_text` to a `BytecodeChunk`
/// and return the serialized payload envelope (caller frees the bytes
/// via `allocator.free`). The runtime / env / macro_table must already
/// be bootstrapped (`loadCore` done) by the caller.
///
/// The compiled chunks' slices are allocated from `arena`
/// (`vm_compiler.compile` uses it), so `serializeEnvelope` copies their
/// bytes and the chunks need no per-chunk free — the caller's arena owns
/// them.
pub fn buildEnvelope(
    allocator: std.mem.Allocator,
    rt: *Runtime,
    env: *Env,
    macro_table: *macro_dispatch.Table,
    arena: std.mem.Allocator,
    source_text: []const u8,
) ![]u8 {
    var chunks: std.ArrayList(BytecodeChunk) = .empty;
    defer chunks.deinit(allocator);

    var reader = Reader.init(arena, source_text);
    while (true) {
        const form = (try reader.read()) orelse break;
        const node = try analyzeForm(arena, rt, env, null, form, macro_table);
        const chunk = try vm_compiler.compile(rt, arena, node);
        try chunks.append(allocator, chunk);
    }
    return serialize.serializeEnvelope(allocator, chunks.items);
}

// --- tests ---

const testing = std.testing;
const driver = @import("../eval/driver.zig");
const primitive = @import("../lang/primitive.zig");
const macro_transforms = @import("../lang/macro_transforms.zig");
const bootstrap = @import("../lang/bootstrap.zig");

test "buildEnvelope compiles two forms into a two-chunk envelope" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();
    var env = try Env.init(&rt);
    defer env.deinit();

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    driver.installVTable(&rt);
    bootstrap.installEmbeddedResolver(&rt);
    try primitive.registerAll(&env);
    var macro_table = macro_dispatch.Table.init(testing.allocator);
    defer macro_table.deinit();
    try macro_transforms.registerInto(&env, &macro_table);
    try bootstrap.loadCore(arena, &rt, &env, &macro_table);

    const bytes = try buildEnvelope(testing.allocator, &rt, &env, &macro_table, arena, "(+ 1 2) (* 3 4)");
    defer testing.allocator.free(bytes);

    const chunks = try serialize.deserializeEnvelope(testing.allocator, &rt, &env, bytes);
    defer serialize.freeEnvelope(testing.allocator, chunks);

    // Two top-level forms → two chunks, in source order, each with a
    // non-empty instruction stream (the compiler emits at least op_ret).
    try testing.expectEqual(@as(usize, 2), chunks.len);
    try testing.expect(chunks[0].instructions.len > 0);
    try testing.expect(chunks[1].instructions.len > 0);
}
