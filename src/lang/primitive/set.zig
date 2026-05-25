// SPDX-License-Identifier: EPL-2.0
//! `clojure.set/` namespace surface — Phase 6.10 cycle 1.
//!
//! Per the survey at `private/notes/phase6-6.10-survey.md`:
//! cw v1 adopts the cw v0 pattern (DIVERGENCE D1) where each
//! `clojure.set` var lives in this Zig file and calls directly
//! into `runtime/collection/{set,map,list}.zig` ops, instead of
//! the JVM pattern of pure-Clojure composition through `reduce` /
//! `conj` / `disj` (those are not yet user-callable primitives).
//!
//! Cycle 1 ships the supporting `rt/hash-set` constructor +
//! Group A clojure.set vars: `union` / `intersection` /
//! `difference` / `subset?` / `superset?`. Group B (rename-keys /
//! map-invert) lands when map primitives register; Group C
//! (relational ops) waits on set-literal `#{...}` Reader (D-061).

const Value = @import("../../runtime/value/value.zig").Value;
const Runtime = @import("../../runtime/runtime.zig").Runtime;
const env_mod = @import("../../runtime/env.zig");
const Env = env_mod.Env;
const error_mod = @import("../../runtime/error/info.zig");
const SourceLocation = error_mod.SourceLocation;
const error_catalog = @import("../../runtime/error/catalog.zig");
const dispatch = @import("../../runtime/dispatch.zig");
const set_collection = @import("../../runtime/collection/set.zig");
const list_collection = @import("../../runtime/collection/list.zig");
const map_collection = @import("../../runtime/collection/map.zig");

/// `(hash-set & xs)` — construct a set from variadic args. Empty
/// arg list returns the empty-set singleton. Each arg is conj-ed
/// in order (idempotent — duplicates collapse).
pub fn hashSet(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    var s = set_collection.empty();
    for (args) |a| s = try set_collection.conj(rt, s, a);
    return s;
}

/// `(hash-map & kvs)` — construct a map from variadic key/value pairs.
/// Odd argument count raises `map_literal_arity_odd` (matches the
/// JVM `IllegalArgumentException`). Empty arg list returns the
/// empty-map singleton.
pub fn hashMap(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    if (args.len % 2 != 0)
        return error_catalog.raise(.map_literal_arity_odd, loc, .{});
    var m = map_collection.empty();
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        m = try map_collection.assoc(rt, m, args[i], args[i + 1]);
    }
    return m;
}

fn assertSetArg(v: Value, fn_name: []const u8, loc: SourceLocation) !void {
    if (v.tag() != .hash_set)
        return error_catalog.raise(.feature_not_supported, loc, .{ .name = fn_name });
}

/// `(clojure.set/union)` / `(union s)` / `(union s1 s2 ...)`.
/// Variadic; 0-arity returns the empty set (matches JVM).
pub fn unionFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    if (args.len == 0) return set_collection.empty();
    if (args.len == 1) {
        try assertSetArg(args[0], "clojure.set/union (non-set arg)", loc);
        return args[0];
    }
    // Fold from the first set, conj-ing every element of subsequent
    // sets. JVM's bubble-max-key optimisation is deferred per
    // DIVERGENCE D2 — same algorithmic complexity, simpler code.
    var acc = args[0];
    try assertSetArg(acc, "clojure.set/union (non-set arg)", loc);
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        try assertSetArg(args[i], "clojure.set/union (non-set arg)", loc);
        var seq_v = try set_collection.seq(rt, args[i]);
        while (seq_v.tag() == .list and list_collection.countOf(seq_v) > 0) {
            acc = try set_collection.conj(rt, acc, list_collection.first(seq_v));
            seq_v = list_collection.rest(seq_v);
        }
    }
    return acc;
}

/// `(clojure.set/intersection s)` / `(intersection s1 s2 ...)`.
/// Returns a set containing only elements present in EVERY arg
/// (JVM contract). Iterates the first set and `contains?`-checks
/// each candidate against the remaining args.
pub fn intersectionFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArityMin("intersection", args, 1, loc);
    try assertSetArg(args[0], "clojure.set/intersection (non-set arg)", loc);
    if (args.len == 1) return args[0];
    for (args[1..]) |a| try assertSetArg(a, "clojure.set/intersection (non-set arg)", loc);

    var result = set_collection.empty();
    var seq_v = try set_collection.seq(rt, args[0]);
    outer: while (seq_v.tag() == .list and list_collection.countOf(seq_v) > 0) {
        const elt = list_collection.first(seq_v);
        seq_v = list_collection.rest(seq_v);
        for (args[1..]) |other| {
            if (!try set_collection.contains(other, elt)) continue :outer;
        }
        result = try set_collection.conj(rt, result, elt);
    }
    return result;
}

/// `(clojure.set/difference s1)` / `(difference s1 s2 ...)`.
/// Returns `s1` with every element of subsequent sets removed.
pub fn differenceFn(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArityMin("difference", args, 1, loc);
    try assertSetArg(args[0], "clojure.set/difference (non-set arg)", loc);
    if (args.len == 1) return args[0];
    var acc = args[0];
    for (args[1..]) |other| {
        try assertSetArg(other, "clojure.set/difference (non-set arg)", loc);
        var seq_v = try set_collection.seq(rt, other);
        while (seq_v.tag() == .list and list_collection.countOf(seq_v) > 0) {
            acc = try set_collection.disj(rt, acc, list_collection.first(seq_v));
            seq_v = list_collection.rest(seq_v);
        }
    }
    return acc;
}

/// `(clojure.set/subset? a b)` — true iff every element of `a` is
/// also in `b`. JVM short-circuits via `(every? ...)`; we
/// short-circuit via early-return.
pub fn subsetQ(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("subset?", args, 2, loc);
    try assertSetArg(args[0], "clojure.set/subset? (non-set arg)", loc);
    try assertSetArg(args[1], "clojure.set/subset? (non-set arg)", loc);
    if (set_collection.count(args[0]) > set_collection.count(args[1])) return Value.false_val;
    var seq_v = try set_collection.seq(rt, args[0]);
    while (seq_v.tag() == .list and list_collection.countOf(seq_v) > 0) {
        const elt = list_collection.first(seq_v);
        if (!try set_collection.contains(args[1], elt)) return Value.false_val;
        seq_v = list_collection.rest(seq_v);
    }
    return Value.true_val;
}

/// `(clojure.set/superset? a b)` — `(subset? b a)`.
pub fn supersetQ(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    try error_catalog.checkArity("superset?", args, 2, loc);
    try assertSetArg(args[0], "clojure.set/superset? (non-set arg)", loc);
    try assertSetArg(args[1], "clojure.set/superset? (non-set arg)", loc);
    return subsetQ(rt, env, &[_]Value{ args[1], args[0] }, loc);
}

fn assertMapArg(v: Value, fn_name: []const u8, loc: SourceLocation) !void {
    if (v.tag() != .array_map and v.tag() != .hash_map)
        return error_catalog.raise(.feature_not_supported, loc, .{ .name = fn_name });
    if (v.tag() == .hash_map)
        // PersistentHashMap iteration is gated on D-045; until promotion
        // lands, maps stay ArrayMap-backed at every accessible scope.
        return error_catalog.raise(.feature_not_supported, loc, .{ .name = fn_name });
}

/// `(clojure.set/rename-keys m kmap)` — return `m` with every key
/// present in `kmap` renamed to its corresponding value. Keys in
/// `kmap` that are absent from `m` are skipped (matches JVM
/// behaviour); when the rename target already exists in `m`, the
/// source's value overwrites it.
pub fn renameKeys(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("rename-keys", args, 2, loc);
    try assertMapArg(args[0], "clojure.set/rename-keys (non-map arg)", loc);
    try assertMapArg(args[1], "clojure.set/rename-keys (non-map kmap)", loc);

    var result = args[0];
    const kmap = args[1].decodePtr(*const map_collection.ArrayMap);
    var i: u32 = 0;
    while (i < kmap.count) : (i += 1) {
        const old_k = kmap.entries[2 * i];
        const new_k = kmap.entries[2 * i + 1];
        if (try map_collection.contains(result, old_k)) {
            const v = try map_collection.get(result, old_k);
            result = try map_collection.dissoc(rt, result, old_k);
            result = try map_collection.assoc(rt, result, new_k, v);
        }
    }
    return result;
}

/// `(clojure.set/map-invert m)` — swap keys and values. When two
/// entries share the same value, one of them wins (JVM does not
/// guarantee which — iteration order determined).
pub fn mapInvert(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    try error_catalog.checkArity("map-invert", args, 1, loc);
    try assertMapArg(args[0], "clojure.set/map-invert (non-map arg)", loc);

    var result = map_collection.empty();
    const am = args[0].decodePtr(*const map_collection.ArrayMap);
    var i: u32 = 0;
    while (i < am.count) : (i += 1) {
        result = try map_collection.assoc(rt, result, am.entries[2 * i + 1], am.entries[2 * i]);
    }
    return result;
}

// --- registration ---

const Entry = struct {
    name: []const u8,
    f: dispatch.BuiltinFn,
};

const RT_ENTRIES = [_]Entry{
    .{ .name = "hash-set", .f = &hashSet },
    .{ .name = "hash-map", .f = &hashMap },
};

const SET_NS_ENTRIES = [_]Entry{
    .{ .name = "union", .f = &unionFn },
    .{ .name = "intersection", .f = &intersectionFn },
    .{ .name = "difference", .f = &differenceFn },
    .{ .name = "subset?", .f = &subsetQ },
    .{ .name = "superset?", .f = &supersetQ },
    .{ .name = "rename-keys", .f = &renameKeys },
    .{ .name = "map-invert", .f = &mapInvert },
};

/// Register `hash-set` into `rt/` (so it's user-callable unqualified
/// after `(refer 'rt)` into `user/`) and the Group A vars into
/// `clojure.set` namespace.
pub fn register(env: *Env) !void {
    const rt_ns = env.findNs("rt") orelse return error.RtNamespaceMissing;
    for (RT_ENTRIES) |it| {
        _ = try env.intern(rt_ns, it.name, Value.initBuiltinFn(it.f), null);
    }
    const set_ns = try env.findOrCreateNs("clojure.set");
    for (SET_NS_ENTRIES) |it| {
        _ = try env.intern(set_ns, it.name, Value.initBuiltinFn(it.f), null);
    }
}
