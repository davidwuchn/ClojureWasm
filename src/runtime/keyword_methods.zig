// SPDX-License-Identifier: EPL-2.0
//! Host-interop instance methods on the `.keyword` value (clojure.lang.Keyword).
//! clj's Keyword exposes `.sym` (→ the underlying Symbol). honeysql's `sql-kw`
//! does `(.sym ^clojure.lang.Keyword k)` to get the keyword's ns/name as a
//! symbol. Installs on the per-Runtime `.keyword` native descriptor — the same
//! `receiverDescriptor` → `method_table` path String / Namespace interop uses.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: clojure.core/symbol (the `(symbol kw)` form shares this impl).

const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const Env = @import("env.zig").Env;
const keyword_mod = @import("keyword.zig");
const symbol_mod = @import("symbol.zig");
const type_descriptor = @import("type_descriptor.zig");
const SourceLocation = @import("error/info.zig").SourceLocation;

/// `(.sym k)` — the keyword's underlying Symbol (same ns + name), mirroring
/// `(symbol k)` (core.zig). clj `Keyword.sym`.
fn keywordSym(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    const kw = keyword_mod.asKeyword(args[0]);
    return symbol_mod.intern(rt, kw.ns, kw.name);
}

/// Populate the per-Runtime `.keyword` native descriptor's method table.
/// Idempotent. Called at runtime init alongside the other native installers.
pub fn installNativeMethods(rt: *Runtime) !void {
    const td = try rt.nativeDescriptor(.keyword);
    if (td.method_table.len != 0) return; // idempotent re-run
    const gpa = rt.gc.infra;
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, 1);
    entries[0] = .{ .protocol_name = "", .method_name = try gpa.dupe(u8, "sym"), .method_val = Value.initBuiltinFn(&keywordSym) };
    td.method_table = entries;
}
