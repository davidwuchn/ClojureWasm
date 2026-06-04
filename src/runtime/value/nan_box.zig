// SPDX-License-Identifier: EPL-2.0
//! NaN-box layout constants for cw v1 Value encoding (g2 64-slot per
//! F-004 + ADR-0027).
//!
//! Every Clojure value is a `u64` using IEEE-754 NaN boxing. The upper
//! 16 bits act as a tag:
//!
//!   top16 < 0xFFF8                 raw f64 (pass-through)
//!
//!   Heap groups (contiguous 0xFFF8-0xFFFB):
//!     0xFFF8  Group A  Hot data + persistent colls
//!     0xFFF9  Group B  Callables + reader extra
//!     0xFFFA  Group C  Mutable + concurrency + transient + sorted/queue
//!     0xFFFB  Group D  Numeric + wasm + extension
//!
//!   Immediate types (contiguous 0xFFFC-0xFFFF):
//!     0xFFFC  integer     i48, signed; overflow → float promotion
//!     0xFFFD  constant    0=nil, 1=true, 2=false
//!     0xFFFE  char        u21 codepoint
//!     0xFFFF  builtin_fn  48-bit function pointer
//!
//! Contiguous layout enables single-op classification:
//!   isHeap:      (top16 & 0xFFFC) == 0xFFF8
//!   isImmediate: (top16 & 0xFFFC) == 0xFFFC
//!
//! Heap-tag bit layout within a tagged Value (per ADR-0027 §1):
//!   bits 63..51   quiet-NaN signal (13)
//!   bits 50..49   group selector (2) — encoded within top16 = 0xFFFx
//!   bits 48..45   sub-type (4)         — 16 sub-types per group → 64 slots
//!   bits 44..1    pointer payload (44) — shifted by 3, 47-bit byte address = 128 TB
//!   bit  0        reserved per F-004   — implicit reservation, stays 0
//!
//! The layout is the g2 64-slot encoding (4 groups × 16 sub-types) per
//! F-004. All Values live in-process and are regenerated each
//! REPL/eval cycle, so there is no on-disk compatibility concern.

// Heap group tags (contiguous: 0xFFF8-0xFFFB)
pub const NB_HEAP_TAG_A: u64 = 0xFFF8_0000_0000_0000;
pub const NB_HEAP_TAG_B: u64 = 0xFFF9_0000_0000_0000;
pub const NB_HEAP_TAG_C: u64 = 0xFFFA_0000_0000_0000;
pub const NB_HEAP_TAG_D: u64 = 0xFFFB_0000_0000_0000;

// Immediate type tags (contiguous: 0xFFFC-0xFFFF)
pub const NB_INT_TAG: u64 = 0xFFFC_0000_0000_0000;
pub const NB_CONST_TAG: u64 = 0xFFFD_0000_0000_0000;
pub const NB_CHAR_TAG: u64 = 0xFFFE_0000_0000_0000;
pub const NB_BUILTIN_FN_TAG: u64 = 0xFFFF_0000_0000_0000;

pub const NB_TAG_SHIFT: u6 = 48;
pub const NB_PAYLOAD_MASK: u64 = 0x0000_FFFF_FFFF_FFFF;
/// 44-bit mask for `addr>>3` per F-004 "44-bit shifted pointer (128 TB)".
/// Pointer payload lives at bits 43..0; align-8 invariant forces the
/// low 3 bits of the byte address to zero, giving an effective 41-bit
/// byte index but 47-bit byte address after shift = 128 TB user space.
pub const NB_ADDR_SHIFTED_MASK: u64 = 0x0000_0FFF_FFFF_FFFF;
/// Sub-type field lives at bits 47..44 (4 bits) per F-004 + ADR-0027
/// §1. Encoding shifts the sub-type index left by NB_HEAP_SUBTYPE_SHIFT
/// to place it; decoding right-shifts + masks with NB_HEAP_SUBTYPE_MASK.
pub const NB_HEAP_SUBTYPE_SHIFT: u6 = 44;
pub const NB_ADDR_ALIGN_SHIFT: u3 = 3; // 8-byte alignment (>>3)
/// 16 sub-types per group (g2 per F-004).
pub const NB_HEAP_GROUP_SIZE: u8 = 16;

// Derived (kept in sync via expressions, not hand-written hex literals)
pub const NB_ADDR_ALIGN_MASK: u64 = (@as(u64, 1) << NB_ADDR_ALIGN_SHIFT) - 1;
pub const NB_HEAP_SUBTYPE_MASK: u64 = NB_HEAP_GROUP_SIZE - 1;
pub const NB_FLOAT_TAG_BOUNDARY: u16 = @truncate(NB_HEAP_TAG_A >> NB_TAG_SHIFT);
pub const NB_TAG_A: u16 = @truncate(NB_HEAP_TAG_A >> NB_TAG_SHIFT);
pub const NB_TAG_B: u16 = @truncate(NB_HEAP_TAG_B >> NB_TAG_SHIFT);
pub const NB_TAG_C: u16 = @truncate(NB_HEAP_TAG_C >> NB_TAG_SHIFT);
pub const NB_TAG_D: u16 = @truncate(NB_HEAP_TAG_D >> NB_TAG_SHIFT);
pub const NB_TAG_INT: u16 = @truncate(NB_INT_TAG >> NB_TAG_SHIFT);
pub const NB_TAG_CONST: u16 = @truncate(NB_CONST_TAG >> NB_TAG_SHIFT);
pub const NB_TAG_CHAR: u16 = @truncate(NB_CHAR_TAG >> NB_TAG_SHIFT);
pub const NB_TAG_BUILTIN: u16 = @truncate(NB_BUILTIN_FN_TAG >> NB_TAG_SHIFT);
pub const NB_I48_MIN: i64 = -(@as(i64, 1) << (NB_TAG_SHIFT - 1));
pub const NB_I48_MAX: i64 = (@as(i64, 1) << (NB_TAG_SHIFT - 1)) - 1;
pub const NB_CANONICAL_NAN: u64 = 0x7FF8_0000_0000_0000; // IEEE-754 positive quiet NaN
