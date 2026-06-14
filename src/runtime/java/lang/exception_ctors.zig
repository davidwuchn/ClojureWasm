// SPDX-License-Identifier: EPL-2.0
//! Constructor surfaces for the common java.lang throwable subtypes the catch
//! hierarchy (`error/host_class.zig`) already recognises but had no `(X. msg)` /
//! `(X. msg cause)` ctor — IllegalArgumentException / IllegalStateException /
//! UnsupportedOperationException / NullPointerException / IndexOutOfBoundsException
//! / ArithmeticException / ClassCastException / NumberFormatException.
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: clojure.core/ex-info
//!
//! Each mints an `.ex_info` tagged with the class name (ADR-0059 no-JVM class;
//! `(catch …)` routes via the isSubclassOf hierarchy in host_class.zig). They all
//! share ONE impl shape (`ex_info.allocExceptionFromArgs`), so the family is
//! comptime-GENERATED — one descriptor + `<init>` per name — rather than N
//! near-identical files. (The per-class F-009 layout is for distinct impls; a
//! shared-impl family of marker-only ctors is the finished form here — a single
//! reviewable name list, no copy-paste drift.) Registered as a SLICE via
//! `EXTENSIONS`, which `_host_api.installAll` iterates alongside `java_surfaces`.
//! Throwable / Exception / RuntimeException keep their own files (pre-existing
//! roots); IOException (java.io, distinct package) is out of this java.lang set.

const std = @import("std");
const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");
const Value = @import("../../value/value.zig").Value;
const Runtime = @import("../../runtime.zig").Runtime;
const Env = @import("../../env.zig").Env;
const ex_info = @import("../../collection/ex_info.zig");
const SourceLocation = @import("../../error/info.zig").SourceLocation;

const NAMES = [_][]const u8{
    "IllegalArgumentException",
    "IllegalStateException",
    "UnsupportedOperationException",
    "NullPointerException",
    "IndexOutOfBoundsException",
    "ArithmeticException",
    "ClassCastException",
    "NumberFormatException",
};

/// Comptime family: a ctor + init pair per throwable name, closing over `name`.
/// `(X. msg)` / `(X. msg cause)` → an `.ex_info` tagged `name`.
fn Family(comptime name: []const u8) type {
    return struct {
        fn ctor(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
            _ = env;
            _ = loc;
            return ex_info.allocExceptionFromArgs(rt, args, name);
        }
        fn init(td: *type_descriptor.TypeDescriptor, gpa: std.mem.Allocator) anyerror!void {
            if (td.method_table.len != 0) return; // idempotent re-run
            const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, 1);
            entries[0] = .{
                .protocol_name = "",
                .method_name = try gpa.dupe(u8, "<init>"),
                .method_val = Value.initBuiltinFn(&ctor),
            };
            td.method_table = entries;
        }
    };
}

/// Module-scoped descriptors (mutable statics; `registerExtension` heap-copies
/// each into `rt.types`, keyed by the simple `fqcn`, like RuntimeException.zig).
var descriptors: [NAMES.len]type_descriptor.TypeDescriptor = blk: {
    var ds: [NAMES.len]type_descriptor.TypeDescriptor = undefined;
    for (NAMES, 0..) |name, i| ds[i] = .{
        .fqcn = name,
        .kind = .native,
        .field_layout = null,
        .protocol_impls = &.{},
        .method_table = &.{},
        .parent = null,
        .meta = .nil_val,
    };
    break :blk ds;
};

/// The Extension slice `_host_api.installAll` registers (sibling to the
/// per-file `java_surfaces` list).
pub const EXTENSIONS: [NAMES.len]host_api.Extension = blk: {
    var exts: [NAMES.len]host_api.Extension = undefined;
    for (NAMES, 0..) |name, i| exts[i] = .{
        .cljw_ns = "cljw.java.lang." ++ name,
        .descriptor = &descriptors[i],
        .init = &Family(name).init,
    };
    break :blk exts;
};
