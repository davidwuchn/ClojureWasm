// SPDX-License-Identifier: EPL-2.0
//! NaN-boxed Value type for ClojureWasm runtime — module root.
//!
//! This file is the public face of the `runtime/value/` subdirectory.
//! It exports the `Value` enum + its `Tag` classifier + every helper
//! callers used to import from the old single-file `runtime/value.zig`.
//! Internal types (`HeapTag`, `HeapHeader`, NaN-box constants) are
//! re-exported here so existing call sites only need to add the `/value`
//! segment to their `@import` path.
//!
//! Phase 5 row 5.2 split lands this module decomposition per
//! `.dev/structure_plan.md` (F-004 + D-029 decree) + ADR-0027 §5.
//! The 32 → 64 HeapTag widening + `heapTagToTag` collapse +
//! `big_int` slot rotation + `tag_ops.zig` skeleton land in the
//! follow-up 5.2.b commit.

const std = @import("std");
const testing = std.testing;

const heap_tag_mod = @import("heap_tag.zig");
const heap_header_mod = @import("heap_header.zig");
const nb = @import("nan_box.zig");

// Re-exports — callers used to reach these through `runtime/value.zig`.
pub const HeapTag = heap_tag_mod.HeapTag;
pub const HeapHeader = heap_header_mod.HeapHeader;

/// NaN-boxed runtime value. Every Clojure value fits in 8 bytes.
///
/// Use `tag()` to classify, constructors (`initInteger`, `initFloat`, …)
/// to build, and accessors (`asInteger`, `asFloat`, …) to extract.
pub const Value = enum(u64) {
    nil_val = nb.NB_CONST_TAG | 0,
    true_val = nb.NB_CONST_TAG | 1,
    false_val = nb.NB_CONST_TAG | 2,
    _,

    /// High-level type tag returned by `tag()`. One slot per kind.
    pub const Tag = enum {
        // Immediates
        nil,
        boolean,
        integer,
        float,
        char,
        builtin_fn,
        // Group A: Core Data
        string,
        symbol,
        keyword,
        list,
        vector,
        array_map,
        hash_map,
        hash_set,
        // Group B: Callable & Binding
        fn_val,
        multi_fn,
        protocol,
        protocol_fn,
        var_ref,
        ns,
        delay,
        regex,
        // Group C: Sequence & State
        lazy_seq,
        cons,
        chunked_cons,
        chunk_buffer,
        atom,
        agent,
        ref,
        @"volatile",
        // Group D: Transient & Extension
        transient_vector,
        transient_map,
        transient_set,
        reduced,
        ex_info,
        big_int,
        ratio,
        class,
    };

    /// Pack a heap pointer + HeapTag into a Value. The pointer must be
    /// 8-byte aligned so the low 3 bits are zero.
    pub fn encodeHeapPtr(ht: HeapTag, ptr: anytype) Value {
        const addr: u64 = @intFromPtr(ptr);
        std.debug.assert(addr & nb.NB_ADDR_ALIGN_MASK == 0);
        const shifted = addr >> nb.NB_ADDR_ALIGN_SHIFT;
        std.debug.assert(shifted <= nb.NB_ADDR_SHIFTED_MASK);
        const type_val = @intFromEnum(ht);
        const group = type_val / nb.NB_HEAP_GROUP_SIZE;
        const tag_base: u64 = switch (group) {
            0 => nb.NB_HEAP_TAG_A,
            1 => nb.NB_HEAP_TAG_B,
            2 => nb.NB_HEAP_TAG_C,
            3 => nb.NB_HEAP_TAG_D,
            // @panic: cw runtime invariant — HeapTag is bounded to
            // 4 × NB_HEAP_GROUP_SIZE entries (g1 = 32; g2 = 64 per
            // F-004 NaN-box second generation layout, row 5.2.b).
            // Adding entries past that bound would require a layout
            // extension ADR; this arm guards against silent drift.
            else => unreachable,
        };
        const sub_type: u64 = type_val % nb.NB_HEAP_GROUP_SIZE;
        return @enumFromInt(tag_base | (sub_type << nb.NB_HEAP_SUBTYPE_SHIFT) | shifted);
    }

    /// Extract the heap pointer from a heap-tagged Value.
    pub fn decodePtr(self: Value, comptime T: type) T {
        const shifted = @intFromEnum(self) & nb.NB_ADDR_SHIFTED_MASK;
        return @ptrFromInt(@as(usize, shifted) << nb.NB_ADDR_ALIGN_SHIFT);
    }

    fn heapTagToTag(ht_raw: u8) Tag {
        return switch (@as(HeapTag, @enumFromInt(ht_raw))) {
            .string => .string,
            .symbol => .symbol,
            .keyword => .keyword,
            .list => .list,
            .vector => .vector,
            .array_map => .array_map,
            .hash_map => .hash_map,
            .hash_set => .hash_set,
            .fn_val => .fn_val,
            .multi_fn => .multi_fn,
            .protocol => .protocol,
            .protocol_fn => .protocol_fn,
            .var_ref => .var_ref,
            .ns => .ns,
            .delay => .delay,
            .regex => .regex,
            .lazy_seq => .lazy_seq,
            .cons => .cons,
            .chunked_cons => .chunked_cons,
            .chunk_buffer => .chunk_buffer,
            .atom => .atom,
            .agent => .agent,
            .ref => .ref,
            .@"volatile" => .@"volatile",
            .transient_vector => .transient_vector,
            .transient_map => .transient_map,
            .transient_set => .transient_set,
            .reduced => .reduced,
            .ex_info => .ex_info,
            .big_int => .big_int,
            .ratio => .ratio,
            .class => .class,
        };
    }

    /// Classify this Value into a Tag by inspecting the upper 16 bits.
    pub fn tag(self: Value) Tag {
        const bits = @intFromEnum(self);
        const top16: u16 = @truncate(bits >> nb.NB_TAG_SHIFT);
        if (top16 < nb.NB_FLOAT_TAG_BOUNDARY) return .float;
        const sub: u8 = @truncate((bits >> nb.NB_HEAP_SUBTYPE_SHIFT) & nb.NB_HEAP_SUBTYPE_MASK);
        return switch (top16) {
            nb.NB_TAG_A => heapTagToTag(sub),
            nb.NB_TAG_B => heapTagToTag(sub + nb.NB_HEAP_GROUP_SIZE),
            nb.NB_TAG_C => heapTagToTag(sub + nb.NB_HEAP_GROUP_SIZE * 2),
            nb.NB_TAG_D => heapTagToTag(sub + nb.NB_HEAP_GROUP_SIZE * 3),
            nb.NB_TAG_INT => .integer,
            nb.NB_TAG_CONST => switch (bits & nb.NB_PAYLOAD_MASK) {
                0 => .nil,
                1, 2 => .boolean,
                // @panic: cw runtime invariant — NB_TAG_CONST payload
                // is constructed only as nil_val (0) / true_val (1) /
                // false_val (2). A NB_TAG_CONST Value with any other
                // payload is a corrupt bit pattern.
                else => unreachable,
            },
            nb.NB_TAG_CHAR => .char,
            nb.NB_TAG_BUILTIN => .builtin_fn,
            // @panic: cw runtime invariant — top16 is constructed only
            // as NB_TAG_INT / _A / _B / _C / _D / _CONST / _CHAR /
            // _BUILTIN, or covered by the `< NB_FLOAT_TAG_BOUNDARY`
            // early-return above. Any other top16 is a corrupt bit
            // pattern.
            else => unreachable,
        };
    }

    pub fn initBoolean(b: bool) Value {
        return if (b) Value.true_val else Value.false_val;
    }

    /// Encode an integer. Values outside i48 range are promoted to float
    /// (Clojure-compatible auto-promotion within the i48 window).
    pub fn initInteger(i: i64) Value {
        if (i < nb.NB_I48_MIN or i > nb.NB_I48_MAX) {
            return initFloat(@floatFromInt(i));
        }
        const raw: u48 = @truncate(@as(u64, @bitCast(i)));
        return @enumFromInt(nb.NB_INT_TAG | @as(u64, raw));
    }

    /// Encode a float. NaN bit patterns whose top16 ≥ 0xFFF8 collide
    /// with tagged values; collapse them to canonical positive quiet NaN.
    pub fn initFloat(f: f64) Value {
        const bits: u64 = @bitCast(f);
        if ((bits >> nb.NB_TAG_SHIFT) >= nb.NB_FLOAT_TAG_BOUNDARY) {
            return @enumFromInt(nb.NB_CANONICAL_NAN);
        }
        return @enumFromInt(bits);
    }

    pub fn initChar(c: u21) Value {
        return @enumFromInt(nb.NB_CHAR_TAG | @as(u64, c));
    }

    /// Pack a 48-bit function pointer into a NaN-boxed Value.
    pub fn initBuiltinFn(fn_ptr: anytype) Value {
        const addr: u64 = @intFromPtr(fn_ptr);
        std.debug.assert(addr <= nb.NB_PAYLOAD_MASK);
        return @enumFromInt(nb.NB_BUILTIN_FN_TAG | addr);
    }

    /// Extract the function pointer from a builtin_fn Value. Caller
    /// supplies the concrete pointer type via `FnPtr`.
    pub fn asBuiltinFn(self: Value, comptime FnPtr: type) FnPtr {
        const raw = @intFromEnum(self) & nb.NB_PAYLOAD_MASK;
        return @ptrFromInt(raw);
    }

    pub fn isNil(self: Value) bool {
        return self == Value.nil_val;
    }

    /// Clojure truthiness: everything except `nil` and `false`.
    pub fn isTruthy(self: Value) bool {
        return self != Value.nil_val and self != Value.false_val;
    }

    pub fn asBoolean(self: Value) bool {
        return self == Value.true_val;
    }

    pub fn asInteger(self: Value) i48 {
        const raw: u48 = @truncate(@intFromEnum(self));
        return @bitCast(raw);
    }

    pub fn asFloat(self: Value) f64 {
        return @bitCast(@intFromEnum(self));
    }

    pub fn asChar(self: Value) u21 {
        return @truncate(@intFromEnum(self));
    }

    pub fn isInt(self: Value) bool {
        return self.tag() == .integer;
    }

    pub fn isFloat(self: Value) bool {
        return self.tag() == .float;
    }

    pub fn isNumber(self: Value) bool {
        const t = self.tag();
        return t == .integer or t == .float;
    }

    pub fn isString(self: Value) bool {
        return self.tag() == .string;
    }

    pub fn isSymbol(self: Value) bool {
        return self.tag() == .symbol;
    }

    pub fn isKeyword(self: Value) bool {
        return self.tag() == .keyword;
    }
};

// --- tests ---

test "nil, true, false constants" {
    const nil: Value = .nil_val;
    const t: Value = .true_val;
    const f: Value = .false_val;

    try testing.expect(nil.tag() == .nil);
    try testing.expect(t.tag() == .boolean);
    try testing.expect(f.tag() == .boolean);

    try testing.expect(nil.isNil());
    try testing.expect(!t.isNil());
    try testing.expect(!f.isNil());

    try testing.expect(!nil.isTruthy());
    try testing.expect(t.isTruthy());
    try testing.expect(!f.isTruthy());

    try testing.expect(t.asBoolean());
    try testing.expect(!f.asBoolean());
}

test "integer encoding round-trip" {
    const zero = Value.initInteger(0);
    try testing.expect(zero.tag() == .integer);
    try testing.expectEqual(@as(i48, 0), zero.asInteger());

    const pos = Value.initInteger(42);
    try testing.expect(pos.tag() == .integer);
    try testing.expectEqual(@as(i48, 42), pos.asInteger());

    const neg = Value.initInteger(-1);
    try testing.expectEqual(@as(i48, -1), neg.asInteger());

    // i48 max/min
    const max_i48 = Value.initInteger((1 << 47) - 1);
    try testing.expect(max_i48.tag() == .integer);
    try testing.expectEqual(@as(i48, (1 << 47) - 1), max_i48.asInteger());

    const min_i48 = Value.initInteger(-(1 << 47));
    try testing.expect(min_i48.tag() == .integer);
    try testing.expectEqual(@as(i48, -(1 << 47)), min_i48.asInteger());

    // Out-of-range → float promotion
    const overflow = Value.initInteger((1 << 47));
    try testing.expect(overflow.tag() == .float);
    const underflow = Value.initInteger(-(1 << 47) - 1);
    try testing.expect(underflow.tag() == .float);
}

test "float encoding round-trip" {
    const pi = Value.initFloat(3.14159);
    try testing.expect(pi.tag() == .float);
    try testing.expectApproxEqRel(@as(f64, 3.14159), pi.asFloat(), 1e-10);

    const zero = Value.initFloat(0.0);
    try testing.expect(zero.tag() == .float);
    try testing.expectEqual(@as(f64, 0.0), zero.asFloat());

    const neg = Value.initFloat(-1.5);
    try testing.expectEqual(@as(f64, -1.5), neg.asFloat());

    const inf = Value.initFloat(std.math.inf(f64));
    try testing.expect(std.math.isPositiveInf(inf.asFloat()));

    const neg_inf = Value.initFloat(-std.math.inf(f64));
    try testing.expect(std.math.isNegativeInf(neg_inf.asFloat()));

    const nan = Value.initFloat(std.math.nan(f64));
    try testing.expect(nan.tag() == .float);
    try testing.expect(std.math.isNan(nan.asFloat()));
}

test "NaN canonicalization" {
    // A negative-sign NaN bit pattern (top16 >= 0xFFF8) would collide
    // with tagged Values; initFloat must canonicalise it.
    const canonical: u64 = 0x7FF8_0000_0000_0000;
    const neg_nan: f64 = @bitCast(@as(u64, 0xFFF8_0000_0000_0001));
    const result = Value.initFloat(neg_nan);
    try testing.expect(result.tag() == .float);
    try testing.expectEqual(canonical, @intFromEnum(result));
}

test "char encoding round-trip" {
    const a = Value.initChar('a');
    try testing.expect(a.tag() == .char);
    try testing.expectEqual(@as(u21, 'a'), a.asChar());

    const emoji = Value.initChar(0x1F600);
    try testing.expect(emoji.tag() == .char);
    try testing.expectEqual(@as(u21, 0x1F600), emoji.asChar());
}

test "type predicates" {
    const nil: Value = .nil_val;
    const int = Value.initInteger(42);
    const float = Value.initFloat(3.14);

    try testing.expect(int.isInt());
    try testing.expect(!float.isInt());
    try testing.expect(float.isFloat());
    try testing.expect(int.isNumber() and float.isNumber());
    try testing.expect(!nil.isNumber());
}

test "encodeHeapPtr round-trip (string)" {
    var data: u64 align(8) = 0xDEAD_BEEF;
    const encoded = Value.encodeHeapPtr(.string, &data);
    try testing.expect(encoded.tag() == .string);
    const decoded = encoded.decodePtr(*u64);
    try testing.expectEqual(&data, decoded);
    try testing.expectEqual(@as(u64, 0xDEAD_BEEF), decoded.*);
}

test "encodeHeapPtr covers all four heap groups" {
    var obj_a: u64 align(8) = 0;
    var obj_b: u64 align(8) = 0;
    var obj_c: u64 align(8) = 0;
    var obj_d: u64 align(8) = 0;

    const a = Value.encodeHeapPtr(.keyword, &obj_a);
    const b = Value.encodeHeapPtr(.fn_val, &obj_b);
    const c = Value.encodeHeapPtr(.cons, &obj_c);
    const d = Value.encodeHeapPtr(.transient_vector, &obj_d);

    try testing.expect(a.tag() == .keyword);
    try testing.expect(b.tag() == .fn_val);
    try testing.expect(c.tag() == .cons);
    try testing.expect(d.tag() == .transient_vector);

    try testing.expectEqual(&obj_a, a.decodePtr(*u64));
    try testing.expectEqual(&obj_b, b.decodePtr(*u64));
    try testing.expectEqual(&obj_c, c.decodePtr(*u64));
    try testing.expectEqual(&obj_d, d.decodePtr(*u64));
}

test "Value is 8 bytes" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(Value));
}
