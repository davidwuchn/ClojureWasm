// SPDX-License-Identifier: EPL-2.0
//! The single wrap/unwrap site for a loaded-wasm instance handle (ADR-0099 §4 /
//! D-259). A `(wasm/load …)` result is a GC-allocated `WasmHandle` tagged with
//! the already-reserved `HeapTag.wasm_module` (F-004 slot D4), carrying an
//! external `*engine.Loaded` pointer. Isolated here so the Phase-16 swap to the
//! finished-form representation (the module/instance/fn semantic split,
//! funcref/externref first-classing, GC finalisation/rooting of the external
//! pointer) is a one-file change, not a scatter-hunt.
//!
//! GC: the box begins with a `HeapHeader` (so `isGcManaged(.wasm_module)` = true
//! holds and the mark phase can read the header), and `wasm_module` carries
//! `null` tag_ops trace — the correct leaf default, since the `*Loaded` points
//! into zwasm's separate space (F-006) the cljw GC must NOT trace. The external
//! `*Loaded` is intentionally not finalised for P1 (short-lived demo,
//! auto-collect off); D-259 owns finalisation/rooting.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: wasm/load, wasm/call
const std = @import("std");
const engine = @import("engine.zig");
const value_mod = @import("../../value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("../../runtime.zig").Runtime;

/// Heap carrier for a loaded-wasm handle. `header` at offset 0 (gc.alloc
/// invariant); `loaded` is an external pointer the GC does not trace.
// PROVISIONAL: opaque wasm_module handle pending F-004 Group D slot semantics + GC finalisation [refs: D-259, feature_deps.yaml#runtime/cljw/wasm/instance_handle]
pub const WasmHandle = extern struct {
    header: HeapHeader,
    loaded: *engine.Loaded,
    meta: Value = Value.nil_val,

    comptime {
        std.debug.assert(@alignOf(WasmHandle) >= 8);
        std.debug.assert(@offsetOf(WasmHandle, "header") == 0);
    }
};

/// Wrap a `*Loaded` in a fresh `.wasm_module` heap Value.
pub fn wrap(rt: *Runtime, loaded: *engine.Loaded) !Value {
    const h = try rt.gc.alloc(WasmHandle);
    h.* = .{ .header = HeapHeader.init(.wasm_module), .loaded = loaded };
    return Value.encodeHeapPtr(.wasm_module, h);
}

/// Decode a `.wasm_module` Value back to its `*Loaded`. Caller verifies the tag.
pub fn unwrap(v: Value) *engine.Loaded {
    std.debug.assert(v.tag() == .wasm_module);
    return v.decodePtr(*const WasmHandle).loaded;
}

/// True iff `v` is a loaded-wasm handle.
pub fn isHandle(v: Value) bool {
    return v.tag() == .wasm_module;
}
