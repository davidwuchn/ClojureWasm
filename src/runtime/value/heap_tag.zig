// SPDX-License-Identifier: EPL-2.0
//! Heap object discriminant tag (`HeapTag`) for cw v1 NaN-boxed Values.
//!
//! Stored in `HeapHeader.tag` on every heap-allocated object and also
//! encoded as a sub-type within heap-tagged Values (combined with the
//! group-band bits in the NaN-box top16). Per ADR-0012 + ADR-0027 the
//! enum is the single source of truth for the heap-tag namespace.
//!
//! Phase 4 entry shape: 32 entries (4 group × 8 sub-type). Phase 5 row
//! 5.2 widens to 64 entries (4 group × 16 sub-type) per F-004 + ADR-0027
//! §2 decree; this file currently carries the 32-entry g1 layout. The
//! widening lands as the 5.2.b follow-up commit per the split-then-widen
//! decomposition (see commit history at row 5.2).

// 32 heap slots (4 groups × 8 sub-types). A type check is a band+sub-type
// read; the value's HeapTag also lives in the object's HeapHeader.
//
// | Group (band)          | Sub 0    | Sub 1    | Sub 2     | Sub 3       | Sub 4   | Sub 5   | Sub 6    | Sub 7      |
// |-----------------------|----------|----------|-----------|-------------|---------|---------|----------|------------|
// | A: Core Data (0xFFF8) | string   | symbol   | keyword   | list        | vector  | arr_map | hash_map | hash_set   |
// | B: Call/Bind (0xFFF9) | fn_val   | multi_fn | protocol  | protocol_fn | var_ref | ns      | delay    | regex      |
// | C: Seq/State (0xFFFA) | lazy_seq | cons     | chunked_c | chunk_buf   | atom    | agent   | ref      | volatile   |
// | D: Trans/Ext (0xFFFB) | t_vector | t_map    | t_set     | reduced     | ex_info | big_int | ratio    | class      |

/// Heap object discriminant. Stored in the object's `HeapHeader.tag` and
/// also encoded as a 3-bit sub-type within heap-tagged Values (combined
/// with the 2-bit group band). Phase 5 row 5.2.b widens the encoding to
/// 4 group × 16 sub-type per F-004; this enum stays the g1 shape until
/// then so existing tests + callers see no churn from the file split.
pub const HeapTag = enum(u8) {
    // Group A: Core Data — immutable literals and persistent collections.
    string = 0,
    symbol = 1,
    keyword = 2,
    list = 3,
    vector = 4,
    array_map = 5,
    hash_map = 6,
    hash_set = 7,
    // Group B: Callable & Binding — invocable, dispatch, name resolution.
    fn_val = 8,
    multi_fn = 9,
    protocol = 10,
    protocol_fn = 11,
    var_ref = 12,
    ns = 13,
    delay = 14,
    regex = 15,
    // Group C: Sequence & State — lazy evaluation, mutable references.
    lazy_seq = 16,
    cons = 17,
    chunked_cons = 18,
    chunk_buffer = 19,
    atom = 20,
    agent = 21,
    ref = 22,
    @"volatile" = 23,
    // Group D: Transient & Extension — mutable colls, control, wasm, escape.
    transient_vector = 24,
    transient_map = 25,
    transient_set = 26,
    reduced = 27,
    ex_info = 28,
    // Slots 29 / 30: released from `wasm_module` / `wasm_fn` per
    // ADR-0006 amendment 1 (Wasm reintroduces via Pod boundary in
    // Phase 16, not as inline NaN-box values). Re-purposed for
    // Phase-5 numeric tower per ADR-0012 amendment 1.
    big_int = 29,
    ratio = 30,
    class = 31,
};
