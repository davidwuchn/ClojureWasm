// SPDX-License-Identifier: EPL-2.0
//! Host-interop instance methods on the Namespace `.ns` value (D-232).
//! clj's `clojure.lang.Namespace` exposes `.name`
//! (→ Symbol) / `.getName` (→ Symbol) / `.toString` (→ the name string); real
//! code (e.g. the upstream `clojure.test-clojure.keywords` suite, line 12:
//! `(str (.name *ns*))`) calls them. Installs them on the per-Runtime `.ns`
//! native descriptor, the same `receiverDescriptor` → `method_table` path that
//! `String` / `Throwable` interop uses — so BOTH backends resolve them.
//!
//! Backend: impl-only (reads the Env Namespace off a `.ns` Value)
//! Impl deps: none
//! Clojure peer: clojure.core/ns-name (the var form; this is the `.`-interop form)

const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const env_mod = @import("env.zig");
const Env = env_mod.Env;
const Namespace = env_mod.Namespace;
const symbol_mod = @import("symbol.zig");
const string_collection = @import("collection/string.zig");
const type_descriptor = @import("type_descriptor.zig");
const error_mod = @import("error/info.zig");
const SourceLocation = error_mod.SourceLocation;

/// `(.name ns)` / `(.getName ns)` — the namespace's name as a Symbol.
fn nsNameSym(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    const ns = args[0].decodePtr(*const Namespace);
    return symbol_mod.intern(rt, null, ns.name);
}

/// `(.toString ns)` — the bare name string (clj `Namespace.toString`).
fn nsToString(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    const ns = args[0].decodePtr(*const Namespace);
    return string_collection.alloc(rt, ns.name);
}

/// Populate the per-Runtime `.ns` native descriptor's method table. Idempotent.
/// Called at runtime init alongside `String`/`Throwable.installNativeMethods`.
pub fn installNativeMethods(rt: *Runtime) !void {
    const td = try rt.nativeDescriptor(.ns);
    if (td.method_table.len != 0) return; // idempotent re-run
    const gpa = rt.gc.infra;
    const specs = .{
        .{ "name", &nsNameSym },
        .{ "getName", &nsNameSym },
        .{ "toString", &nsToString },
    };
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
}
