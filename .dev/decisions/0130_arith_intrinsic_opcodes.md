# ADR-0130: Arithmetic / comparison intrinsic opcodes

Status: Proposed → Accepted (2026-06-11)
Deciders: autonomous loop (perf-parity campaign, user-directed)
Refs: F-002, F-004, F-005, F-006, F-011, F-013; ADR-0036 (dual-backend parity);
`.dev/perf_v0_baseline.md`; cw v0 `src/engine/compiler/compiler.zig` F95.

## Context

cljw compiles every call — including `(+ a b)` — as a generic `CallNode` →
`op_call <arity>` (compiler.zig:297): load the callee Var, load args, `op_call`,
which at runtime resolves the Var and dispatches the `BuiltinFn`. For hot
arithmetic (`fib`, `tak`, `arith_loop`) this per-operation var-resolve + dispatch
+ arg-slice is the dominant overhead. cw v0's "arithmetic intrinsics" (direct
opcodes for `+ - * < …`) drove `fib_recursive` 502→41 ms (12×); it is the **#1
lever** of the v0-parity perf campaign (`perf_v0_baseline.md`). v1 currently has
no arithmetic opcodes.

Key facts that shaped the decision (from a v1 source read + the Devil's-advocate
fork below):

- **Rebinding safety is already structural.** The analyzer resolves a call's
  head through `analyzeSymbol`; a lexical binding (`(let [+ str] …)`) yields a
  `.local_ref`, NOT a `.var_ref` to `clojure.core/+`. So the intrinsic gate is
  just "callee is `.var_ref` AND its `var_ptr` is the canonical `clojure.core`
  arith Var" — unfoolable by `let` shadowing, `:refer :rename`, or a user-ns
  `(def + …)` (different Var pointer).
- **The numeric tower already lives in `promote.zig`** (`addPromoting`,
  `subPromoting`, `mulPromoting`, each i64 `@addWithOverflow` → `wrapI64`, which
  produces inline-i48 / heap-Long / BigInt per F-005). The intrinsic dispatch
  calls these EXISTING functions — it does NOT reimplement arithmetic. So there
  is no second numeric implementation to drift from the builtin (F-011).
  `Value.initInteger` must NEVER be used to box a result (it overflows i48 →
  float; the i48..i63 window must become a heap-Long via `wrapI64`).

## Decision

Add a small set of **binary intrinsic opcodes** whose VM dispatch calls the
existing `promote.*` / comparison primitive directly, gated by canonical-Var
pointer identity. (Devil's-advocate Alternative 2, the finished-form-clean shape.)

1. **Opcodes (first cut):** `op_add`, `op_sub`, `op_mul` (→ `promote.addPromoting`
   / `subPromoting` / `mulPromoting`) and comparisons `op_lt`, `op_le`, `op_gt`,
   `op_ge` (→ the existing numeric comparison primitive). **Deferred:** `/`
   (integer `/` → Ratio / divide-by-zero, no fixnum fast path), `=` / `not=`
   (must match full `valueEqual` on the non-numeric tail — marginal win, real
   risk). They keep using `op_call`.
2. **Shared mechanism (both backends).** The dispatch body is a single
   `intrinsic.fastBinary(rt, op, a, b)` that delegates to the `promote.*` /
   comparison primitive. The VM `op_add` arm AND the TreeWalk call path both
   route an intrinsifiable 2-arg core-arith call through it, so parity is
   STRUCTURAL (one code path), not merely diff-tested — the direct F-011
   "commonization outranks effort" answer and the ADR-0036 drift-prevention.
3. **Compile-time recognition + folding** (compiler.zig `compileCall`): when the
   callee is a `.var_ref` whose `var_ptr` equals a Runtime-cached canonical core
   arith Var AND it is not deopted (point 5), fold by arity — `(+)`→`op_const 0`,
   `(+ x)`→`x`, `(+ a b)`→`op_add`, `(+ a b c …)`→left-folded chain of `op_add`
   (matches the builtin's left fold, incl. float non-associativity). Every
   intrinsic opcode is strictly binary (stack effect −1), so no runtime variadic
   loop exists — which also removes the O-005-class UAF risk (no runtime
   accumulator held across a promotion alloc).
4. **Var-pointer cache.** Runtime caches the canonical `clojure.core` Var
   pointers for the intrinsifiable names at bootstrap (new; rt has none today).
5. **Deopt on redefinition (the one F-011 hole the analyzer does NOT close).**
   `(alter-var-root #'clojure.core/+ …)` / a `(def +)` that re-roots the
   canonical Var mutates the same pointer → the gate would still fire. A
   `core_arith_pristine` flag (or per-Var `intrinsic_safe` bit) is cleared when a
   core arith Var is redefed/alter-var-root'd; the compiler gate consults it and
   falls through to `op_call`. (Already-compiled chunks that captured an
   intrinsic are a non-issue in the common case — bootstrap defines `+` once
   before user code; a stricter generation/epoch invalidation is a follow-up if
   a test needs it.)
6. **GC (F-006).** The non-overflow integer path allocates nothing → no
   safepoint, no rooting (the O-007 precedent). The overflow path allocs inside
   `wrapI64`; operands are read into the i64 op before the alloc, and compile-time
   variadic folding means no extra intermediate is held across it.

### Layer

Recognition + folding: `src/eval/backend/vm/compiler.zig` + a closed-set table
in a new `src/eval/backend/intrinsic.zig` (the F-013 structural defense: a gate
asserts the recognized Var set ⊆ the clojure.core numeric/comparison surface).
Dispatch: arms in `src/eval/backend/vm.zig`. Shared primitive: existing
`src/runtime/numeric/promote.zig` + the comparison primitive. TreeWalk consults
`intrinsic.fastBinary` in its call path.

## Alternatives considered (Devil's-advocate fork, fresh context)

**Alt 1 — smallest-diff:** pointer-identity Var gate + i64 fast path in each
opcode arm calling `wrapI64`; 2-arity only; non-fixnum defers to the builtin.
*Better:* most correctness-conservative (fallback re-invokes the same builtin).
*Breaks:* `(+ a b c)` un-intrinsified; the `alter-var-root` hole; TreeWalk gets
no speedup and parity is test-dependent, not structural.

**Alt 2 — finished-form-clean (CHOSEN):** unified `fastBinary` shared by both
backends + compile-time variadic fold + closed-set Var table. *Better:*
eliminates the dual-backend drift class entirely (one fast path); variadic /
0-1-arity solved at compile time; F-013 closed-set defense; no runtime-variadic
UAF risk. *Breaks/risks:* largest diff (F-002: not a constraint); touches the
TreeWalk oracle path (mitigated — `fastBinary` returns to the builtin for any
non-(fixnum,fixnum) case, so oracle values are provably unchanged); float
left-fold associativity must be locked by a diff case.

**Alt 3 — wildcard:** skip opcodes; do compare-branch (`op_lt_branch`) +
reduce-over-range fusion (v0 24A.3/24C.7/37.3) targeting `arith_loop`'s 34× hole
directly. *Better:* hits the measured worst regression; on-roadmap (Phase 17
`super_instruction.zig`). *Breaks:* doesn't deliver the fib/tak recursion win
(recursion ≠ counted loop); bigger seq-realization semantic surface; inverts the
baseline's stated lever order. **Sequenced as the NEXT unit after this ADR, not a
substitute.**

## Riskiest correctness traps (from the fork; each gets a diff/e2e lock)

1. `alter-var-root #'clojure.core/+` — the redef hole (point 5 deopt).
2. `/` excluded — integer `/` → Ratio / divide-by-zero arg-precise raise.
3. `=`/`not=` deferred — must match `valueEqual` (`(= 1 1.0)`→false, NaN, AD-001).
4. i48→i64 boxing — use `wrapI64`, never `initInteger`; diff case at
   `(+ 140737488355327 1)` (the i48 boundary → heap-Long, not float).
5. GC rooting only on the overflow/promotion path (non-overflow allocates none).
6. Float variadic left-fold associativity — diff case `(+ 0.1 0.2 0.3)`.

## Consequences

- fib/tak/arith hot paths skip var-resolve + BuiltinFn dispatch + arg-slice;
  expected fib win in the v0 12× class (arith_loop needs the Alt-3 fusion next
  for its full drop).
- One new module (`intrinsic.zig`) + a closed-set gate; new opcodes per
  ADR-0036 (compile arm + dispatch arm + TreeWalk parity + diff cases, same
  commit). Naive form (the builtin) remains the F-011 contract.
- Verified per cycle by a focused quick-bench + the differential oracle + the
  six trap diff cases; GC-torture on the dispatch arms (O-005/O-013 discipline).
