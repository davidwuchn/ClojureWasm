// SPDX-License-Identifier: EPL-2.0
//! cljw `wasm` namespace — the polyglot Wasm FFI surface (ADR-0099 / CFP P1).
//! `(wasm/load "path.wasm")` embeds + instantiates a module via zwasm v2 and
//! returns an opaque handle; `(wasm/call handle "export" & args)` invokes an
//! export by name, marshalling args/results from the export's runtime signature.
//! Compiled + registered ONLY under `-Dwasm` (`build_options.wasm`); the default
//! build never resolves zwasm (F-001).
//!
//! The builtin fns live in the surface tree (runtime/cljw/**) per ADR-0029 D2:
//! lang/primitive/ may not import a surface, so the host fns + their ns
//! registration live here and are wired via runtime/cljw/_host_api.zig.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: wasm/load, wasm/call
const engine = @import("engine.zig");
const marshal = @import("marshal.zig");
const wasm_handle = @import("wasm_handle.zig");
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const Value = @import("../../value/value.zig").Value;
const error_catalog = @import("../../error/catalog.zig");
const SourceLocation = @import("../../error/info.zig").SourceLocation;
const string_mod = @import("../../collection/string.zig");
const vector_mod = @import("../../collection/vector.zig");
const file_io = @import("../../file_io.zig");

/// `(wasm/load "path.wasm")` — read the file, compile + instantiate it via
/// zwasm v2, and return an opaque instance handle. F-006: the engine is given
/// `rt.gpa` (the layer-1 backing allocator), keeping zwasm's space separate
/// from the cljw GC heap.
pub fn wasmLoadFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("wasm/load", args, 1, loc);
    if (!args[0].isString())
        return error_catalog.raiseInternal(loc, "wasm/load: expected a string path");
    const path = string_mod.asString(args[0]);

    const bytes = file_io.readAll(rt.io, rt.gpa, path) catch
        return error_catalog.raiseInternal(loc, "wasm/load: cannot read the .wasm file");
    defer rt.gpa.free(bytes);

    const loaded = engine.load(rt.gpa, bytes) catch
        return error_catalog.raiseInternal(loc, "wasm/load: failed to compile/instantiate the module");
    return wasm_handle.wrap(rt, loaded);
}

/// `(wasm/call handle "export" & args)` — invoke an export by name. Arg/result
/// types come from the export's runtime signature; a single result is returned
/// as a scalar, multiple as a vector, none as nil.
pub fn wasmCallFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArityMin("wasm/call", args, 2, loc);
    if (!wasm_handle.isHandle(args[0]))
        return error_catalog.raiseInternal(loc, "wasm/call: first argument is not a loaded wasm module");
    if (!args[1].isString())
        return error_catalog.raiseInternal(loc, "wasm/call: export name must be a string");

    const loaded = wasm_handle.unwrap(args[0]);
    const name = string_mod.asString(args[1]);
    const call_args = args[2..];

    const sig = loaded.exportSig(name) orelse
        return error_catalog.raiseInternal(loc, "wasm/call: no such exported function");
    if (call_args.len != sig.params.len)
        return error_catalog.raiseInternal(loc, "wasm/call: wrong number of arguments for the export");

    // Marshal args in + size the results buffer. Both are short-lived
    // host-side scratch on rt.gpa (the wasm boundary, not cljw Values).
    const in = try rt.gpa.alloc(engine.Value, sig.params.len);
    defer rt.gpa.free(in);
    for (call_args, sig.params, 0..) |a, vt, i| in[i] = try marshal.toWasm(a, vt, loc);

    const out = try rt.gpa.alloc(engine.Value, sig.results.len);
    defer rt.gpa.free(out);

    loaded.invoke(name, in, out) catch
        return error_catalog.raiseInternal(loc, "wasm/call: the wasm call trapped or failed");

    if (out.len == 0) return Value.nil_val;
    if (out.len == 1) return marshal.fromWasm(out[0], loc);

    const items = try rt.gpa.alloc(Value, out.len);
    defer rt.gpa.free(items);
    for (out, 0..) |r, i| items[i] = try marshal.fromWasm(r, loc);
    return vector_mod.fromSlice(rt, items);
}

/// Create the `wasm` host namespace. Called by
/// `runtime/cljw/_host_api.zig::installAll` under `build_options.wasm`.
pub fn register(env: *Env) !void {
    const ns = try env.findOrCreateNs("wasm");
    _ = try env.intern(ns, "load", Value.initBuiltinFn(&wasmLoadFn), null);
    _ = try env.intern(ns, "call", Value.initBuiltinFn(&wasmCallFn), null);
}
