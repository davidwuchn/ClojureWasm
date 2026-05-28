# 0047 — VM peephole optimizer architecture (Phase 13)

- **Status**: Accepted
- **Date**: 2026-05-28
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-13-entry, vm, optimizer, peephole, differential-oracle

## Context

ROADMAP master-table row 13 (Phase 13) = `peephole.zig`: five
canonical benchmarks within 110% of cw v0 24C.10. cljw needs a
post-compile optimizer over the VM `Instruction` stream that
preserves the ADR-0005 differential oracle (TreeWalk ≡ VM Value).

Phase 17's `super_instruction.zig` (100% target) is a **separate**
pass — instruction *fusion* (combining ops into new fused opcodes)
is Phase 17, NOT peephole. cw v0's so-called "peephole"
(`src/engine/compiler/compiler.zig:1387-1600`) was entirely fusion
(`add_locals` / compare-and-branch); only its jump-target-collection
+ IP-remap *machinery* is reusable here, not its fusion patterns.

Step 0.6 (re-laying against finished-form) found that the Step 0
survey's recommended first rule — `op_jump +0` elision — is a
**phantom**: cljw's codegen never emits a jump-to-next. `compileIf`
always emits an else branch (`op_const nil` when none) so its
forward jump skips ≥1 instruction; `compileTry` always has the
re-raise `op_throw` between the last catch clause's end-jump and
`end:`, so that jump is offset ≥1 too. An `op_jump +0` rule would
remove nothing from real programs. The actually-demonstrable
redundancy is **`compileDo`'s `<form>; op_pop` after every
non-final form** (`compiler.zig:170-172`): `(do 1 2)` compiles to
`op_const c1; op_pop; op_const c2`, and the pure-push-then-discard
pair `op_const c1; op_pop` is removable.

## Decision

1. **File**: `src/eval/backend/vm/peephole.zig` — sibling to
   `compiler.zig` / `opcode.zig`, Layer-1 (`eval/`), imports only
   `opcode.zig`. No `optimize/` subdirectory yet (a one-file dir
   is premature reservation; promote to `optimize/` when Phase 17's
   `super_instruction.zig` joins it).

2. **Runs inside `compiler.compile`** (last step, in/before
   `finalize()`), and **recurses into fn sub-chunks**
   (`compileFnMethodBody` produces a `*BytecodeChunk` per method —
   hot loops live in fn bodies, e.g. `fib_recursive` / `arith_loop`).
   Callers (`driver.zig`, `evaluator.compare`) get optimized
   bytecode transparently — no caller knows the optimizer exists.
   The Phase-12 serializer therefore caches the **optimized** chunk
   (correct: the cache's contract is "skip recompilation"; caching
   pre-optimization bytecode would defeat or invert the cache).

3. **Core primitive `applyPlan(keep_mask)`** — the load-bearing,
   reused IP-remap. Rules populate an arena-sized `[]bool keep`
   mask (sized to `instructions.len`, never cw v0's fixed-64K stack
   blob). `applyPlan` then: builds a prefix-sum `old→new` index map,
   compacts the instruction slice, and re-resolves the three
   position-referencing operands — `op_jump` / `op_jump_if_false` /
   `op_push_handler`, all signed-i16-offset-relative-to-next
   (`vm.zig:188-201,317`) — by mapping each old absolute target to
   its new index and recomputing the offset against the op's new
   position. Targets are resolved in old-index space first, then
   mapped, then re-differenced (order-independent — no in-place
   mutation while offsets are stale). `call_sites` / `libspecs` are
   operand-indexed side-tables, untouched by instruction removal.

   **Physical removal is the only honest optimization for cljw's
   current opcode set.** An index-stable `op_nop` null-out was
   rejected: a nop still costs a dispatch turn (`vm.zig` `ip += 1` +
   switch), so it optimizes nothing (permanent-no-op smell). No
   index-stable *real* optimization exists for the current ops, so
   the IP-remap is unavoidable; deferring it = deferring Phase 13.

4. **First rule: pure-push + `op_pop` elision** — a *pure push*
   immediately followed by `op_pop` is removable (net stack effect
   0, no side effect, no observable). Purity is an **exhaustive
   `Opcode.isPurePush()` switch** in `opcode.zig`, NOT a
   hand-maintained allowlist in `peephole.zig`: adding a new opcode
   forces a purity decision at compile time. This closes the real
   hazard — forgetting to add a pure op only loses optimization
   (safe), but mis-classifying a *non-pure* op as pure (e.g.
   `op_get_var`, which derefs a dynamic var and can throw) would
   silently drop a side effect and break ADR-0005. Phase 13's pure
   set is exactly `{ op_const, op_load_local }`.

5. **No `Rule` registry yet.** The first rule is a plain function
   (`markPurePushPop`). A one-entry data-driven rule registry is an
   excessive skeleton / reservation-as-bias (F-002) — the registry
   interface should emerge when rule 2 reveals what it actually
   needs, not be speculated on one rule.

6. **Correctness guards**: skip a removal if either removed index is
   a branch target (do not orphan an incoming edge). The ADR-0005
   differential oracle is the end-to-end check; Layer-1 unit tests
   assert the remapped instruction stream directly; Layer-3 `diff`
   cases exercise a removal followed by a downstream jump so the
   IP-remap is proven on a real `.clj` form.

This is NOT a new analyzer Node variant, so the ADR-0036 dual-
backend Node-arm contract adds no arms; the spirit (VM change keeps
parity + carries a diff case) is honoured via the Layer-3 cases.

## Alternatives considered (Devil's-advocate fork, fresh context, 2026-05-28)

Ground truth re-verified by the subagent: jump operands are i16
offsets relative to `ip`-after-jump; `call_sites`/`libspecs` are
operand-indexed (survive removal); `compileDo` emits `<form>;
op_pop`; `op_jump +0` is never emitted.

- **Alt 1 — smallest-diff**: sibling `peephole.zig`, one hardcoded
  rule, ad-hoc inline `removed_before[i]` remap, top-level chunk
  only. Better: minimal, one cycle, clears the demonstrable bar.
  Breaks: the IP-remap is written as a one-rule concern; rule 2
  re-opens and generalises it under pressure (skeleton *enlarges*
  the rewrite — F-002 risk); in-place mutation while offsets are
  stale is where an off-by-one ships and passes the loop/arith
  benches by luck.
- **Alt 2 — finished-form-clean (recommended envelope)**: build
  `applyPlan(keep_mask)` once as a reusable, differential-tested
  primitive; purity on the Opcode enum; recurse into fn sub-chunks;
  sibling file. Better: the dangerous part (offset re-resolution)
  is built and tested once and is exactly what Phase-17 fusion
  reuses. Breaks (self-critique): erecting a data-driven `Rule`
  registry on one rule is itself the excessive-skeleton smell — so
  the narrowed form keeps `applyPlan` as the only abstraction and
  writes the first rule as a plain function.
- **Alt 3 — wildcard**: land an identity-transform harness + the
  differential wrapper first, defer the real rule, let the 110%
  budget be met by the already-tight typed-struct VM. Better: zero
  cycle-1 correctness hazard. Breaks: an identity-only pass is the
  permanent-no-op smell unless paired with a real rule in the same
  Phase; the "index-stable real optimization" half is vapour (no
  such target in the current opcode set).
- Findings: **(a)** pure-push+op_pop is the right first rule (only
  one that demonstrably fires; op_jump+0 is dead); the real hazard
  is the purity classification → encode as `Opcode.isPurePush()`
  exhaustive switch, not a list. **(b)** physical removal + remap is
  the only honest option; op_nop null-out is fake (pays the dispatch
  turn). **(c)** recurse into fn sub-chunks in Phase 13 — the benches
  are fn bodies. **(d)** sibling `peephole.zig`, not a one-file
  `optimize/` dir (reservation-as-bias). **(e)** optimize-then-
  serialize is correct; the existing bytecode version field must
  document that its scope includes the peephole rule set, else a
  future rule change serves stale optimized caches (tracked D-103).
- DA recommendation (non-binding): Alt 2 narrowed by its own self-
  critique — `applyPlan` as the sole load-bearing primitive, purity
  on the enum, first rule as a plain function, recurse into fns,
  sibling file, optimize-then-serialize + D-103. Main loop adopted
  this.

## Consequences

- **Positive**: the IP-remap primitive is built and differential-
  tested once, reused by every future removal rule and by Phase-17
  fusion. Compile-time purity safety. The Phase-12 cache stores the
  true (optimized) compile output.
- **Negative**: the five current bench fixtures (arith_loop /
  fib_recursive / let_chain / list_build / quote_chain) rarely
  contain pure-push+op_pop pairs, so this rule shows little bench
  movement. Row 13.4 measures the five-canonical parity and files a
  debt row if a benchmark misses the 110% budget rather than
  blocking — the 110% budget is expected to hold largely because
  cljw's typed-struct VM is already tight.
- **Follow-up**: **D-103** — confirm/​document that the Phase-12
  bytecode-cache version field's scope includes the peephole rule
  set (a rule-set change must bump the version so stale optimized
  caches are rejected).

## References

- ROADMAP §9.15 (Phase 13 rows 13.3 / 13.4), §9 master table row 13
  (peephole, 110%) vs row 17 (`super_instruction.zig`, 100%)
- ADR-0005 (dual-backend differential oracle — the correctness gate)
- ADR-0036 (dual-backend parity contract)
- ADR-0034 (Phase-12 bytecode serializer — the cache that stores the
  optimized chunk)
- `.dev/structure_plan.md` (`eval/backend/` subtree — `optimize/` dir
  deferred to Phase 17)
- Step 0 survey: `private/notes/phase13-13.3-survey.md` (op_jump+0
  recommendation superseded by Step 0.6 per this ADR's Context)
- cw v0 prior art: `~/Documents/MyProducts/ClojureWasm/src/engine/compiler/compiler.zig:1387-1600` (fusion + 5-pass remap machinery)

## Revision history

- 2026-05-28: Status: Proposed -> Accepted (Phase 13 row 13.3
  entry; Devil's-advocate fork embedded in Alternatives considered).
