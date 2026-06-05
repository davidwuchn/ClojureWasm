// SPDX-License-Identifier: EPL-2.0
//! Marshal cljw `Value` ↔ `zwasm.Value`, driven by an export's runtime
//! signature (`exportFuncSig` ValTypes). The load-bearing piece of the wasm
//! FFI surface (ADR-0099): the untyped dynamic invoke path needs each arg
//! coerced to the param's wasm type and each result decoded from the result's
//! wasm type. i32 / i64 / f32 / f64 are covered; v128 / ref are out of P1
//! scope (Phase-16, when wasm refs become first-class cljw Values per F-004).
//!
//! Backend: impl-only
//! Impl deps: none
//! Clojure peer: wasm/load, wasm/call
const engine = @import("engine.zig");
const ValType = engine.ValType;
const ZValue = engine.Value;
const value_mod = @import("../../value/value.zig");
const Value = value_mod.Value;
const error_catalog = @import("../../error/catalog.zig");
const ClojureWasmError = error_catalog.ClojureWasmError;
const SourceLocation = @import("../../error/info.zig").SourceLocation;

/// Coerce one cljw `Value` to a `zwasm.Value` of the param's wasm type.
pub fn toWasm(arg: Value, vt: ValType, loc: SourceLocation) ClojureWasmError!ZValue {
    switch (vt) {
        .i32 => {
            if (!arg.isNumber()) return badArg(loc);
            return ZValue.fromI32(@intCast(intOf(arg)));
        },
        .i64 => {
            if (!arg.isNumber()) return badArg(loc);
            return ZValue.fromI64(intOf(arg));
        },
        .f32 => {
            if (!arg.isNumber()) return badArg(loc);
            const f: f32 = @floatCast(floatOf(arg));
            return ZValue.fromF32Bits(@bitCast(f));
        },
        .f64 => {
            if (!arg.isNumber()) return badArg(loc);
            return ZValue.fromF64Bits(@bitCast(floatOf(arg)));
        },
        .v128 => return error_catalog.raiseInternal(loc, "wasm/call: v128 arguments are not supported yet"),
        .ref => return error_catalog.raiseInternal(loc, "wasm/call: reference-typed arguments are not supported yet"),
    }
}

/// Decode one `zwasm.Value` result back to a cljw `Value`.
pub fn fromWasm(res: ZValue, loc: SourceLocation) ClojureWasmError!Value {
    switch (res) {
        .i32 => |v| return Value.initInteger(v),
        .i64 => |v| return Value.initInteger(v),
        .f32 => |bits| return Value.initFloat(@as(f32, @bitCast(bits))),
        .f64 => |bits| return Value.initFloat(@bitCast(bits)),
        .v128 => return error_catalog.raiseInternal(loc, "wasm/call: v128 results are not supported yet"),
        .funcref, .externref => return error_catalog.raiseInternal(loc, "wasm/call: reference-typed results are not supported yet"),
    }
}

/// cljw number → i64 (an int passes through; a float truncates toward zero).
fn intOf(v: Value) i64 {
    return if (v.isInt()) v.asInteger() else @intFromFloat(v.asFloat());
}

/// cljw number → f64 (a float passes through; an int widens).
fn floatOf(v: Value) f64 {
    return if (v.isFloat()) v.asFloat() else @floatFromInt(v.asInteger());
}

fn badArg(loc: SourceLocation) ClojureWasmError {
    return error_catalog.raiseInternal(loc, "wasm/call: argument is not a number");
}
