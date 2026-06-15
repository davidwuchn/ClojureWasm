// SPDX-License-Identifier: EPL-2.0
//! Host-interop instance methods on the `.ratio` value (clojure.lang.Ratio).
//! clj's Ratio exposes `.numerator` / `.denominator` (→ BigInteger). Real libs
//! reach them via the dot form: clojure.math.numeric-tower's MathFunctions
//! extends `clojure.lang.Ratio` and computes floor/ceil/round/sqrt with
//! `(. n numerator)` / `(. n denominator)`. Installs on the per-Runtime
//! `.ratio` native descriptor — the same `receiverDescriptor` → `method_table`
//! path String / Keyword / BigDecimal interop uses (D-420).
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: clojure.core/numerator, clojure.core/denominator (same impl).

const Value = @import("value/value.zig").Value;
const Runtime = @import("runtime.zig").Runtime;
const Env = @import("env.zig").Env;
const ratio_mod = @import("numeric/ratio.zig");
const promote = @import("numeric/promote.zig");
const type_descriptor = @import("type_descriptor.zig");
const SourceLocation = @import("error/info.zig").SourceLocation;

/// `(.numerator r)` — the Ratio's numerator as an integer. Mirrors
/// `(numerator r)` (math.zig); clj `Ratio.numerator`.
fn ratioNumerator(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    return switch (ratio_mod.parts(args[0])) {
        .small => |s| promote.wrapI64(rt, s.n),
        .big => |b| promote.wrapManaged(rt, b.n.m),
    };
}

/// `(.denominator r)` — the Ratio's denominator as an integer (always > 0).
/// Mirrors `(denominator r)`; clj `Ratio.denominator`.
fn ratioDenominator(rt: *Runtime, env: *Env, args: []const Value, loc: SourceLocation) anyerror!Value {
    _ = env;
    _ = loc;
    return switch (ratio_mod.parts(args[0])) {
        .small => |s| promote.wrapI64(rt, s.d),
        .big => |b| promote.wrapManaged(rt, b.d.m),
    };
}

/// Populate the per-Runtime `.ratio` native descriptor's method table.
/// Idempotent. Called at runtime init alongside the other native installers.
pub fn installNativeMethods(rt: *Runtime) !void {
    const td = try rt.nativeDescriptor(.ratio);
    if (td.method_table.len != 0) return; // idempotent re-run
    const gpa = rt.gc.infra;
    const specs = .{
        .{ "numerator", &ratioNumerator },
        .{ "denominator", &ratioDenominator },
    };
    const entries = try gpa.alloc(type_descriptor.TypeDescriptor.MethodEntry, specs.len);
    inline for (specs, 0..) |spec, i| {
        entries[i] = .{
            .protocol_name = "",
            .method_name = try gpa.dupe(u8, spec[0]),
            .method_val = Value.initBuiltinFn(spec[1]),
        };
    }
    td.method_table = entries;
}
