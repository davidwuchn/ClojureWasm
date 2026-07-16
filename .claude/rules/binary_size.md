---
paths:
  - "src/**/*.zig"
  - "build.zig"
  - "build.zig.zon"
---

# Binary-size awareness (ADR-0172 is the SSOT)

Auto-loaded when editing Zig source / the build. cljw's headline claim is
"one small static binary"; size is budgeted per component and gate-checked.
This rule carries the operational discipline + the measured lessons from the
2026-07-16 campaign (9.47 MB → 7.38 MB, −22%) so they are not re-derived.

## The mechanical guards (already wired — do not duplicate)

- **`size_claims` step** (full gate, `test/run_all.sh`): README's headline
  "<N> MB" must stay within 10% of the freshly built binary — a prose size
  claim can no longer rot (the 3.8-vs-9.5 MB incident class is closed).
- **Budget ceiling check** (same step, `scripts/binary_size_report.sh
  --check`): the built binary must stay under the ADR-0172 **derived
  ceiling** (`BUDGET_CEILING_BYTES` in the script, kept in sync with the
  ADR's budget table). A breach fails the gate: attribute with the report
  tool, then either land a lever or consciously amend the budget **in
  ADR-0172** (Revision history entry) — never silently.
- **Measurement tool**: `bash scripts/binary_size_report.sh [BIN]` — total +
  segment breakdown; on a `-Dprofile=true` build it prints top symbols for
  attribution.

## When your change plausibly adds size, check it

A change is size-relevant when it adds: a new `@embedFile`/generated blob, a
new comptime-instantiated generic family, a new std subsystem (crypto, http,
regex-class tables), a large `switch`/table, or a new dependency. For those:
measure before/after (`binary_size_report.sh`), and note the delta in the
commit message when it exceeds ~50 KB. Feature growth is legitimate
(F-013/F-014) — the budget exists to make it *conscious*, not to forbid it.

## Measured lessons (do not re-litigate; citations in ADR-0172/0173)

1. **Instantiation count predicts recoverable size — symbol size does NOT.**
   A huge single symbol that aggregates once-called inlined handlers is
   size-NEUTRAL to out-line (zwasm's 707 KB emitter: table-driven rewrite
   changed nothing). The real wins are ×N-duplicated bodies (zwasm's
   host-callback thunks: ~300 B × 3,840 → −1.08 MB collapsed to shared
   bridges + 23 B forwarders). Before proposing a size refactor, ask "how
   many call sites / comptime instantiations share this code?".
2. **Watch comptime cross-products.** `fn(T) × arg-kinds × arity × slot`
   families explode silently. Prefer a type-erased shared body + thin
   per-instantiation forwarders (`noinline` on the shared body) when the
   family exceeds a handful of instances. Known open case: std.sort
   comparator monomorphization ≈ 224 KB / 93 instances (ADR-0172 L6).
3. **Embedded assets compress ~4-5×** (bytecode blob, `.clj` text): flate
   `.raw` + exact `uncompressed_len` + decompress-on-demand into
   `rt.load_arena` is the established pattern (serialize.zig
   `flateCompress`/`flateDecompress`; two std pitfalls are documented on
   those fns — non-empty output buffer for Compress, REAL 32 KB window for
   Decompress).
4. **Safety is never traded for size.** ReleaseSafe stays the shipped config
   (ADR-0132); ReleaseSmall/hybrid rejections are recorded as ADR-0172
   L3/L4 — don't re-propose them without new facts.
5. **Startup claims need median-of-20 on a quiet machine.** Single-shot
   `CLJW_PROFILE_STARTUP` probes under load produced a phantom −32% once
   (corrected in ADR-0173). Size numbers are stable; time numbers are not.

## Cross-references

- `.dev/decisions/0172_binary_size_budget_and_ledger.md` — budget table +
  lever ledger + governance (the SSOT).
- `.dev/decisions/0173_envelope_v7_zero_copy_pool_flate.md` — the envelope
  v7 arc (pool / zero-copy / flate) with its measurement corrections.
- `.dev/debt.yaml` D-515 — the standing drain anchor.
- `docs/works/binary_size.md` — the public measured comparison.
