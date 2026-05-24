//! UUID primitives for the `rt/` namespace — Clojure-ns surface.
//!
//! `random-uuid` and `parse-uuid` from clojure.core. Both wrap
//! `runtime/uuid.zig` per F-009 (the same impl is shared with the
//! Java surface in `runtime/java/util/UUID.zig`).

const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const error_mod = @import("../../runtime/error/info.zig");
const error_catalog = @import("../../runtime/error/catalog.zig");
const SourceLocation = error_mod.SourceLocation;
const dispatch = @import("../../runtime/dispatch.zig");
const uuid = @import("../../runtime/uuid.zig");
const string_collection = @import("../../runtime/collection/string.zig");

/// `(random-uuid)` — generate a UUID v4 and return it as a 36-char
/// canonical string. Phase 6 returns a String (Clojure.core's
/// `random-uuid` returns a `java.util.UUID` instance on the JVM —
/// cw v1 returns the canonical String until Phase 7 wires
/// `host_instance` values through the Clojure surface).
pub fn randomUuid(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("random-uuid", args, 0, loc);
    const bytes = uuid.generateV4(rt.io);
    const canonical = uuid.format(bytes);
    return try string_collection.alloc(rt, &canonical);
}

/// `(parse-uuid s)` — parse a canonical UUID string; returns the
/// canonical-form String on success, `nil` on parse failure
/// (matches clojure.core/parse-uuid: returns nil for invalid
/// input, never throws).
pub fn parseUuid(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("parse-uuid", args, 1, loc);
    if (args[0].tag() != .string) {
        return error_catalog.raise(.type_arg_not_string, loc, .{ .fn_name = "parse-uuid", .actual = @tagName(args[0].tag()) });
    }
    const s = string_collection.asString(args[0]);
    const bytes = uuid.parse(s) catch return .nil_val;
    const canonical = uuid.format(bytes);
    return try string_collection.alloc(rt, &canonical);
}

// --- registration ---

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const ENTRIES = [_]Entry{
    .{ .name = "random-uuid", .f = &randomUuid },
    .{ .name = "parse-uuid", .f = &parseUuid },
};

pub fn register(env: *Env, rt_ns: *env_mod.Namespace) !void {
    for (ENTRIES) |it| {
        _ = try env.intern(rt_ns, it.name, Value.initBuiltinFn(it.f));
    }
}
