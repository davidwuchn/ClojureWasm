// SPDX-License-Identifier: EPL-2.0
//! cljw wasm engine wrapper — embeds zwasm v2 (F-001 / ADR-0099). Holds a
//! loaded module's `Engine` + `Module` + `Instance` triple so a cljw
//! `(wasm/load …)` produces a single live handle. Compiled ONLY under `-Dwasm`.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: wasm/load, wasm/call
//!
//! zwasm ownership (zwasm-from-scratch branch): `Engine` owns the c-api
//! `*Store`; `Module`/`Instance` hold pointer-VALUE copies of `c_store` (not
//! self-referential into each other's storage), so the triple is heap-boxable
//! and movable — only deinit order (instance→module→engine) and "engine
//! outlives instance" matter.
//!
//! Phase-16 split alignment (ADR-0099, Alt-2): the public fn shapes
//! (`load`/`invoke`/`exportSig`) match the structure_plan module/instance
//! split, so Phase-16 separating module.zig/instance.zig out is *addition, not
//! extraction*. F-006 seam: `load` takes the allocator as a NAMED parameter
//! (the cw-GC-allocator inject point), never an inline global grab.
const std = @import("std");
const zwasm = @import("zwasm");

pub const Value = zwasm.Value;
pub const FuncType = zwasm.ir.zir.FuncType;
pub const ValType = zwasm.ir.zir.ValType;

/// A loaded wasm module instance + its owning engine/module, boxed together so
/// the cross-pointers (Module/Instance borrow Engine's `*Store`) stay valid.
pub const Loaded = struct {
    engine: zwasm.Engine,
    module: zwasm.Module,
    instance: zwasm.Instance,

    /// Runtime signature of an exported function (`null` if absent / not a
    /// func). Drives the marshal: caller sizes its `[]Value` buffers from
    /// `sig.params` / `sig.results`.
    pub fn exportSig(self: *Loaded, name: []const u8) ?FuncType {
        return self.instance.exportFuncSig(name);
    }

    /// Invoke an export by name on caller-allocated arg/result slices.
    pub fn invoke(self: *Loaded, name: []const u8, args: []const Value, results: []Value) !void {
        return self.instance.invoke(name, args, results);
    }

    /// Free the zwasm triple (instance→module→engine). Does NOT free the box
    /// itself — the caller frees the `*Loaded` box. Called by the `.wasm_module`
    /// GC finaliser (`wasm_handle.finaliseGc`), which then frees the box back to
    /// `gc.infra`; so a swept `(wasm/load …)` handle no longer leaks (D-259 (b)).
    pub fn deinit(self: *Loaded) void {
        self.instance.deinit();
        self.module.deinit();
        self.engine.deinit();
    }
};

/// Compile + instantiate `bytes` into a fresh `*Loaded`, boxed on `alloc`
/// (the F-006 seam — pass cljw's layer-1 backing allocator, NOT the moving GC
/// heap; zwasm keeps its linear memory + bookkeeping in this separate space).
/// Caller owns the returned box.
pub fn load(alloc: std.mem.Allocator, bytes: []const u8) !*Loaded {
    const self = try alloc.create(Loaded);
    errdefer alloc.destroy(self);

    self.engine = try zwasm.Engine.init(alloc, .{});
    errdefer self.engine.deinit();
    self.module = try self.engine.compile(bytes);
    errdefer self.module.deinit();
    self.instance = try self.module.instantiate(.{});
    return self;
}
