// SPDX-License-Identifier: EPL-2.0
//! cljw.http.server — cljw's own HTTP server (ADR-0098), on Zig 0.16
//! `std.Io.net` + `std.http.Server`. Layer 0 (the cljw-original surface tree).
//!
//! Ring-style: `run-server` serves a blocking serial accept loop; each request
//! becomes a Ring request map `{:request-method :get :uri "/path"}` passed to the
//! handler (invoked via `rt.vtable.callFn`), whose response map
//! `{:status N :body "…"}` (or a bare string body) is written back.
//!
//! Follow-ons (D-257): request :headers/:body, per-connection threading + a
//! non-blocking stop handle, and per-request GC rooting of the freshly-built
//! request map under auto-collect (today auto-collect is off, so the
//! build-then-immediately-call path is safe).
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: cljw.http.server/run-server
const std = @import("std");
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const Value = @import("../../value/value.zig").Value;
const error_mod = @import("../../error/info.zig");
const SourceLocation = error_mod.SourceLocation;
const error_catalog = @import("../../error/catalog.zig");
const keyword_mod = @import("../../keyword.zig");
const string_mod = @import("../../collection/string.zig");
const map_mod = @import("../../collection/map.zig");

/// `:request-method` keyword for an HTTP method (lowercase, Ring convention).
fn methodKeyword(rt: *Runtime, m: std.http.Method) !Value {
    const name = switch (m) {
        .GET => "get",
        .HEAD => "head",
        .POST => "post",
        .PUT => "put",
        .DELETE => "delete",
        .OPTIONS => "options",
        .PATCH => "patch",
        .TRACE => "trace",
        .CONNECT => "connect",
    };
    return keyword_mod.intern(rt, null, name);
}

/// Bind `0.0.0.0:port` and serve forever (blocking, serial), dispatching each
/// request through `handler` (a Ring `(fn [req] resp)`).
pub fn runServer(rt: *Runtime, env: *Env, handler: Value, port: u16, loc: SourceLocation) anyerror!Value {
    const io = rt.io;
    const kw_method = try keyword_mod.intern(rt, null, "request-method");
    const kw_uri = try keyword_mod.intern(rt, null, "uri");
    const kw_status = try keyword_mod.intern(rt, null, "status");
    const kw_body = try keyword_mod.intern(rt, null, "body");

    var addr = std.Io.net.IpAddress.parse("0.0.0.0", port) catch
        return error_catalog.raiseInternal(loc, "cljw.http.server: invalid bind address");
    var server = addr.listen(io, .{}) catch
        return error_catalog.raiseInternal(loc, "cljw.http.server: listen/bind failed (port in use?)");

    while (true) {
        var stream = server.accept(io) catch continue;
        defer stream.close(io);
        var rbuf: [16384]u8 = undefined;
        var wbuf: [16384]u8 = undefined;
        var sr = stream.reader(io, &rbuf);
        var sw = stream.writer(io, &wbuf);
        var hs = std.http.Server.init(&sr.interface, &sw.interface);
        var req = hs.receiveHead() catch continue;

        // Build the Ring request map (cycle: method + uri; headers/body = D-257).
        const req_map = buildRequest(rt, &req, kw_method, kw_uri) catch {
            req.respond("Internal Server Error\n", .{ .status = .internal_server_error, .keep_alive = false }) catch {};
            continue;
        };

        // Dispatch to the handler. A throwing handler → 500 (server stays up).
        const vtable = rt.vtable orelse
            return error_catalog.raiseInternal(loc, "cljw.http.server: runtime vtable not installed");
        const resp = vtable.callFn(rt, env, handler, &.{req_map}, loc) catch {
            req.respond("Internal Server Error\n", .{ .status = .internal_server_error, .keep_alive = false }) catch {};
            continue;
        };

        // Render the response: a bare string is a 200 body; a map yields
        // {:status :body}.
        var status: std.http.Status = .ok;
        var body: []const u8 = "";
        if (resp.tag() == .string) {
            body = string_mod.asString(resp);
        } else {
            const s = map_mod.get(resp, kw_status) catch Value.nil_val;
            if (s.isInt()) status = @enumFromInt(@as(u10, @intCast(s.asInteger())));
            const b = map_mod.get(resp, kw_body) catch Value.nil_val;
            if (b.tag() == .string) body = string_mod.asString(b);
        }
        req.respond(body, .{ .status = status, .keep_alive = false }) catch {};
    }
}

fn buildRequest(rt: *Runtime, req: *std.http.Server.Request, kw_method: Value, kw_uri: Value) !Value {
    const method_kw = try methodKeyword(rt, req.head.method);
    const uri_str = try string_mod.alloc(rt, req.head.target);
    var m = map_mod.empty();
    m = try map_mod.assoc(rt, m, kw_method, method_kw);
    m = try map_mod.assoc(rt, m, kw_uri, uri_str);
    return m;
}

// --- Clojure surface (cljw.http.server / cljw.http.client) ---
// These builtin fns live in the surface tree (runtime/cljw/**) per the ADR-0029
// D2 zone rule: lang/primitive/ may not import a surface, so the host fns + their
// ns registration live here and are wired via runtime/cljw/_host_api.zig.

/// `(run-server handler {:port N})` — Ring-style. `handler` is `(fn [req] resp)`;
/// `opts` carries `:port` (a bare integer port is also accepted). Blocking.
pub fn runServerFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("run-server", args, 2, loc);
    const handler = args[0];
    const opts = args[1];
    const port: i64 = blk: {
        if (opts.isInt()) break :blk opts.asInteger();
        const kw_port = try keyword_mod.intern(rt, null, "port");
        const p = map_mod.get(opts, kw_port) catch Value.nil_val;
        if (!p.isInt())
            return error_catalog.raiseInternal(loc, "run-server: opts map needs an integer :port");
        break :blk p.asInteger();
    };
    if (port < 1 or port > 65535)
        return error_catalog.raiseInternal(loc, "run-server: port out of range (1..65535)");
    return runServer(rt, env, handler, @intCast(port), loc);
}

/// Placeholder for every `cljw.http.client` fn until the client lands (D-257).
pub fn clientStubFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = rt;
    _ = env;
    _ = args;
    return error_catalog.raise(.feature_not_supported, loc, .{ .name = "cljw.http.client (HTTP client not yet implemented)" });
}

/// Create the `cljw.http.server` / `cljw.http.client` host namespaces. Called by
/// `runtime/cljw/_host_api.zig::installAll`.
pub fn register(env: *Env) !void {
    const srv = try env.findOrCreateNs("cljw.http.server");
    _ = try env.intern(srv, "run-server", Value.initBuiltinFn(&runServerFn), null);

    const cli = try env.findOrCreateNs("cljw.http.client");
    inline for (.{ "get", "post", "put", "delete" }) |name| {
        _ = try env.intern(cli, name, Value.initBuiltinFn(&clientStubFn), null);
    }
}
