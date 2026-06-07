// SPDX-License-Identifier: EPL-2.0
//! `classOf` — the TypeDescriptor of a Value as an interned `.type_descriptor`
//! Value (ADR-0059). Factored out of `classPrim` (lang/primitive/protocol.zig)
//! so both `clojure.core/class` and `clojure.lang.Util/classOf`
//! (runtime/clojure/lang/Util.zig) delegate here and cannot drift (D-303).

const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const td_mod = @import("type_descriptor.zig");
const big_int_mod = @import("numeric/big_int.zig");
const ex_info_mod = @import("collection/ex_info.zig");
const host_class_mod = @import("error/host_class.zig");
const host_instance = @import("host_instance.zig");

/// `(class v)` semantics: nil → nil (JVM); a heap-boxed Long (D-165/ADR-0080)
/// is class Long, not BigInt; an exception reports its specific class
/// (ExInfo.class_name, simple-name normalized per AD-003); typed / reified /
/// host_instance carry their own descriptor; every other value consults the
/// per-Tag native descriptor. Interning (`makeTypeDescriptorRef` caches one ref
/// per descriptor) makes `(= (class a) (class b))` hold iff a, b share a type.
pub fn classOf(rt: *Runtime, v: Value) !Value {
    if (v.tag() == .nil) return Value.nil_val;
    if (v.tag() == .big_int and big_int_mod.originOf(v) == .long) {
        return td_mod.makeTypeDescriptorRef(rt, try rt.nativeDescriptor(.integer));
    }
    if (v.tag() == .ex_info) {
        const raw = ex_info_mod.className(v) orelse "ExceptionInfo";
        const simple = host_class_mod.normalizeClassName(raw);
        return td_mod.makeTypeDescriptorRef(rt, try rt.exceptionDescriptor(simple));
    }
    const td: *const td_mod.TypeDescriptor = switch (v.tag()) {
        .typed_instance => v.decodePtr(*const td_mod.TypedInstance).descriptor,
        .reified_instance => v.decodePtr(*const td_mod.ReifiedInstance).descriptor,
        .host_instance => host_instance.asHostInstance(v).descriptor,
        else => try rt.nativeDescriptor(v.tag()),
    };
    return td_mod.makeTypeDescriptorRef(rt, td);
}
