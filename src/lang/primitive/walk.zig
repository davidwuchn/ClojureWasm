// SPDX-License-Identifier: EPL-2.0
//! `clojure.walk/` namespace surface — Phase 6.11 cycle 1.
//!
//! Per the survey at `private/notes/phase6-6.11-survey.md`,
//! cw v1 adopts DIVERGENCE D1: each var lives in this Zig file
//! and dispatches over `Value.Tag` directly, calling user fns
//! via `rt.vtable.callFn` (the pattern proven in
//! `lang/primitive/string.zig::escape`).
//!
//! Cycle 1 ships the spine: `walk` (one-level rebuild) +
//! `prewalk` + `postwalk` (recursive Zig-direct traversal).
//! `partial` is NOT a registered primitive in cw v1 yet, so
//! the JVM `(walk (partial prewalk f) identity (f form))`
//! pattern is replaced with explicit Zig recursion.
//!
//! Cycle 2 layers `keywordize-keys` / `stringify-keys` /
//! `prewalk-replace` / `postwalk-replace` on top of this spine.

const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const error_mod = @import("../../runtime/error/info.zig");
const SourceLocation = error_mod.SourceLocation;
const error_catalog = @import("../../runtime/error/catalog.zig");
const dispatch = @import("../../runtime/dispatch.zig");

const vector_collection = @import("../../runtime/collection/vector.zig");
const list_collection = @import("../../runtime/collection/list.zig");
const map_collection = @import("../../runtime/collection/map.zig");
const set_collection = @import("../../runtime/collection/set.zig");

fn callOne(rt: *Runtime, env: *Env, fn_val: Value, arg: Value, loc: SourceLocation) anyerror!Value {
    if (fn_val.tag() != .fn_val and fn_val.tag() != .builtin_fn)
        return error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk callback (non-fn)" });
    const vt = rt.vtable orelse return error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk (vtable not installed)" });
    const args = [_]Value{arg};
    return vt.callFn(rt, env, fn_val, &args, loc);
}

/// Rebuild a list with `transform_child` applied to each element.
/// Builds the result tail-first by collecting transformed children
/// into a temporary buffer (so we can `consHeap` in reverse).
fn rebuildList(
    rt: *Runtime,
    env: *Env,
    loc: SourceLocation,
    form: Value,
    /// Generic transformer: returns the transformed child Value.
    /// `ctx` is the caller's threaded state (fn Value + loc).
    comptime transform_child: fn (rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value,
    ctx: anytype,
) anyerror!Value {
    const n = list_collection.countOf(form);
    if (n == 0) return form;
    var buf: std.ArrayList(Value) = .empty;
    defer buf.deinit(rt.gc.infra);
    var cur = form;
    while (cur.tag() == .list and list_collection.countOf(cur) > 0) {
        const child = list_collection.first(cur);
        const t = try transform_child(rt, env, ctx, child, loc);
        try buf.append(rt.gc.infra, t);
        cur = list_collection.rest(cur);
    }
    var result: Value = .nil_val;
    var i: usize = buf.items.len;
    while (i > 0) {
        i -= 1;
        result = try list_collection.consHeap(rt, buf.items[i], result);
    }
    return result;
}

fn rebuildVector(
    rt: *Runtime,
    env: *Env,
    loc: SourceLocation,
    form: Value,
    comptime transform_child: fn (rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value,
    ctx: anytype,
) anyerror!Value {
    const n = vector_collection.count(form);
    var result = vector_collection.empty();
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const child = vector_collection.nth(form, i);
        const t = try transform_child(rt, env, ctx, child, loc);
        result = try vector_collection.conj(rt, result, t);
    }
    return result;
}

fn rebuildSet(
    rt: *Runtime,
    env: *Env,
    loc: SourceLocation,
    form: Value,
    comptime transform_child: fn (rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value,
    ctx: anytype,
) anyerror!Value {
    var result = set_collection.empty();
    var seq_v = try set_collection.seq(rt, form);
    while (seq_v.tag() == .list and list_collection.countOf(seq_v) > 0) {
        const child = list_collection.first(seq_v);
        const t = try transform_child(rt, env, ctx, child, loc);
        result = try set_collection.conj(rt, result, t);
        seq_v = list_collection.rest(seq_v);
    }
    return result;
}

/// Rebuild an array_map by walking each entry as a 2-vector and
/// applying `transform_child` to it. The transformer must return
/// a 2-vector (or 2-element collection); the resulting key/value
/// pair is `assoc`-ed into the rebuilt map. Per DIVERGENCE 1 the
/// inner fn sees `[k v]` not a JVM `MapEntry`.
fn rebuildArrayMap(
    rt: *Runtime,
    env: *Env,
    loc: SourceLocation,
    form: Value,
    comptime transform_child: fn (rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value,
    ctx: anytype,
) anyerror!Value {
    var result = map_collection.empty();
    const am = form.decodePtr(*const map_collection.ArrayMap);
    var i: u32 = 0;
    while (i < am.count) : (i += 1) {
        // Synthesize the [k v] 2-vector.
        var entry = vector_collection.empty();
        entry = try vector_collection.conj(rt, entry, am.entries[2 * i]);
        entry = try vector_collection.conj(rt, entry, am.entries[2 * i + 1]);
        const transformed = try transform_child(rt, env, ctx, entry, loc);
        // Expect transformed back to a 2-vector.
        if (transformed.tag() != .vector or vector_collection.count(transformed) != 2)
            return error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk map child returned non-2-vector" });
        result = try map_collection.assoc(rt, result, vector_collection.nth(transformed, 0), vector_collection.nth(transformed, 1));
    }
    return result;
}

// --- walk (one-level) ---

const WalkCtx = struct { inner: Value };

fn walkInnerCallback(rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value {
    return callOne(rt, env, ctx.inner, child, loc);
}

fn walkRebuild(rt: *Runtime, env: *Env, inner: Value, form: Value, loc: SourceLocation) anyerror!Value {
    const ctx = WalkCtx{ .inner = inner };
    return switch (form.tag()) {
        .list, .cons => rebuildList(rt, env, loc, form, walkInnerCallback, ctx),
        .vector => rebuildVector(rt, env, loc, form, walkInnerCallback, ctx),
        .hash_set => rebuildSet(rt, env, loc, form, walkInnerCallback, ctx),
        .array_map => rebuildArrayMap(rt, env, loc, form, walkInnerCallback, ctx),
        .hash_map => error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk on .hash_map (D-045)" }),
        else => form, // scalar / other Tag — walk leaves it alone
    };
}

/// `(clojure.walk/walk inner outer form)` — one-level: apply
/// `inner` to each immediate child, rebuild the same collection
/// type, then apply `outer` to the result. Scalars receive only
/// `outer`.
pub fn walkFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("walk", args, 3, loc);
    const rebuilt = try walkRebuild(rt, env, args[0], args[2], loc);
    return callOne(rt, env, args[1], rebuilt, loc);
}

// --- prewalk (pre-order: apply f first, then recurse) ---

const PrewalkCtx = struct { f: Value };

fn prewalkChildCallback(rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value {
    return prewalkRec(rt, env, ctx.f, child, loc);
}

fn prewalkRec(rt: *Runtime, env: *Env, f: Value, form: Value, loc: SourceLocation) anyerror!Value {
    const transformed = try callOne(rt, env, f, form, loc);
    const ctx = PrewalkCtx{ .f = f };
    return switch (transformed.tag()) {
        .list, .cons => rebuildList(rt, env, loc, transformed, prewalkChildCallback, ctx),
        .vector => rebuildVector(rt, env, loc, transformed, prewalkChildCallback, ctx),
        .hash_set => rebuildSet(rt, env, loc, transformed, prewalkChildCallback, ctx),
        .array_map => rebuildArrayMap(rt, env, loc, transformed, prewalkChildCallback, ctx),
        .hash_map => error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk/prewalk on .hash_map (D-045)" }),
        else => transformed,
    };
}

pub fn prewalkFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("prewalk", args, 2, loc);
    return prewalkRec(rt, env, args[0], args[1], loc);
}

// --- postwalk (post-order: recurse first, then apply f) ---

const PostwalkCtx = struct { f: Value };

fn postwalkChildCallback(rt: *Runtime, env: *Env, ctx: anytype, child: Value, loc: SourceLocation) anyerror!Value {
    return postwalkRec(rt, env, ctx.f, child, loc);
}

fn postwalkRec(rt: *Runtime, env: *Env, f: Value, form: Value, loc: SourceLocation) anyerror!Value {
    const ctx = PostwalkCtx{ .f = f };
    const rebuilt = switch (form.tag()) {
        .list, .cons => try rebuildList(rt, env, loc, form, postwalkChildCallback, ctx),
        .vector => try rebuildVector(rt, env, loc, form, postwalkChildCallback, ctx),
        .hash_set => try rebuildSet(rt, env, loc, form, postwalkChildCallback, ctx),
        .array_map => try rebuildArrayMap(rt, env, loc, form, postwalkChildCallback, ctx),
        .hash_map => return error_catalog.raise(.feature_not_supported, loc, .{ .name = "clojure.walk/postwalk on .hash_map (D-045)" }),
        else => form,
    };
    return callOne(rt, env, f, rebuilt, loc);
}

pub fn postwalkFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("postwalk", args, 2, loc);
    return postwalkRec(rt, env, args[0], args[1], loc);
}

// --- registration ---

const std = @import("std");

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const ENTRIES = [_]Entry{
    .{ .name = "walk", .f = &walkFn },
    .{ .name = "prewalk", .f = &prewalkFn },
    .{ .name = "postwalk", .f = &postwalkFn },
};

pub fn register(env: *Env) !void {
    const ns = try env.findOrCreateNs("clojure.walk");
    for (ENTRIES) |it| {
        _ = try env.intern(ns, it.name, Value.initBuiltinFn(it.f), null);
    }
}
