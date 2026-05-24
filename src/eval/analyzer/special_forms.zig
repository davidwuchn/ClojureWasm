// SPDX-License-Identifier: EPL-2.0
//! Analyzer sub-module per D-030 split — special-form analysers.
//!
//! Phase 6.1.b (this commit) extracts `analyzeDeftype` as the
//! pattern proof. 6.1.c lands `analyzeDef` / `analyzeIf` /
//! `analyzeDo` / `analyzeQuote` / `analyzeThrow` /
//! `analyzeCtorCall` / `analyzeFieldAccess` alongside it; the
//! orchestrating `analyzeSpecial` dispatcher stays in
//! `analyzer/analyzer.zig`.

const std = @import("std");
const Form = @import("../form.zig").Form;
const node_mod = @import("../node.zig");
const Node = node_mod.Node;
const error_catalog = @import("../../runtime/error/catalog.zig");
const analyzer_mod = @import("analyzer.zig");
const AnalyzeError = analyzer_mod.AnalyzeError;

/// `(deftype Name [field1 field2 ...])` per ADR-0007 Option β.
/// Phase 5.12.a scope: declaration only — protocol method bodies
/// (items[3..]) silently dropped until 5.12.d wires the dispatch
/// ABI.
pub fn analyzeDeftype(arena: std.mem.Allocator, items: []const Form, form: Form) AnalyzeError!*const Node {
    if (items.len < 3) {
        return error_catalog.raise(.feature_not_supported, form.location, .{ .name = "deftype with no field list" });
    }
    if (items[1].data != .symbol) {
        return error_catalog.raise(.def_name_not_symbol, items[1].location, .{});
    }
    const name_sym = items[1].data.symbol;
    if (name_sym.ns != null) {
        return error_catalog.raise(.def_name_namespace_qualified, items[1].location, .{ .ns = name_sym.ns.?, .name = name_sym.name });
    }
    if (items[2].data != .vector) {
        return error_catalog.raise(.bindings_not_vector, items[2].location, .{ .form = "deftype" });
    }
    const field_forms = items[2].data.vector;
    const field_names = try arena.alloc([]const u8, field_forms.len);
    for (field_forms, 0..) |fld, i| {
        if (fld.data != .symbol) {
            return error_catalog.raise(.binding_name_not_symbol, fld.location, .{ .form = "deftype" });
        }
        if (fld.data.symbol.ns != null) {
            return error_catalog.raise(.binding_name_namespace_qualified, fld.location, .{ .form = "deftype" });
        }
        field_names[i] = fld.data.symbol.name;
    }
    const n = try arena.create(Node);
    n.* = .{ .deftype_node = .{
        .name = name_sym.name,
        .fields = field_names,
        .loc = form.location,
    } };
    return n;
}
