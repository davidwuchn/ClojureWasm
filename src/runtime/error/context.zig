// SPDX-License-Identifier: EPL-2.0
//! `cljw.error/*error-context*` — cw v1's first dynamic var + the
//! raise-time context-snapshot provider (ADR-0055 D2/D3).
//!
//! `register` interns the var (dynamic, root `{}`) and installs
//! `current` into `info.zig` so `setErrorFmt` snapshots the live
//! `*error-context*` value while the `binding` frame is still pushed —
//! the frame is popped during unwind, before the renderer runs, so a
//! render-time deref would always miss it.
//!
//! The Var pointer is a process-global slot: correct for the single-Env
//! CLI EDN-error path (the only path that renders structured error
//! events; nREPL returns errors to the client). D-142 tracks the latent
//! multi-Env race. `register` runs in `bootstrap.setupCore`, which
//! `src/app/builder.zig`'s test blocks also exercise — so a test Env
//! that registered would, on teardown, leave this slot pointing at a
//! freed Var and the next `setErrorFmt` would UAF. `register` therefore
//! arms `Env.on_deinit_hook = clear`: every `Env.deinit` drops the slot
//! before freeing its Vars. Production runs one Env for the process
//! lifetime, so the hook fires only at exit.

const Value = @import("../value/value.zig").Value;
const env_mod = @import("../env.zig");
const Env = env_mod.Env;
const Var = env_mod.Var;
const map = @import("../collection/map.zig");
const info = @import("info.zig");

/// The interned `cljw.error/*error-context*` Var (ADR-0055 D3 / D-142).
var error_context_var: ?*const Var = null;

/// Provider for `info.setContextProvider`: deref the dynamic var, which
/// consults the live threadlocal binding frame. null when unregistered.
fn current() ?Value {
    const v = error_context_var orelse return null;
    return v.deref();
}

/// Clear the cached Var slot. Wired into `Env.on_deinit_hook` by
/// `register` so the slot is dropped before the owning Env frees its
/// Vars — otherwise a later `setErrorFmt` would deref a freed Var
/// (UAF across `setupCore`-using tests; harmless single-Env production).
fn clear() void {
    error_context_var = null;
}

/// Register `cljw.error/*error-context*` (dynamic, root `{}`), wire the
/// raise-time snapshot provider, and arm the Env-teardown clear hook.
/// Idempotent — `env.intern` updates in place; the provider + hook fns
/// are identical across calls.
pub fn register(env: *Env) !void {
    const ns = try env.findOrCreateNs("cljw.error");
    const v = try env.intern(ns, "*error-context*", map.empty(), null);
    v.flags.dynamic = true;
    error_context_var = v;
    info.setContextProvider(current);
    env_mod.on_deinit_hook = clear;
}
