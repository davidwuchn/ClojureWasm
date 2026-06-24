# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; ≈ `e1940e50`). Per-commit = smoke; commit
  **and** push (CLAUDE.md § atomic Step 6). `build.zig.zon` `.zwasm` = tag pin
  `v2.0.0-alpha.3`.
- **First commit on resume MUST be**: open **D-510 — the general host-enum /
  singleton unification** (the big-design unit the user reserved for a clear
  context). It is depth-2 structural → draft **ADR-016x + a Devil's-advocate fork**
  (CLAUDE.md § ADR-level inline). The design question: the 4 host enums use TWO
  representations — RoundingMode/ChronoUnit/MathContext-DECIMAL* are `.host_instance`
  (state[0]=ordinal) + a toString method; DayOfWeek/Month are `.typed_instance` +
  the `TemporalPrint` enum-name arm + getValue. Unify into ONE mechanism (one
  `StaticFieldValue.host_enum` arm + a registry/per-enum name fn), reconciling the
  representations. Foundation is READY (3 host-singleton consumers live; the
  `.rounding_mode`/`.chrono_unit`/`.math_context` arm + `runtime/{…}.zig` +
  rt-slot-cache pattern is proven). Full detail + the scope finding: `.dev/debt.yaml`
  D-510. Start: oracle DayOfWeek/Month behaviour, then ADR+DA.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails —
  `zig_build_test_needs_dwasm`); bare `zig build` for a probe (ADR-0133 — ReleaseSafe).
  Reader-macro / syntax-quote NS-qualification stays `rt/` (AD-038/049).

## Last landed (git log = SSOT)

**clj-parity sweep arc, 2026-06-24 — full gate GREEN (392/0).** Complete BigDecimal
numeric surface (RoundingMode enum [ADR-0160] + compareTo/max/min/equals/pow/
remainder/divideToIntegralValue/intValue/longValue/doubleValue/divide-with-mode,
MathContext [+DECIMAL*], `(BigDecimal. str|int)` ctor); `java.time` ChronoUnit enum
+ `.until` across LocalDate/LocalDateTime/Instant; `java.math.BigInteger` instance
methods (abs/negate/signum/gcd/pow/mod/sqrt/modPow/bitLength/isProbablePrime);
`ns-unalias`. A session code-review (JVM-oracle-verified) found the new numeric/time
code correct. `.zig-cache` cleanup: ~39G local + 126G ubuntunote freed (user-asked).
The common clj-parity surface is mature (extensively probed: core/string/set/data/
walk/math/format/zip/edn/pprint/spec/test/contrib/transducers/destructuring/
protocols/state/reader all clean). Remaining gaps tracked: D-510/D-513.

## Standing units (tracked in .dev/debt.yaml)

- **D-510** — general host-enum/singleton unification (the next big-design unit; see
  Resume contract). **D-513** — clojure.core.reducers (needs cljw-native impl over
  the primitive reduce) / clojure.repl (blocked by) / the var `:doc`-metadata gap.

## North star (ACTIVE)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
The embedded **zwasm** JIT engine (ADR-0200) is the cljw DEFAULT (`.auto`); the
remaining north-star step is **components-through-the-JIT** (zwasm-side, D-500).
Live ledger: `.dev/zwasm_capabilities.md`.

## Cold-start reading order (resume)

handover → `.dev/debt.yaml` D-510 (the next unit's full scope) → memory
`clj_stdlib_contrib_sweep_campaign` + `.claude/rules/clj_diff_sweep.md` →
`private/notes/sweep-*.md` (this arc). memories `char_literal_e2e_oracle`,
`verify_actual_pattern_not_proxy`, `smoke_first_batch_full_gate`.

## Stopped — user requested

User instruction (2026-06-24): "D-514がniche も含め終わったら、クリアコンテキストで
始めたいため、明示的に配線・参照チェーンを監査し、大きな設計の要るやつを自律的に進め
られるような状態にし、ストップしてください". D-514 is DISCHARGED (BigInteger complete);
the session's new wiring/reference chains were audited clean (3 host-singleton
modules: singleton↔analyzer-resolver↔runtime-deinit + rt-slots + java_surfaces +
primitive.zig all matched; full gate 392/0 validated test-reach/zone). Resume by
opening D-510 per the Resume contract.
