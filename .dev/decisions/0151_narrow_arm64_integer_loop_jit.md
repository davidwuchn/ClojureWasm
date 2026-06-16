# ADR-0151 — Narrow ARM64 integer-loop JIT (D-133), as a third backend

**Status**: Accepted (Proposed → Accepted same cycle, 2026-06-16; ADR-level
design handled inline per CLAUDE.md § ADR-level designs are handled inline).

**Supersedes / relates**: D-133 (the debt row this discharges the design for);
F-010 (interim goal M = Phase 15 + a "cw-v0-程度 JIT"); ADR-0145 (sequenced the
JIT last, after dispatch micro-opts); ADR-0148 (the fastest-script campaign);
ADR-0125 (eval-budget / back-edge poll the JIT must cooperate with); ADR-0090
(GC safe-point); F-004 / F-005 / F-006 / F-011 / F-012 (the envelope).

## Context

The 2026-06-16 measurement arc (private/notes/9.2.S-d386-flatten-path-orientation.md)
empirically **exhausted the non-JIT lever space** for the 5 open ADR-0148
fastest-script targets (destructure 1.05× / gc_large_heap 1.08× / gc_alloc_rate
1.15× / sieve 1.23× / json_parse 1.14×):

- Redundancy wins landed (O-048 single-scan `fastGet`, O-049 simple-key
  `eqConsult`): destructure 55→45.9 ms (−16.5%), gc_large_heap 33.5→32.0 ms.
- Micro-levers all **inert** (A/B, reverted): TLV-address caching, the per-call
  error-trace push (D-386 "lever (a)" — REFUTED, 0.2–0.8 ms), TailNode/ArrayMap
  memset-skip, the `gc.alloc` mutex.
- Auto-collect recycling **net-negative** (`CLJW_GC_TORTURE=N`: 42→59→131→510 ms
  as collect frequency rises — the STW mark-sweep cost exceeds the malloc
  savings).
- The **call-ABI fast-path ceiling measured ~3–4.5%** (A/B stripping both
  `treeWalkCall` current_env + trace-push), and that ceiling is unreachable
  (current_env is needed for ADR-0129 correctness; trace-push needs a risky
  lazy-rebuild). REFUTED as worthwhile.

So the remaining targets are dispatch / allocation bound, and the decisive lever
is to **stop interpreting the hot integer loop** — a JIT. ADR-0145's gate
("dispatch / alloc / call micro-opts exhausted") is now met. F-010 sanctions
exactly this: a narrow, cw-v0-程度 JIT (~700–1000 LOC, counter trigger, leaf
C-ABI, deopt-on-non-int), NOT a broad/optimizing JIT.

Step 0 survey (private/notes/9.2.S-d133-jit-survey.md) found the key enabler:
**cljw already ships the superinstruction opcodes cw v0's JIT consumed**
(O-017..O-022: `op_add/sub_{locals,local_const}`, `op_branch_{ne,ge,gt}_*`,
`op_recur_loop`). So D-133 is a pure codegen + trigger addition with **zero new
IR**.

## Decision

Add a **narrow ARM64 integer-loop JIT as a true third execution backend**
(the DA-fork's recommended Alt 2, chosen over the lighter draft per F-002), at a
new `src/eval/backend/jit/` subtree.

1. **Backend seam, not a VM escape hatch.** The JIT exposes a small backend
   surface symmetric with `tree_walk.zig` / `vm.zig` — `compileLoop` / `run` /
   `deoptToVM` only; the VM holds an opaque `JitCache` and never reaches into
   codegen internals. This keeps F-011 (no second mechanism bolted into VM
   dispatch) and F-012 (the JIT is a backend the oracle validates, like
   VM-vs-TreeWalk) structural rather than prose.
2. **Trigger.** A **named** back-edge counter co-located with the existing
   `op_recur_loop` arm (vm.zig) — NOT overloaded onto the GC-poll branch
   (Alt 1's coupling hazard). At threshold (~64) compile the loop body once into
   a per-VM single-slot `JitCache`.
3. **First milestone (smallest coherent slice).** Compile exactly a **pure-fixnum
   `loop`/`recur` accumulator loop** — fixnum add/sub + a fixnum comparison
   branch + recur, no `mul`, no calls, no allocation/collection mutation — so the
   JITted leaf allocates nothing. (fib = call-recursion, sieve = in-loop
   collection mutation; both are explicitly NOT first-milestone.)
4. **Codegen.** Raw u32 ARM64 emission into an mmap'd page; on Apple Silicon use
   `MAP_JIT` + `pthread_jit_write_protect_np` toggling + `sys_icache_invalidate`
   (via `@extern`; Zig 0.16 `std.posix.mmap` + `std.c.mprotect`). Leaf C-ABI
   `(stack_ptr, base, constants_ptr) -> {value, status}`, x0–x17 only, no frame.
5. **Typed deopt** (not a bare `status != 0`): an enum
   `{ ok, deopt_non_fixnum, deopt_overflow, deopt_safepoint }`. On a non-fixnum
   value (top16 != cljw's **0xFFFC** inline-fixnum tag, F-004) OR on i48
   arithmetic overflow (F-005 forbids cw-v0's silent wrap), the leaf bails
   allocation-free without mutating interpreter state and the VM runs the loop
   normally (and auto-promotes to BigInt on the overflow path). Cooperates with
   the ADR-0125 / ADR-0090 back-edge safe-point by capping native iterations or
   polling `gc_requested`.
6. **Oracle-wired day one (F-012).** Every JITted loop runs under the dual-backend
   diff harness against its TreeWalk form, asserting bit-identical NaN-boxed
   results AND identical deopt→VM→same-result, with a `--backend=jit` selector
   mirroring the existing VM/TreeWalk selection.

### Mandatory carry-overs (DA-fork, all shapes)

1. **Tag/payload constants come from cljw `value.zig` (F-004 `0xFFFC`), NEVER
   ported from cw v0's `0xFFF9`** — the F-011 trap hiding in "modeled on v0".
2. **Overflow-deopt MUST be proven against the VM's BigInt auto-promotion under
   the diff oracle + a corpus line** (anti-D-177 over-claim) — never listed as
   landed without the probe.
3. **The leaf's allocation-free property MUST be asserted, not assumed** — pair
   it with `CLJW_GC_TORTURE` so a stray alloc inside JITted code surfaces as a
   deterministic UAF, not silent rooting debt (F-006).

### Forward debt

Alt 3 (lower the hot leaf to a **zwasm-JITed Wasm function** — portable to the
edge-native deployment target, gap area II) is **recorded as forward debt**, not
adopted: it strains F-010's letter (not a v0-shaped native leaf), has a per-loop
build/instantiate latency floor a 64-iteration leaf may never amortize, and
mid-loop deopt across the Wasm boundary loses the allocation-free resumable
deopt. Re-open it when broad-JIT / edge-native work opens (a new debt row at that
time; the capability-matrix successor is D-443).

## Alternatives considered (Devil's-advocate fork, verbatim)

> Forked `general-purpose` subagent, fresh context, briefed with the proposed
> shape + the active F-NNN envelope. Output embedded verbatim per
> `.dev/principle.md` (Devil's-advocate mandatory at depth ≥ 2).

### Preface — leading F-NNN finding

There is no F-NNN that the finished-form-clean direction must violate. F-010
explicitly *blesses* a "cw-v0-程度 JIT (~700-1000 LOC, counter trigger, leaf
C-ABI, deopt-on-non-int)" as part of interim goal M. The draft sits squarely
inside that envelope. The real tension is **F-011** (no second mechanism
duplicating an existing one) and **F-012** (VM is production default; TreeWalk is
the differential oracle). The draft introduces a *third* execution path, which is
the sharpest F-NNN-adjacent risk to scrutinize — not a violation, but the thing
most likely to drift into one. All three alternatives below stay inside every
F-NNN.

A grounding correction the draft should absorb: the deopt mask `top16 != 0xFFFC`
is the **cljw F-004 tag** (correct) — but NOT cw v0's tag (`0xFFF9...` INT_TAG).
"Modeled on cw v0's jit.zig" must not copy v0's boxing constants; source them from
cljw's `value.zig`. This is an F-011 behavioural-equivalence trap hiding in the
word "modeled."

### (1) Smallest-diff — inline trigger, reuse the back-edge poll, no new subtree

Single `jit.zig` under `src/eval/backend/vm/`; hook at `op_recur_loop` (vm.zig:895)
+ reuse the existing back-edge poll (vm.zig:270) as the warmup counter; per-VM
single-slot `JitState` as cw v0.
- **Better**: reuses the already-paid back-edge branch (zero new cold-path cost),
  co-locates the trigger with the GC poll it must cooperate with, smallest oracle
  surface, defers the subtree decision.
- **Breaks**: couples the JIT trigger to the GC-poll branch semantics (a future
  GC-poll refactor silently moves the trigger — ADR-0125 coupling hazard); a lone
  `jit.zig` next to `vm.zig` reads as a VM helper not a peer backend, postponing
  the structural decision (Structural-imagination-deferral).
- **F-NNN**: compliant; tag-mask still cljw-native; GC-poll coupling is a risk not
  a violation.

### (2) Finished-form-clean — JIT as a true third backend behind a dispatch seam

`src/eval/backend/jit/` with a backend interface symmetric with tree_walk/vm
(`compileLoop` / `run` / `deopt-to-VM` only; VM holds an opaque `JitCache`).
Diff-oracle wired from the first commit (every JITted loop + its VM form run under
the dual-backend harness, bit-identical NaN-boxed results + deopt→VM→same-result),
`--backend=jit` selector. Typed deopt enum `{ ok, deopt_non_fixnum,
deopt_overflow, deopt_safepoint }` instead of bare `status != 0`.
- **Better**: serves F-002 + F-012 — the JIT is a backend the oracle validates the
  same way it validates VM-vs-TreeWalk, not a special-cased side path; the seam
  pre-exists for milestone 2-3 growth (no re-architecture). The typed-deopt result
  turns F-005's "deopt, don't wrap" from an honor-system comment into a testable
  invariant (overflow → `deopt_overflow` → VM auto-promotes → corpus line locks
  it, anti-D-177). Kills the F-011 "second mechanism" risk at the root.
- **Breaks**: substantially larger diff (seam + typed enum + oracle wiring +
  selector) vs "pure codegen+trigger, zero new IR"; some seam is speculative until
  backend #4 exists; risk of over-abstracting for two-and-a-half backends
  (Premature-generalization); the JIT is not *fully* a peer (it deopts to the VM
  mid-loop by construction — really a VM accelerator), so forced interface
  symmetry slightly misrepresents the dependency.
- **F-NNN**: fully compliant, most F-011/F-012-aligned. Per F-002 the larger diff
  is not a reason to downgrade.

### (3) Wildcard — lower the hot leaf loop to a zwasm-JITed function

At threshold, lower the detected fixnum leaf loop to a tiny Wasm function (i48
add/sub + compare + br_if + loop) and hand it to zwasm's existing JIT (F-001:
zwasm unavoidable; cw v0's tree even ships a zwasm with its own jit.zig). Deopt
becomes a guard inside the generated Wasm.
- **Better**: zero new arch-specific codegen / mmap / W^X / icache management;
  **portable to every target zwasm runs on, including the Wasm-edge-native
  deployment target** (gap area II — a native ARM64 JIT does nothing for a cljw
  running inside a Wasm sandbox at the edge); strongest F-011 story (reuses an
  existing mechanism — the JIT *is* zwasm).
- **Breaks**: **contradicts F-010's letter** ("a cw-v0-程度 JIT … native leaf
  modeled on v0") — F-010-spirit-compliant (it is *some* JIT for hot integer
  loops) but letter-divergent; flagged explicitly per the brief. It does NOT
  violate F-010 outright (F-010 describes the M milestone's JIT *shape*; a finished
  form could amend implementation-shape while keeping the M capability) but
  adopting it requires reading F-010 as capability-not-implementation — a
  deliberate stretch. Plus: build→instantiate→call latency floor a 64-iteration
  leaf may never amortize (v0's whole point was a *cheap* leaf compile); mid-loop
  deopt back into the cljw interpreter across the Wasm boundary is genuinely hard
  (cannot resume the interpreter at an arbitrary IP with live unboxed values) — you
  likely lose the allocation-free, state-non-mutating deopt.
- **F-NNN**: F-001/F-006/F-011/F-012 compliant, most portable; **F-010
  letter-divergent** (capability-compliant, implementation-shape-divergent). Not
  recommended as the milestone-M shape.

### Recommendation

**Adopt Alternative (2).** The draft is already F-010/F-006/F-005-compliant; the
gap is that its F-012 oracle integration and F-005 deopt guarantee are stated as
prose/comments, where the finished form makes them mechanical (typed deopt +
day-one diff-oracle wiring + a clean backend seam). That is the F-002
"finished-form cleanliness wins" call, and the larger diff is not a reason to
prefer the draft (cycle/LOC is not a constraint). NOT recommending the
smaller-diff Alt (1) on "one file, mirrors v0, smallest surface" grounds — that is
the Cycle-budget defer smell, and its GC-poll coupling postpones the structural
decision the ADR should settle. Take from Alt (1): the trigger co-locates with the
back-edge site but as an explicit *named* counter, not by overloading the GC-poll
branch. The wildcard (3) is the right long-horizon question for gap-area II
(edge-native) — record as forward debt, do not adopt now.

Mandatory carry-overs (any shape): (1) tag/payload constants from cljw `value.zig`
(F-004 `0xFFFC`), never ported from v0's `0xFFF9`; (2) overflow-deopt proven
against the VM's BigInt auto-promotion under the diff oracle + a corpus line; (3)
the leaf's allocation-free claim asserted via `CLJW_GC_TORTURE`, not assumed.

## Consequences

- A new `src/eval/backend/jit/` backend subtree + a `JitCache` slot on the VM + a
  named back-edge counter + a `--backend=jit` test selector. The compiler / IR is
  unchanged (zero new opcodes — the superinstruction family already exists).
- ARM64-only initially (the leaf codegen is arch-specific); on a non-aarch64 host
  the JIT is inert (the VM runs the loop) — no behaviour change, the diff oracle
  still validates VM≡TreeWalk there. (Portability is the wildcard's forward-debt
  domain.)
- The diff oracle gains a third participant; a JIT/VM divergence becomes a gate
  failure, so the JIT cannot silently diverge (F-012).
- Implementation is the next TDD unit (the arith_loop milestone), not this commit.
  This ADR locks the design + the DA analysis; the source lands against it.

## Affected files (at implementation time)

- `src/eval/backend/jit/` (new) — codegen + trigger + `JitCache` + deopt.
- `src/eval/backend/vm.zig` — named back-edge counter at the `op_recur_loop` arm;
  opaque `JitCache` hook; deopt return path.
- `src/runtime/value/value.zig` — (read-only) the F-004 `0xFFFC` tag/payload
  constants the codegen sources.
- the diff harness / `--backend=jit` selector + a corpus line for the
  overflow-deopt proof.
- `.dev/debt.yaml` D-133 (status), `.dev/structure_plan.md` (`jit/` subtree),
  `.dev/optimizations.md` (the O-NNN at landing).

## Revision history

- 2026-06-16 — Accepted. Design + Devil's-advocate fork (Alt 2 chosen per F-002)
  captured ahead of the arith_loop milestone implementation. Non-JIT lever space
  empirically exhausted (ADR-0148 arc); ADR-0145 JIT gate met.
