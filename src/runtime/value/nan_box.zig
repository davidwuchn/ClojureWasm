// SPDX-License-Identifier: EPL-2.0
//! NaN-box layout constants for cw v1 Value encoding.
//!
//! Every Clojure value is a `u64` using IEEE-754 NaN boxing. The upper
//! 16 bits act as a tag:
//!
//!   top16 < 0xFFF8                 raw f64 (pass-through)
//!
//!   Heap groups (contiguous 0xFFF8-0xFFFB):
//!     0xFFF8  Group A  Core Data           sub-type[47:45] | addr>>3 [44:0]
//!     0xFFF9  Group B  Callable & Binding  sub-type[47:45] | addr>>3 [44:0]
//!     0xFFFA  Group C  Sequence & State    sub-type[47:45] | addr>>3 [44:0]
//!     0xFFFB  Group D  Transient & Ext     sub-type[47:45] | addr>>3 [44:0]
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
//! Slot mapping is 1:1 (no slot-sharing + discriminant) so a type check
//! reduces to a band comparison on top16 plus a 3-bit sub-type read.
//!
//! Phase 5 row 5.2.b widens the sub-type field 3 → 4 bits per F-004 +
//! ADR-0027 §1 (64 slot, 44-bit shifted pointer, 128 TB user space).
//! The constants below are the g1 32-slot shape; the widening lands as
//! the follow-up 5.2.b commit per the split-then-widen decomposition.

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
pub const NB_ADDR_SHIFTED_MASK: u64 = 0x0000_1FFF_FFFF_FFFF; // 45 bits for addr>>3 (g1)
pub const NB_HEAP_SUBTYPE_SHIFT: u6 = 45; // 3-bit sub-type at bits 47..45 (g1)
pub const NB_ADDR_ALIGN_SHIFT: u3 = 3; // 8-byte alignment (>>3)
pub const NB_HEAP_GROUP_SIZE: u8 = 8; // g1; widens to 16 at 5.2.b per F-004

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
