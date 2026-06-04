// SPDX-License-Identifier: EPL-2.0
//! Java surface for `java.util.Random`.
//!
//! Backend: impl-only
//! Impl deps: random
//! Clojure peer: none. clojure.core/rand & rand-int are primitives
//! in `lang/primitive/math.zig` that call `runtime/random.zig`
//! directly — they do NOT route through this Java surface.
//!
//! The `___HOST_EXTENSION` declaration is registered, but the
//! method_table is empty: instance methods (nextInt / nextLong /
//! nextDouble / setSeed) over `runtime/random.zig` are not yet
//! wired. This surface is a reservation only.

const host_api = @import("../_host_api.zig");
const type_descriptor = @import("../../type_descriptor.zig");

pub const ___HOST_EXTENSION: host_api.Extension = .{
    .cljw_ns = "cljw.java.util.Random",
    .descriptor = &descriptor,
};

var descriptor: type_descriptor.TypeDescriptor = .{
    .fqcn = "cljw.java.util.Random",
    .kind = .native,
    .field_layout = null,
    .protocol_impls = &.{},
    .method_table = &.{},
    .parent = null,
    .meta = .nil_val,
};
