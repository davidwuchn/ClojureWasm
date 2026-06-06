# ADR-0105 — Java arrays (aget / aset / make-array / *-array / alength / aclone)

- Status: Proposed → Accepted (2026-06-07)
- Drives: D-287 (Java arrays); campaign Stage 1.3 ladder rung 4b
  (flatland.ordered `aset`) + rung 6 (clojure.tools.reader `aget`).
- Related: ADR-0104 (TypedInstance mutable slice precedent), ADR-0059 / AD-003
  (no-JVM simple class name), F-002 / F-003 / F-004 / F-005 / F-009 / F-011 /
  F-012 / F-013.

## Context

cljw has a RESERVED-but-unwired `.array` Value tag (slot 51 D3,
`value/value.zig:100` + `heap_tag.zig:105`) — no struct, no trace fn, no
primitive. `aget` → "Unable to resolve symbol". Real pure-Clojure libraries use
Java arrays as a mutable backing store:

- **flatland.ordered** (rung 4b): `aset` at set.clj:84 (object-array store).
- **clojure.tools.reader** (rung 6): reader_types.clj:62 `aget`;
  `InputStreamReader` (`^"[B"` byte-array + `(aget buf 0)` / `(byte-array 1)` /
  `(.read is buf)`), `PushbackReader` (`^"[Ljava.lang.Object;"` object-array).

## Decision

Wire the reserved `.array` tag as a **type-erased mutable `[]Value`** array,
implemented as **plain `BuiltinFn` primitives** (no analyzer Node / VM opcode —
both backends free, like every collection op). Representation mirrors the
just-landed ADR-0104 `TypedInstance`:

```zig
pub const JavaArray = extern struct {
    header: HeapHeader,
    len: u32,
    _pad: [4]u8 = .{0,0,0,0},
    items_ptr: [*]Value,   // gc.infra-owned, mutable, traced
};
```

`aset` writes `items_ptr[i] = v` in place (non-moving mark-sweep, slot already
traced — no write barrier, exactly `TypedInstance.setField`). Trace mirrors
`traceTypedInstance`; finaliser frees the `gc.infra` slice.

### Behavioural fidelity (F-011 — oracle-verified, NOT divergences)

The element TYPE is erased after construction, but observable clj behaviour is
preserved:

1. **Per-constructor init defaults** (oracle): `int-array`/`long-array`/
   `make-array <numeric>` → `0`; `double-array`/`float-array` → `0.0`;
   `boolean-array` → `false`; `char-array` → `\space`;
   `object-array`/`make-array <ref>` → `nil`. The constructor fills the
   correct default Value, then forgets the type. (A uniform nil-fill would be
   an F-011 bug, not licensed by any AD.)
2. **Byte/short/char wrap** (oracle: `(vec (byte-array [1 2 300]))` →
   `[1 2 44]`): `byte-array` / `aset-byte` (and short/char) apply the clj
   modular wrap before storing the (boxed-int) Value. `aset-int`/`-long`/
   `-double` need no coercion (the f64 tower already holds them); they are
   aliases of `aset`.
3. **Identity equality**: `(= (object-array 1) (object-array 1))` → false.
   Verified: `equal.zig` already returns `else => false` for distinct `.array`
   pointers and the identity fast-path covers equal ones — **no new `.array`
   equal arm is added** (adding one would be over-specification).
4. **`aclone` / `to-array`**: copy contents into a fresh array (not
   `identical?`).
5. **Multi-dim** `(make-array T d1 d2)` / `(aget a i j)` / `(aset a i j v)`:
   nested arrays, looped indices (clj parity).

### Type erasure is the one accepted divergence (AD-019)

Array element type HINTS (`^"[B"`, `^"[Ljava.lang.Object;"`, `^ints`,
`^bytes`) parse to advisory `{:tag …}` and do not constrain element values;
`aset` to a "typed" array never raises on element-type mismatch (e.g. a String
into an `int-array`). `derives_from` F-004 (uniform 8-byte Value) + F-005 (no
primitive specialization) + ADR-0059. The `(class (object-array 0))` /
`(class (aget (int-array 3) 0))` simple-name surface is **already AD-003**
(no-JVM simple class name) — array cases are added to AD-003's coverage, NOT
minted as a separate AD.

### Packed `[]u8` byte-array is DEFERRED to Phase 16 (F-003)

The Devil's-advocate fork recommended a SEPARATE packed `ByteArray` (`[]u8`)
for `byte-array` (Phase-16 Wasm-linear-memory / binary-I/O / digest can
`@memcpy` it; `bytes?` becomes a distinct tag). That is a real finished-form
candidate — but **whether `byte-array` is the Phase-16 binary vehicle, or a
dedicated `WasmMemory`/`ByteBuffer` host object is (JVM: `byte-array` ≠
`java.nio.ByteBuffer`), is an unmade Phase-16 structural decision.** Per F-003
(decision-deferral over decision-seizure on structural plans) + the
principle.md Structural-imagination phase, the packed representation is
**deferred to its owning Phase-16 design**, recorded as a debt row, NOT seized
now on speculation. This is NOT the Cycle-budget-defer smell: the uniform
`[]Value` array with byte-WRAP is **fully F-011-behaviourally-equivalent**
today (packing is a performance/representation choice, not a behaviour gap);
A is the finished form for Phase 13's scope, and the packed rep is Phase 16's
finished-form decision to make with its own context.

### Surface (F-013 — definition-derived comprehensive, not lib-minimum)

`aget`, `aset` (+ `aset-int`/`-long`/`-double`/`-float`/`-short`/`-char`/
`-byte`/`-boolean` aliases, with byte/short/char wrap), `make-array`,
`object-array`, `int-array`, `long-array`, `double-array`, `float-array`,
`short-array`, `byte-array`, `char-array`, `boolean-array`, `to-array`,
`to-array-2d`, `into-array`, `aclone`, `alength`, the `ints`/`longs`/`bytes`/
`shorts`/`chars`/`floats`/`doubles`/`booleans`/`objects` cast fns; `amap` /
`areduce` as `core.clj` macros over aget/aset/alength. `clojure.core/{array?
is implicit via class}` + a `bytes?`-style predicate returns true for any
array (single erased kind) — until the Phase-16 packed split gives `bytes?` a
distinct tag.

### Code placement (F-009 / zone)

New `runtime/collection/java_array.zig` (neutral impl, `keyword: array`) +
`lang/primitive/array.zig` (primitive surface, registered in
`lang/primitive.zig registerAll`); Value glue in `value.zig` (initArray /
asArray), `class_name.zig`, `print.zig` (`#object` / simple form), the trace
table, `gc` finaliser; `amap`/`areduce` in `core.clj`. cw v0's
`src/lang/builtins/array.zig` (617 lines) is read-only prior art — its
`element_type` enum is dropped (it bought nothing; type erasure is cleaner).

## Alternatives considered (Devil's-advocate, fresh context)

> Verbatim from a fresh-context `general-purpose` Devil's-advocate fork. Active
> F-NNN envelope: F-002 / F-004 / F-005 / F-009 / F-011 / F-012 / F-013.

**Leading finding (oracle-forced F-011 corrections, applied to the Decision
above, not alternative-specific):** (1) make-array/*-array init value is NOT
"nil for all" — it is the clj type-default per constructor (0 / 0.0 / false /
\space / nil); a uniform nil-fill is an F-011 bug. (2) `aset-byte`/`byte-array`
DO coerce (`300`→`44` signed-byte wrap) — a bare alias-of-`aset` with no wrap
is a silent F-011 divergence (Silent-default-shift smell). Both corrected.

**Alt A — Smallest-diff: type-erased `[]Value` JavaArray with correct
per-constructor init + byte wrap (no stored element_type).** Better: the draft
minus the two F-011 bugs; reuses the proven ADR-0104 GC pattern; F-004/F-005
clean; identity equality free (no new equal arm). Breaks/leaves: defers the
packed-byte question to Phase 16 — legitimate under F-003 only if byte path is
not needed now (tools.reader's `(.read is buf)` writes byte-as-int Values into
`items_ptr`, so `[]Value` works today); risk is a future copy at a Phase-16
contiguous-`[]u8` boundary.

**Alt B — Finished-form-clean (DA recommended): type-erased `[]Value` for
object/int/long/double PLUS a separate packed `ByteArray` (`[]u8`) for
byte-array.** Better: Phase-16-correct (contiguous buffer for Wasm memory /
binary I/O / digest, zero box/unbox per byte); honest `bytes?`; byte-wrap
intrinsic. The DA argues F-005 does NOT block it (F-005 forbids numeric-TOWER
specialization; a `[]u8` byte-array is STORAGE, boxed-on-`aget`, analogous to a
UTF-8 String being `[]u8` — F-004 also holds, the Value handle is still 8
bytes). Breaks/costs: 2 array kinds → 2-arm dispatch on every array op;
asymmetric (only byte packed — why not int/double?); a second tag slot. **DA's
own decisive caveat**: B hinges on a Phase-16 representation question the draft
does not resolve — if Phase 16 uses a dedicated `WasmMemory`/`ByteBuffer`
distinct from clojure `byte-array`, then byte-array has no finished-form binary
consumer and A is finished-form-clean. "The ADR should state which world it
assumes."

> **Main-loop decision (A, recorded not deferred):** adopt **Alt A** + the two
> F-011 corrections + a Phase-16 deferral debt row for the packed `[]u8`
> byte-array. The A-over-B choice is **F-003 (decision-deferral on structural
> plans)**, NOT cycle-budget: B's packed-byte rep depends on the unmade
> Phase-16 Wasm-memory ↔ byte-array structural decision (the DA's own caveat),
> and the Structural-imagination phase says imagine the horizon, record the gap
> as a debt row at the owning Phase, and DEFER the structural decision to that
> owner. Seizing B now risks building byte-only packing that Phase 16 unwinds
> if it chooses a dedicated buffer type. Crucially A is **fully F-011-equivalent
> today** (byte WRAP, not packing, gives `[1 2 44]`), so this defers a
> performance/representation choice, not a behaviour — exactly what F-003
> covers. (If this were a behaviour gap, F-011 would forbid the defer.)

**Alt C — Wildcard: back arrays with the existing transient_vector store.**
Better: zero new GC machinery (reuse transient tracing/rooting). Breaks:
imports HAMT-trie + tail growable machinery to model a fixed flat buffer
(Smallest-diff-bias); transient `assoc!` may return a new transient vs
array `aset`'s in-place-return-val; identity bookkeeping re-introduced; blocks
the Phase-16 packed path. Strictly worse than A on finished-form; recorded for
completeness, not competitive.

**Cross-cutting fixes adopted from the DA:** no new `equal.zig` `.array` arm
(identity is free); array `(class …)` folds into AD-003 (not a new AD-020);
AD-019 tightened to "type hints advisory + `aset` no type-check" (init-defaults
+ byte-wrap are F-011 obligations, not AD content); F-013 surface widened
(to-array-2d, into-array, the cast fns, multi-dim); plain-primitive decision
confirmed F-012-clean.

## Consequences

- flatland.ordered (rung 4b) advances past `aset`; tools.reader (rung 6) past
  `aget` — both unblock the array layer (further blockers may remain, e.g.
  java.io.InputStream/Closeable for tools.reader's InputStreamReader).
- A new wired Value type (`.array`) + ~25 primitives + amap/areduce macros. All
  additive plain primitives — no analyzer Node / VM opcode / dual-backend node.
- AD-019 (type hints advisory) + AD-003 array cases. One Phase-16 deferral debt
  row (packed `[]u8` byte-array).

## Affected files

- `src/runtime/collection/java_array.zig` (NEW — impl).
- `src/lang/primitive/array.zig` (NEW — primitive surface) + register in
  `src/lang/primitive.zig`.
- `src/runtime/value/value.zig` — `initArray` / `asArray` / `JavaArray` glue on
  the `.array` tag.
- `src/runtime/gc/…` trace table + finaliser for `.array`.
- `src/runtime/print.zig` + `src/runtime/class_name.zig` — array print + simple
  class name (AD-003).
- `src/lang/clj/core.clj` — `amap` / `areduce` macros.
- `.dev/accepted_divergences.yaml` — AD-019 + AD-003 array cases.
- `.dev/debt.yaml` — D-287 discharge + a NEW Phase-16 packed-byte-array
  deferral row.
- `test/e2e/` + `src/lang/diff_test.zig` — array cases (incl. AD pins).
