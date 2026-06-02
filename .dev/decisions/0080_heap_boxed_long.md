# ADR-0080 — Heap-boxed Long: an `IntOrigin` flag on the heap-integer struct

**Status**: Proposed → Accepted (2026-06-03, clj-parity campaign C7 / D-165)

## Context

ADR-0076 §9.2.P clj-parity campaign unit **C7 (D-165)** (the LAST unit):
cljw's NaN-box inline integer is i48 (±2^47 ≈ ±1.4e14). A Long value beyond
±2^47 but within i64 currently promotes to a heap **BigInt** (D-014a), so it
prints with an `N` suffix and `(class …)` → BigInt. clj keeps it a primitive
**Long** to the full i64 range.

Oracle-verified: `(parse-long "999999999999999")` → cljw `999999999999999N`
(BigInt) / clj `999999999999999` (Long); `(* 1000000000 1000000)` → cljw
`1000000000000000N` / clj `1000000000000000`; `9999999999999999` (16-digit
no-`N` literal, > i48, ≤ i64) → cljw "BigInt" / clj java.lang.Long. The VALUE
is exact; only the print form (`N`) + `(class)` diverge.

**Representation is user-settled (F-005 LAW, ADR-0076 am1 — NOT re-litigated):
B2 = a flag on the heap-integer (BigInt) struct.** NO new NaN-box slot (F-004
UNCHANGED — an 8-byte Value can't hold tag + i64; i64-inline is physically
impossible, cw v0 also i48). A heap-boxed Long mirrors the JVM (boxes Long on
the heap, stays class Long).

The flag is **intent-based, not value-range-based** (oracle):
`(parse-long "999999999999999")` → Long despite exceeding i48; `(bigint 5)` /
`5N` → BigInt despite fitting a Long; `99999999999999999999` (no-`N`, past i64)
→ BigInt (`…N`). So the producing call sets the flag; it is never inferred from
the stored magnitude.

## Decision

A non-defaulted `IntOrigin` enum on the heap-integer struct, set by every
producing call (the Devil's-advocate fork's Alt 2, chosen over the survey's
defaulted bool — see Alternatives):

```zig
pub const IntOrigin = enum { long, bigint };
pub const BigInt = extern struct {
    header: HeapHeader,
    origin: IntOrigin,   // 1 byte — replaces ONE _pad byte; m's offset preserved
    _pad: [5]u8 = .{ 0, 0, 0, 0, 0 },
    m: *Managed,
};
```

- **No default** on `origin` — the alloc constructors take it as a REQUIRED
  arg, so a forgotten classification is a COMPILE ERROR, not a silent
  mis-print on the common (Long) path. This is the core of the DA's correction:
  the work is "classify every producing site", and a required enum makes
  omission un-compilable + each site self-documenting (`.long` / `.bigint`).
- `wrapI64` / `wrapManaged` (the "exact i64 → Value" collapse path) hard-wire
  `.long` — they are the Long-category overflow/collapse entry points.
- **Arithmetic needs NO flag propagation** (the DA's key simplification): the
  dispatch ARM already encodes category. In `promote.zig`, the both-int arm
  (Long ⊕ Long, e.g. `addPromoting` line 243's i64-overflow `allocAddManaged`)
  passes `.long`; the both-Managed / contagion arm (any BigInt operand, e.g.
  line 249, `quotPromoting`'s `isExactBig` branch) passes `.bigint`. The same
  `allocAddManaged` fn is called from two arms with OPPOSITE origins — the
  enum makes that visible. No operand `origin` is ever READ during arithmetic;
  only written per-arm.
- **Literals** (analyzer `parseBigIntLiteral` / reader): no-`N` literal in
  (2^47, i64] → `.long`; no-`N` literal > i64 → `.bigint`; `N`-literal →
  `.bigint`. (Oracle: `9999999999999999`→Long, `99999999999999999999`→BigInt
  `…N`, `5N`→BigInt.)
- **`bigint`/`biginteger` fns + bigint coerce** → `.bigint` (BigInt regardless
  of magnitude); `long`/`int` coerce → `.long`; `parse-long`/Long·Math statics
  / JSON int → `.long`.
- **print** (`printBigInt`) gates the `N` suffix on `origin == .bigint`.
- **`(class)` + `instance?`** (`class_name.zig`): the `.big_int` tag now yields
  TWO class names by `origin` — `.long` → "Long", `.bigint` → "BigInt". The DA
  flagged that this makes `nativeTagFor` non-injective: a heap-Long answers
  `(instance? Long x)`→true / `(class)`→"Long" while tagged `.big_int`. Both
  the class-display and the `isInstance`/`matchUserType` "Long" paths consult
  `origin`.
- **`=` / hash UNCHANGED** — already value-based (D-205), so `(= 5N 5)`→true and
  `(= (hash 5N) (hash 5))`→true hold for free; the flag is print/class only.
  (Pinned by a corpus regression line regardless.)

## Consequences

- `(parse-long "999999999999999")`→Long (no `N`, class Long); `(* 1000000000
  1000000)`→Long; `9999999999999999`→Long; `(bigint 5)`→5N; `5N`→BigInt;
  `99999999999999999999`→BigInt. The i47-inline window (±1.4e14) covers
  ms-timestamps (~4400 yr) / counters / sizes; only sub-ms timestamps /
  Snowflake IDs / 64-bit hashes take the heap-Long path (still ≤ JVM, which
  boxes everything > 127).
- Closes D-165 — the LAST clj-parity campaign unit. After C7, C1..C7 are
  complete; D-210 anchor becomes a standing `quality-loop floor` (drain new
  sweep DIFFs). Overflow-past-i64 promote-vs-throw stays the separate
  user-ratified **AD-008**.

## Affected files

- `runtime/numeric/big_int.zig` (`IntOrigin` + struct field + `origin`-taking
  `allocFromI64`/`allocFromManaged`), `runtime/numeric/promote.zig` (`wrapI64`/
  `wrapManaged` → `.long`; each arith arm passes its origin),
  `runtime/numeric/ratio.zig` + `big_decimal.zig` (internal bigints → `.bigint`;
  `@offsetOf` asserts unchanged), `eval/analyzer/analyzer.zig` +
  `eval/reader.zig` (literal origin by range/`N`), `lang/primitive/math.zig`
  (bigint/long/int coerce, parse-long), `lang/primitive/json.zig` (int read →
  `.long`), `runtime/print.zig` (`N` gate), `runtime/class_name.zig` (class +
  isInstance by `origin`). Corpus `heap_long.txt` + e2e.

## Alternatives considered

(Devil's-advocate subagent, fresh context, depth-≥2 mandate. Within B2 + the
F-NNN envelope — slot-vs-flag is user-settled, NOT re-litigated.)

### Alt 1 — Smallest-diff: defaulted `long_origin: bool = false` + thin `…Long` wrapper variants

The survey's shape: `long_origin: bool = false` (BigInt-default, preserves
unmigrated paths' `N`); `allocFromManagedLong`/`allocFromI64Long` wrappers set
true; contagion arms call the base (false) variants.

**Better:** minimal struct churn; existing caller signatures unchanged.

**Breaks/risks:** the `= false` default is a loaded gun on the COMMON path —
most heap integers in real code are overflowed Longs, not bigints, so every
miss (a forgotten arm, a future Phase-15 arith path) silently prints `N` on a
value that should be a plain Long = the C7 bug re-introduced by omission. No
compiler help for the 8 promote.zig arms; the `allocAddManaged`-called-from-
two-arms-with-opposite-flags reality is invisible. The **Smallest-diff bias
smell**: cheap struct edit, classification cost pushed onto unaided vigilance.

### Alt 2 — Finished-form-clean (CHOSEN): non-defaulted `IntOrigin` enum on a unified constructor

The decision above. **Omission is a compile error** (required enum arg); the
two-arms-one-fn trap becomes two visibly-different `.long` / `.bigint` call
sites; no default-direction debate (there is no default); self-documenting.

**Better:** classification is STRUCTURALLY enforced, not vigilance-enforced
(F-002 finished form); future arith arms inherit the same compiler pressure.

**Risks:** larger diff — every `allocFromManaged`/`allocFromI64` caller
(ratio/big_decimal/math/json/analyzer + the ~12 sites) adds an `origin` arg.
But that IS the C7 task (classify each), and cycle/diff size is not an F-NNN
constraint (anti-Cycle-budget-defer). Ratio numerator/denominator internal
bigints pass `.bigint` (a harmless fixed choice — they print via ratio's own
path, never standalone).

### Alt 3 — Wildcard: a separate `HeapTag.long_box` tag (no new NaN-box slot)

A distinct `HeapTag` value (not a new NaN-box slot) for heap-Long; genuine
BigInt keeps `.big_int`; both point at identical `BigInt` structs. `class_name`
becomes injective again; print gates on tag; `=`/hash tag-agnostic.

**Better:** cleanest type-system answer — every `switch (v.tag())` is forced to
consider both; `nativeTagFor` stays injective.

**Breaks/risks — REJECTED:** it relitigates the user-settled B2 ("a FLAG on the
struct", not a new tag) and carries a >20-site `.big_int or .long_box` sweep
across promote.zig (coerceToManaged / toF64 / isExactBig / every arith arm) — a
missed one silently treats a heap-Long as a non-integer (far larger regression
surface than Alt 2's write-side-only risk). Cleaner in theory, highest
regression in practice; recorded, not adopted (would need the user to reopen
B2).

### Decision

**Alt 2 chosen** (per the DA, over the survey's defaulted-bool Alt 1) — the
non-defaulted enum makes the per-site classification compile-enforced, killing
the common-path silent-mis-print risk. Two DA-surfaced sites the survey missed
are fixed in the same cycle: `isInstance`/`nativeTagFor` non-injectivity, and
the oracle-pinned past-i64-literal print. Alt 3 (new HeapTag) rejected
(relitigates B2 + >20-site sweep). No F-NNN amendment (B2 + F-004 + F-005 hold).

## Revision history

- 2026-06-03 created (Accepted): clj-parity C7 / D-165 (LAST unit). `IntOrigin`
  enum (DA Alt 2) over the defaulted bool (survey); arithmetic classifies by
  dispatch-arm category (no operand-flag propagation); `=`/hash untouched
  (D-205); class/isInstance/print gate on `origin`. AD-008 (overflow-past-i64)
  stays separate.
