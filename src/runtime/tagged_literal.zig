// SPDX-License-Identifier: EPL-2.0
//! `clojure.lang.TaggedLiteral` — the `#tag form` carrier value (ADR-0075,
//! NaN-box slot 24 `tagged_literal`). A fixed two-field, ILookup-only value
//! (NOT map-like): `(tagged-literal 'foo 5)` → `(:tag t)`=foo, `(:form t)`=5,
//! `(pr-str t)`=`#foo 5`, `=` by (tag, form). It is the opt-in unknown-tag
//! fallback (`(binding [*default-data-reader-fn* tagged-literal] …)`); the
//! default reader still RAISES on an unknown tag (ADR-0073 unchanged).
//!
//! Both fields are GC-managed Values, so the trace marks both and there is
//! NO finaliser (unlike `uuid.zig`'s inline bytes / `regex`'s gc.infra
//! payload). The `clojure.core/tagged-literal` + `tagged-literal?` surfaces
//! live in `lang/primitive/core.zig`; this file is the neutral impl (F-009).

const std = @import("std");
const value_mod = @import("value/value.zig");
const Value = value_mod.Value;
const HeapHeader = value_mod.HeapHeader;
const Runtime = @import("runtime.zig").Runtime;
const keyword_mod = @import("keyword.zig");
const tag_ops = @import("gc/tag_ops.zig");
const gc_heap_mod = @import("gc/gc_heap.zig");
const mark_sweep = @import("gc/mark_sweep.zig");

/// Heap-managed TaggedLiteral. `header` at offset 0 (gc.alloc invariant);
/// `tag` is a symbol Value, `form` the carried value. Both GC-traced.
pub const TaggedLiteral = extern struct {
    header: HeapHeader,
    _pad: [6]u8 = .{ 0, 0, 0, 0, 0, 0 },
    tag: Value,
    form: Value,

    comptime {
        std.debug.assert(@alignOf(TaggedLiteral) >= 8);
        std.debug.assert(@offsetOf(TaggedLiteral, "header") == 0);
    }
};

/// Wrap `(tag, form)` in a fresh `.tagged_literal` heap Value.
pub fn alloc(rt: *Runtime, tag: Value, form: Value) !Value {
    const t = try rt.gc.alloc(TaggedLiteral);
    t.* = .{ .header = HeapHeader.init(.tagged_literal), .tag = tag, .form = form };
    return Value.encodeHeapPtr(.tagged_literal, t);
}

/// Decode. Caller verifies `v.tag() == .tagged_literal`.
pub fn asTaggedLiteral(v: Value) *const TaggedLiteral {
    std.debug.assert(v.tag() == .tagged_literal);
    return v.decodePtr(*const TaggedLiteral);
}

/// ILookup: answer ONLY `:tag` / `:form`, else `not_found` (matches clj's
/// `valAt` — TaggedLiteral is ILookup-only, not associative). The single
/// source the `get` primitive + keyword-invoke `(:tag t)` both call.
pub fn valAt(v: Value, k: Value, not_found: Value) Value {
    if (k.tag() != .keyword) return not_found;
    const kw = keyword_mod.asKeyword(k);
    if (kw.ns != null) return not_found;
    const t = asTaggedLiteral(v);
    if (std.mem.eql(u8, kw.name, "tag")) return t.tag;
    if (std.mem.eql(u8, kw.name, "form")) return t.form;
    return not_found;
}

/// Per-tag trace: both fields are GC Values, so mark each.
fn traceTaggedLiteral(gc_ptr: *anyopaque, header: *HeapHeader) void {
    const gc: *gc_heap_mod.GcHeap = @ptrCast(@alignCast(gc_ptr));
    const t: *TaggedLiteral = @ptrCast(@alignCast(header));
    if (t.tag.heapHeader()) |h| mark_sweep.mark(gc, h);
    if (t.form.heapHeader()) |h| mark_sweep.mark(gc, h);
}

pub fn registerGcHooks() void {
    tag_ops.registerTrace(.tagged_literal, &traceTaggedLiteral);
    // No finaliser — both fields are GC Values (nothing on gc.infra to free).
}

const testing = std.testing;

test "valAt answers :tag/:form, else not_found" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var rt = Runtime.init(th.io(), testing.allocator);
    defer rt.deinit();

    const sym = @import("symbol.zig");
    const tag = try sym.intern(&rt, null, "foo");
    const form = Value.initInteger(5);
    const tl = try alloc(&rt, tag, form);
    try testing.expectEqual(value_mod.Value.Tag.tagged_literal, tl.tag());

    const k_tag = try keyword_mod.intern(&rt, null, "tag");
    const k_form = try keyword_mod.intern(&rt, null, "form");
    const k_other = try keyword_mod.intern(&rt, null, "nope");
    try testing.expectEqual(tag, valAt(tl, k_tag, Value.nil_val));
    try testing.expectEqual(form, valAt(tl, k_form, Value.nil_val));
    try testing.expectEqual(Value.nil_val, valAt(tl, k_other, Value.nil_val));
}
