// SPDX-License-Identifier: EPL-2.0
//! Collection content hash / equality over a SEQ'd map-like or set-like value
//! (D-375 / ADR-0108 am1). The neutral impl behind the `clojure.lang.*`
//! abstract-collection static surfaces (APersistentMap / APersistentSet) that
//! custom-collection libraries call from their deftype hashCode/hasheq/equals
//! bodies — `(APersistentMap/mapHash this)` etc., where `this` is a deftype
//! INSTANCE implementing the map interface, not a native map.
//!
//! The crux: a deftype instance is iterated via the protocol-seq vtable callback
//! (`rt.vtable.callFn` → `clojure.core/seq` → the deftype's own `-seq` impl), the
//! confirmed `java/util/Iterator.zig` pattern. After the initial `(seq inst)` the
//! result is a native seq, walked with the Layer-0 `lazy_seq` first/rest/seq.
//!
//! `mapHash`/`mapHasheq` return cljw's SINGLE content hash (ADR-0108 am1 DA-fork
//! Alt 2): the same `entryHash` + order-independent `+%` + single `mixCollHash`
//! fold `map.contentHash` uses, so a custom map and an `=`-equal native map share
//! one hash. Native maps fast-path straight to `map.contentHash`.

const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const Env = @import("env.zig").Env;
const SourceLocation = @import("error/info.zig").SourceLocation;
const hash = @import("hash.zig");
const map = @import("collection/map.zig");
const set = @import("collection/set.zig");
const equal = @import("equal.zig");

/// Resolve `clojure.core/<name>` and call it through the backend vtable. The
/// Layer-0 → Layer-2 callback every `clojure.lang.*` collection static rides
/// (mirrors `java/util/Iterator.zig`).
fn callCore(rt: *Runtime, env: *Env, name: []const u8, args: []const Value, loc: SourceLocation) !Value {
    const core = env.findNs("clojure.core") orelse return error.NoVTable;
    const v = core.resolve(name) orelse return error.NoVTable;
    const vt = rt.vtable orelse return error.NoVTable;
    return vt.callFn(rt, env, v.deref(), args, loc);
}

/// `(seq coll)` through the vtable — reaches a deftype's own `-seq` impl.
fn seqVia(rt: *Runtime, env: *Env, coll: Value, loc: SourceLocation) !Value {
    return callCore(rt, env, "seq", &.{coll}, loc);
}

/// Seq walk via the vtable (`first`/`next`) — handles every seq + entry type the
/// deftype's protocol-seq yields (a Layer-0 `lazy_seq.first` does not cover
/// map_entry / vector heads). The whole walk is the deftype-instance path; native
/// colls fast-path past it, so the per-step vtable cost is acceptable (optimization
/// deferred — `optimization_deferred_until_15_libs`).
fn firstVia(rt: *Runtime, env: *Env, s: Value, loc: SourceLocation) !Value {
    return callCore(rt, env, "first", &.{s}, loc);
}
fn nextVia(rt: *Runtime, env: *Env, s: Value, loc: SourceLocation) !Value {
    return callCore(rt, env, "next", &.{s}, loc);
}
/// `(nth indexed i)` — extracts k (i=0) / v (i=1) from a `[k v]` entry, whether a
/// MapEntry or a 2-vector (both Indexed).
fn nthVia(rt: *Runtime, env: *Env, coll: Value, i: i64, loc: SourceLocation) !Value {
    return callCore(rt, env, "nth", &.{ coll, Value.initInteger(i) }, loc);
}

/// cljw content hash of a map-like value (ADR-0108 am1). Native maps fast-path to
/// `map.contentHash`; any other map-like (a deftype instance) is seq'd and folded
/// through the identical `entryHash`/`mixCollHash` path, so the two agree.
pub fn mapContentHash(rt: *Runtime, env: *Env, coll: Value, loc: SourceLocation) !u32 {
    switch (coll.tag()) {
        // PERF: native maps fold rt-free without the seq/vtable round-trip [refs: O-NONE]
        .array_map, .hash_map => return map.contentHash(coll),
        else => {},
    }
    var acc: u32 = 0;
    var n: u32 = 0;
    var cursor = try seqVia(rt, env, coll, loc);
    while (cursor.tag() != .nil) {
        const entry = try firstVia(rt, env, cursor, loc);
        const k = try nthVia(rt, env, entry, 0, loc);
        const v = try nthVia(rt, env, entry, 1, loc);
        acc +%= map.entryHash(k, v);
        n += 1;
        cursor = try nextVia(rt, env, cursor, loc);
    }
    return hash.mixCollHash(acc, n);
}

/// cljw content hash of a set-like value (set hashCode partner; folds element
/// hashes order-independently, then `mixCollHash`). Native sets fast-path.
pub fn setContentHash(rt: *Runtime, env: *Env, coll: Value, loc: SourceLocation) !u32 {
    switch (coll.tag()) {
        .hash_set, .sorted_set => return set.contentHash(coll),
        else => {},
    }
    var acc: u32 = 0;
    var n: u32 = 0;
    var cursor = try seqVia(rt, env, coll, loc);
    while (cursor.tag() != .nil) {
        acc +%= equal.valueHash(try firstVia(rt, env, cursor, loc));
        n += 1;
        cursor = try nextVia(rt, env, cursor, loc);
    }
    return hash.mixCollHash(acc, n);
}

/// `(APersistentMap/mapEquals m1 other)` — entry-wise equality (clj's `.equals`
/// flavour): `other` is a map of the same count where every `m1` entry's value
/// `=` `(get other k)`. Works on a deftype `m1` (seq'd) against any map `other`
/// (vtable get/count). Non-map `other` → false.
pub fn mapEquals(rt: *Runtime, env: *Env, m1: Value, other: Value, loc: SourceLocation) !bool {
    if (m1 == other) return true;
    if (!try isCountedMapLike(rt, env, other, loc)) return false;
    var n1: i64 = 0;
    var cursor = try seqVia(rt, env, m1, loc);
    while (cursor.tag() != .nil) {
        const entry = try firstVia(rt, env, cursor, loc);
        const k = try nthVia(rt, env, entry, 0, loc);
        const v = try nthVia(rt, env, entry, 1, loc);
        // (contains? other k) AND (= v (get other k)) — a missing key fails contains?.
        if (!toBool(try callCore(rt, env, "contains?", &.{ other, k }, loc))) return false;
        const ov = try callCore(rt, env, "get", &.{ other, k }, loc);
        if (!try equal.valueEqual(rt, env, v, ov)) return false;
        n1 += 1;
        cursor = try nextVia(rt, env, cursor, loc);
    }
    // Same count both ways: m1 ⊆ other (above) + |m1| == |other| ⇒ equal.
    return n1 == try countVia(rt, env, other, loc);
}

/// `(APersistentSet/setEquals s1 other)` — membership-wise equality: `other` is a
/// set of the same count containing every `s1` element. Non-set `other` → false.
pub fn setEquals(rt: *Runtime, env: *Env, s1: Value, other: Value, loc: SourceLocation) !bool {
    if (s1 == other) return true;
    if (!try isCountedSetLike(rt, env, other, loc)) return false;
    var n1: i64 = 0;
    var cursor = try seqVia(rt, env, s1, loc);
    while (cursor.tag() != .nil) {
        const e = try firstVia(rt, env, cursor, loc);
        if (!toBool(try callCore(rt, env, "contains?", &.{ other, e }, loc))) return false;
        n1 += 1;
        cursor = try nextVia(rt, env, cursor, loc);
    }
    return n1 == try countVia(rt, env, other, loc);
}

fn toBool(v: Value) bool {
    return switch (v.tag()) {
        .nil => false,
        .boolean => v == Value.true_val,
        else => true,
    };
}

fn countVia(rt: *Runtime, env: *Env, coll: Value, loc: SourceLocation) !i64 {
    const c = try callCore(rt, env, "count", &.{coll}, loc);
    return if (c.tag() == .integer) c.asInteger() else 0;
}

fn isCountedMapLike(rt: *Runtime, env: *Env, v: Value, loc: SourceLocation) !bool {
    return switch (v.tag()) {
        .array_map, .hash_map, .sorted_map => true,
        .typed_instance, .reified_instance => toBool(try callCore(rt, env, "map?", &.{v}, loc)),
        else => false,
    };
}

fn isCountedSetLike(rt: *Runtime, env: *Env, v: Value, loc: SourceLocation) !bool {
    return switch (v.tag()) {
        .hash_set, .sorted_set => true,
        .typed_instance, .reified_instance => toBool(try callCore(rt, env, "set?", &.{v}, loc)),
        else => false,
    };
}
