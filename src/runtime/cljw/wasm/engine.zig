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

/// Per-axis runtime budget for a loaded module (re-exported from zwasm's
/// `Module.Budget`, ADR-0179). `.unmetered` lifts the cap (trusted modules
/// only); `.{ .limited = n }` caps it. cljw's `load` defaults each axis to
/// zwasm's finite default (fuel 1e9 / 4096 pages = 256 MiB), so an untrusted
/// module is bounded out of the box (SE-1 / ZE-1) — the caller opts INTO a
/// larger budget or `.unmetered`, never the reverse.
pub const Budget = zwasm.Module.Budget;

/// Optional load-time budget overrides; each axis defaults to zwasm's finite
/// default when left null.
pub const LoadOpts = struct {
    fuel: ?Budget = null,
    max_memory_pages: ?Budget = null,
};

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
/// `opts` caps the module's runtime budget; a null axis uses zwasm's finite
/// default (so an untrusted module is bounded by default — SE-1 / ZE-1). Caller
/// owns the returned box.
pub fn load(alloc: std.mem.Allocator, bytes: []const u8, opts: LoadOpts) !*Loaded {
    const self = try alloc.create(Loaded);
    errdefer alloc.destroy(self);

    self.engine = try zwasm.Engine.init(alloc, .{});
    errdefer self.engine.deinit();
    self.module = try self.engine.compile(bytes);
    errdefer self.module.deinit();
    // Build zwasm InstantiateOpts: a null cljw axis leaves zwasm's struct default
    // (finite) in place; a provided axis overrides it.
    var inst_opts: zwasm.Module.InstantiateOpts = .{};
    if (opts.fuel) |b| inst_opts.fuel = b;
    if (opts.max_memory_pages) |b| inst_opts.max_memory_pages = b;
    self.instance = try self.module.instantiate(inst_opts);
    return self;
}
