// SPDX-License-Identifier: EPL-2.0
//! cljw-original surface aggregator (ADR-0098), the sibling of
//! `runtime/java/_host_api.zig`. `installAll` registers every `cljw.*` host
//! namespace; it is imported by `src/lang/primitive.zig` — the only lang
//! aggregator permitted to reach a surface tree under the ADR-0029 D2 / F-009
//! zone rule (files *under* `lang/primitive/` must not import a surface).
//!
//! As more cljw-original surfaces land (cljw.build / cljw.wasm / cljw.edge /
//! cljw.repl per structure_plan.md), add their `register(env)` here.
const Env = @import("../env.zig").Env;
const http_server = @import("http/server.zig");

pub fn installAll(env: *Env) !void {
    try http_server.register(env);
}
