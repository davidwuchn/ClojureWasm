# ADR-0131 — In-VM call-frame stack: flatten `op_call` host recursion

- **Status**: Proposed → Accepted
- **Date**: 2026-06-11
- **Phase**: §9.2.S perf-parity campaign (cljw-vs-Python)
- **Supersedes / relates**: builds on ADR-0130 (O-015 frame-rooting),
  ADR-0091/0095 (GC EvalFrame A1), ADR-0119 (trace), ADR-0129 (consult-env),
  ADR-0060/0071 (VM try/catch handler stack), ADR-0036 (dual-backend parity),
  ADR-0005 (differential oracle). v0 reference: `ClojureWasm/src/engine/vm/vm.zig`.

## Context

The perf-parity campaign (handover; F-002 finished-form wins; not ROI-gated)
needs cljw to beat Python on `fib_recursive` (2.4×) and `nested_update` (3.1×) —
both **call-bound**. After O-014 (arith intrinsics) and O-015 (exact-count frame
rooting), the residue is the call path itself.

**Two pieces of evidence settle the lever (this cycle):**

1. **Design 2 measured null.** A monomorphic `op_call` fast path that bypassed
   `vt.callFn` + the `treeWalkCall` switch + `callFunction` + `vt.evalChunk`
   (the 2 vtable hops + the choke switch), keeping consult-env/trace/bind inline
   and calling `eval` directly, moved fib_recursive 57→56 ms / tak 18 ms —
   **no measurable win** (10-run ReleaseSafe). It was reverted as an
   excessive-skeleton; only the `bindCallFrame` extraction was kept (`ab1959c2`).

2. **`sample` profile of `(fib 35)`** (ReleaseSafe): 100% of samples are a single
   **5-host-frame recursion cycle** that nests a real C frame per Clojure call
   (indentation grows unbounded). **No GC / alloc / collect heavy leaf** (fib is
   fixnum-only). The pass-through hops Design 2 removed were already
   tail-call-collapsed by the optimizer; the irreducible cost is the **non-tail
   `eval` re-entry** — op_call must resume after the callee returns, so it cannot
   be a tail call, and is a genuine recursive host frame per call. Design 2 kept
   that frame; only flattening the recursion removes it.

The conclusion matches v0's proven design: v0 dispatches a call **in-place on a
flat in-VM frame stack**, staying inside one `run()` loop (fib 16 ms, beats
Python). cw v1's per-call `vm.eval` host re-entry is the structural tax.

Full survey: `private/notes/9.2.S-flat-frame-survey.md` (+ its EMPIRICAL UPDATE).

## Decision

Replace `vm.eval`'s **one-host-frame-per-call** activation model with an
**explicit in-VM call-frame stack** iterated by a single `eval` loop. A
monomorphic bytecode-`.fn_val` `op_call` **pushes a frame and continues the
same loop**; `op_ret` **pops the frame and continues**; only the top-level
boundary returns a host value. Everything not in the fast set (builtins,
multi_fn, protocol_fn, coll/keyword/var-as-IFn, IFn-instance, **TreeWalk-kind
fns**) keeps routing through `vt.callFn → treeWalkCall` — a host call out,
preserving the F-012 dual-backend oracle seam (the mandated DIVERGENCE from v0,
which has no such seam).

### Operand/locals model — DECIDED: Alt A (preserve v1's split, base-window both)

**Key correction from the Devil's-advocate fork: v1 ≠ v0 on the activation
record.** v0 unifies locals INTO the operand stack (`locals = stack[base+slot]`,
one array, one root slice). **v1 keeps them SEPARATE** — `locals: []Value` is
caller-owned (a `[256]Value` allocated in `callMethodImpl`) and the operand
`stack` is a distinct `eval`-local (`vm.zig:85-99`). That split is **deliberate
v1 architecture, not incidental**: it is the seam that lets `bindCallFrame` be
the ONE source shared by TreeWalk (which has NO operand stack, only locals) and
the VM (F-011 one-source, just landed `ab1959c2`).

Therefore the finished form is **Alt A, not v0's unification (Alt B)**: keep the
locals/operand split, base-window BOTH into shared arenas —
`stack[0..global_sp]` (operands) + `locals[0..global_loc_high]` (call-frame
slots), each frame addressing its window via an operand `base` and a `loc_base`.
`bindCallFrame` is reused **as-written** — point it at a sub-window of the shared
`locals` arena instead of a private `[256]Value`. Alt B (full v0 unification)
was REJECTED because it would FORK `bindCallFrame` (VM in-place splice vs
TreeWalk private array), regressing the F-011 one-source property; v1's split is
its finished form. The shared arenas are O(depth) base markers — the per-frame
memory worry the first draft raised is moot, and so is v0's "one slice" claim
(Alt A roots two slices, strictly simpler than today's N-chain, see GC below).

### Per-frame state (the `CallFrame` struct)

Each frame owns the state that is `eval`-local today: `ip`, `chunk`, operand
`base` + `loc_base` (windows into the shared arenas), `fs` (its locals window
width), the **handler-stack base** (try/catch), the **consult-env restore**
value (ADR-0129), and the **trace-pushed flag** (ADR-0119). `op_ret` restores
consult-env + pops the trace frame from the frame record, not from a Zig `defer`.

**No `saved_ns` slot** (DA prerequisite a): unlike v0's D68, **v1 does NOT switch
`current_ns` on a fn call** — `Function.defining_ns` is read ONLY by `calleeFrame`
to build the trace frame, never to rebind ns at runtime (the only `current_ns`
writes are in `in-ns`/`ns`/binding-frame ops). Reserving a per-frame `saved_ns`
would be the Reservation-as-bias smell (rooting a save/restore for state that
never changes per call). It is deliberately absent.

`loc_stack` (ADR-0118, the parallel `[256]SourceLocation`) is windowed with the
operand stack — same `base`, same `global_sp` — so `op_call`'s
`swapArgSources(loc_stack[…])` reads the right window (DA prerequisite c).

### GC root reshape (A1 — F-006)

Today: one `EvalFrame` per `vm.eval`, chained by the host recursion, each rooting
`stack[0..sp]` + `locals` + `constants`. The flat model (Alt A) publishes **ONE
`EvalFrame` per `eval` invocation** rooting the whole shared `stack[0..global_sp]`
+ the whole shared `locals[0..global_loc_high]` + **each active frame's
`chunk.constants`** (a small per-frame list). This is **two big Value slices + a
constants list — strictly simpler than today's N×2-slice chain**, not v0's single
slice (the split is preserved). Every below-`sp` operand slot is written only by
pushes; every locals slot is nil-init'd by `bindCallFrame` (O-015) on frame push;
a frame reads ONLY its own `[base..sp]` / `[loc_base..loc_base+fs]` window, never
a sibling's — so the shared arenas are safe under the existing nil-valid
invariant. `gc_rooting.md §A` row A1 + `root_set.EvalFrame` get a coordinated
edit.

**The torture lock must ALLOCATE per frame (DA prerequisite d — the sharpest
F-006 point).** fib is fixnum-only (zero allocation — the profile confirms no GC
leaf), so fib under `CLJW_GC_TORTURE` proves NOTHING about rooting. The locking
e2e MUST be a **deep recursion that allocates per frame** (e.g. builds a
list/map per level) so a missed root surfaces as a deterministic UAF. This is
the gate before trust (the O-005 UAF class lives here).

### Exception unwinding — a `while` loop around the existing catch (not a new subsystem)

DA correction: this is **cheaper than the first draft billed**. The existing
`eval` catch block (`vm.zig:152-207`) already does handler-stack unwind +
cleanup-vs-catch (ADR-0071) + catalog→exception synth (ADR-0060). Flat: on a
throw with no live handler in the top in-VM frame, **pop the frame** (restore its
consult-env + trace; no ns — see above), decrement `frame_count`, retry the
handler check against the new top frame — a `while` loop around the existing
logic. The `handlers[]` stay one array per `eval` invocation with a per-frame
`handler_base`, so "pop frames until a live handler" is "scan down past each
frame's base."

**Reentry-boundary handler scoping (DA prerequisite b — the highest parity
risk).** The ~30 reentrant `vt.callFn` callers (reduce / apply / lazy-seq force /
sort comparator / multimethod dispatch-fn / watchers / print-method …) re-enter
via `vt.callFn → treeWalkCall → callMethodImpl → evalChunk → eval`, each starting
a **fresh nested `eval` with its OWN frame array + OWN `handlers[]`**. Because
handler stacks stay **per-`eval`-invocation** (NOT promoted to a process-global
stack), a throw inside a reduce step-fn unwinds only the inner `eval`'s frames and
re-propagates the Zig error to the reduce caller — it CANNOT be caught by a
handler the outer `eval` established. This scopes handlers across reentry for
free (v0 needs `call_target_frame` only because it has nested `executeUntil`
loops; v1's per-invocation handler array avoids that). **Lock with a diff/e2e
case: "throw inside a reduce step-fn caught by an OUTER `try`."**

### Deep recursion: SIGSEGV → catchable StackOverflow (behaviour improvement)

Deep cljw recursion currently overflows the host C stack (SIGSEGV, uncatchable).
The flat model grows the in-VM frame array to a cap, then raises a **catchable
`StackOverflow`** — matching v0 (`vm.zig:1611`) and clj (`StackOverflowError`).
A new `error_catalog` Code + a frame cap. A diff/e2e case locks it.

### The shared arena lives in a per-thread `VmArena` (as landed in 2a)

The "shared base-windowed arena" cannot be a per-`eval` host-stack array: deep
recursion needs the arena to hold thousands of frames (a fixed host-stack array
big enough would blow the C stack, and nested reentrant `eval`s would multiply
it). v0 resolves this with ONE VM stack reused across calls. cw v1 adopts the
same as a **threadlocal `VmArena`** — but with **inline arrays (static BSS,
demand-paged), NOT a lazy heap alloc**: a never-freed heap arena leaks under the
test `DebugAllocator`, whereas static storage has nothing to free.
`ARENA_SLOTS = 16384` keeps the global watermark `op_top` within `u16`, so
`root_set.EvalFrame.sp` is unchanged (no blast radius to the other GC producers).
Each `eval` borrows from `op_top` (restored on return; nested reentrant evals
stack above); the A1 `EvalFrame` roots `stack[0..op_top]`.

### Implementation is incremental (green, gated increments)

1. **2a — operand arena (LANDED `a12fdb09`, O-016)**: the operand stack + its
   parallel loc stack moved off the per-`eval` host C stack into the threadlocal
   `VmArena`; locals stay caller-passed; one frame per eval (host recursion
   retained). The A1 `EvalFrame` points into the arena. Planned behaviour-identical
   — turned out a **real ~25% win** (fib 56→41 ms, tak 18→15) from the reused warm
   arena vs cold fresh host arrays. The key invariant: during `op_call`'s
   `vt.callFn` the deferred `sp` write-back leaves `op_top` at the PRE-step
   high-water, so the callee's args stay rooted AND the nested eval borrows above
   them — NO publish-before-nest (the initial 4-site plan was wrong, would UAF the
   args). Verified under the allocating `frame_local_alloc` torture gate.
2. **2b — the flatten**: a `frames` array of `CallFrame`; `op_call` (callee
   `.fn_val` + bytecode method + `!has_rest` + `!chunk.has_handlers` + frame cap)
   binds the callee's locals into a NEW `VmArena.local_arena` window via
   `bindCallFrame` + pushes a `CallFrame` + continues the loop; `op_ret` pops.
   **GC: each `CallFrame` carries its OWN inline `root_set.EvalFrame`** pushed on
   the existing chain at flatten / popped at ret — so the collector's existing
   chain-walk roots every active frame's locals + constants with NO `root_set`
   change (it cannot hold a vm-type `CallFrame` — zone rule). Bounded throw-unwind
   (flattened frames are handler-free, so the handler stack is invariant across
   them → pop flattened frames then run the base frame's catch). Deep recursion →
   catchable `StackOverflow` at the frame cap. Slow cases keep `vt.callFn`. Gate +
   allocating-torture + diff + the reduce-throw-outer-try case + deep-recursion +
   cross-lang bench. (`op_call` must NOT pop the args before the eval loop binds
   them — args stay rooted via `op_top` until `bindCallFrame` copies them.)
   Full spec: `private/notes/9.2.S-flat-frame-survey.md § CONVERGED 2b FLATTEN`.

Each increment is its own revert-friendly commit with an O-NNN row
(`.dev/optimizations.md`) + a clj corpus line (F-011).

## Consequences

- **AS-LANDED FINDING (2b, 2026-06-11): the flatten is perf-NEUTRAL.** The
  hypothesis that the host-recursion was the fib/tak tax was WRONG. A `sample`
  re-profile of `(fib 35)` after 2b shows the 5-host-frame cycle COLLAPSED (the
  flatten fires; fib runs in one eval loop) yet fib stays 39-41 ms / tak 15 ms.
  Both Design 2 (kept recursion) and 2b (removed it) measured neutral → the real
  tax is **per-instruction DISPATCH** (`stepOnce` called per op + its sp/ip
  read+write-back + the 3 per-op eval-loop polls; ~0.3 ns/op vs v0 ~0.1). The
  next campaign lever is dispatch efficiency (inline `stepOnce`, batch the polls
  v0-style every N ops, then computed-goto / superinstructions — D-NNN), NOT the
  frame model. See `private/notes/9.2.S-flat-frame-survey.md § 2b LANDED`.
- **Positive (what 2b DOES deliver)**: fixes the latent deep-recursion **SIGSEGV**
  — a deep non-tail recursion that crashed at ~1300 host frames now runs to the
  2048 frame cap then raises a bounded `stack_overflow` (deep1500 ✓, deep5000 →
  clean error). It is v0's finished form (F-002) and keeps the dual-backend oracle
  seam for all non-fast tags. (The `stack_overflow` is uncatchable for now —
  `resource_exhausted` kind; a follow-up maps it to a catchable StackOverflowError
  for full clj parity.)
- **Negative / risk**: the hottest, most-tested loop is rewritten for a
  perf-neutral result. GC rooting (each flattened frame's own `EvalFrame` on the
  chain) is UAF-critical — mitigated by the allocating `frame_local_alloc`
  `CLJW_GC_TORTURE` gate, the full diff oracle, the reduce-throw-outer-try parity
  case, and the deep-recursion repro. Kept (not reverted like Design 2) because it
  is a real bug fix + the finished form, not dead weight.
- **Dual-backend (F-012)**: no new opcode (reuses `op_call`/`op_ret`); the
  parity surface is "same Value out", covered by the diff corpus + targeted
  recursion cases. TreeWalk keeps its host recursion (it has no VM).
- **Zone**: all in `eval/backend/vm.zig` + `runtime/gc/root_set.zig` (Layer 0
  EvalFrame shape). No upward import.

## Affected files

- `src/eval/backend/vm.zig` — `eval` loop, frame struct/array, `op_call`,
  `op_ret`, handler unwind, error annotation reads top frame.
- `src/runtime/gc/root_set.zig` — `EvalFrame` shape (shared-stack + per-frame
  constants list) if the A1 reshape needs it.
- `src/runtime/error/catalog.zig` — `StackOverflow` Code.
- `.dev/gc_rooting.md` §A row A1 — root-shape edit.
- `src/lang/diff_test.zig` + `test/diff/clj_corpus/` — recursion parity cases.
- `.dev/optimizations.md` (O-016/O-017 rows), `.dev/debt.yaml` (if a sub-risk
  defers).

## Alternatives considered

Devil's-advocate subagent output (fresh context, mandatory at depth ≥ 2 per
CLAUDE.md § ADR-level designs are handled inline), reflected verbatim. Its
findings drove the Decision above: Alt A over Alt B (preserve v1's locals/operand
split = the F-011 `bindCallFrame` seam), drop the phantom `saved_ns`, per-`eval`
handler stacks for free reentry scoping, window `loc_stack`, and the
allocating-torture-not-fib F-006 lock. The recommendation (Alt B) is NOT binding;
the main loop chose Alt A on the explicit judgement the DA flagged — v1's split
is essential v1 architecture, not v0 inheritance, so v1's finished form preserves
it (and keeps `bindCallFrame` single-source, which Alt B would fork).

---

### Reframing: v1 ≠ v0 on the locals/operand split

v0 unifies locals into the operand stack (`stack[base+slot]`, one array, one root
slice, `shiftStackRight` splice). v1 keeps `locals: []Value` (caller-owned, passed
into `eval`) SEPARATE from the operand `stack` (`eval`-local). The first ADR draft
conflated two decisions: (1) do operand stacks share one base-windowed array? and
(2) do locals merge into it (v0) or stay separate (v1)? The memory argument + the
"one slice" A1 claim only hold for full v0 unification; the reuse of `bindCallFrame`
(targets a private `[256]Value`) points the other way. The ADR must pick one — and
the choice is load-bearing for F-006.

### Alt A — SMALLEST-DIFF / arguably v1's finished form: flat frames, locals stay per-frame & separate ("two stacks, base-windowed each")

Keep v1's split: shared operand `stack` (base-windowed) + shared `locals` arena
(frame i at `locals[loc_base_i .. +fs_i]`). `op_call` monomorphic bytecode
`.fn_val`: selectMethod → `bindCallFrame` writes the callee window into shared
`locals` at the new `loc_base` → push `CallFrame{ip, chunk, operand_base, loc_base,
fs, handler_base, consult_restore, trace_pushed}` → continue. `op_ret` pops, drops
operand `sp` to caller window, pushes result. A1: root `stack[0..global_sp]` +
`locals[0..global_loc_high]` + per-frame `constants`. **Better:** reuses
`bindCallFrame` exactly as written; minimal change; smallest F-012 surface (opcodes
keep operand/locals distinct); `op_make_fn`'s `locals[0..slot_base]` snapshot
keeps working. **Breaks:** two base markers/frame; two caps (operand + locals)
with two `StackOverflow`s; not v0's unified form — but the split is *v1's*
finished form (it anchors the dual-backend `bindCallFrame` seam), so this may be
cleaner than v0 for v1. The memory worry is moot (one shared `locals` arena =
O(depth) bases).

### Alt B — FINISHED-FORM-CLEAN (v0 model): fully unify locals into the operand stack, single root slice

Delete the separate `locals` param; locals become `stack[base+slot]`.
`bindCallFrame` rewritten to splice in-place on the operand stack (v0
`shiftStackRight`). `op_load_local slot` → `stack[base+slot]`; `op_make_fn`
snapshots `stack[base..base+slot_base]`. A1 collapses to v0's one slice
`stack[0..global_sp]` + per-frame `constants`; `EvalFrame` loses `locals`.
**Better:** the genuinely clean finished form; the ONLY shape delivering "one root
slice"; F-006 maximally simple (one array, one nil-valid invariant, no separate
locals tail to under-root — the O-005 class). Matches v0's 16ms structure.
**Breaks:** large blast on the SHARED binder — `bindCallFrame` is shared with
TreeWalk (which wants a private locals array, no operand stack). Unifying forks
VM vs TreeWalk binding, breaking the F-011 one-source property just bought
(`ab1959c2`). You'd thread `dest:[]Value, dest_base` through both, but in-place
`shiftStackRight` for rest/closure differs from "memcpy into a fresh frame", so
unification is partial. F-002 says pay it — but the ADR must own that
`bindCallFrame`'s signature changes and re-verify TreeWalk parity.

### Alt C — WILDCARD: keep Zig-error threading; flatten frame allocation, not control flow

Keep `op_call` pushing a frame into the same loop (host recursion gone for the
normal path) but keep Zig `error.ThrownValue`/`RecurSignaled` for exceptional
paths. On a throw, the single loop's existing catch (`vm.zig:152-207`) walks the
IN-VM frame array popping frames until one has a live handler — a `while` around
the existing logic, no new mechanism. **Better:** shows "frame-aware unwind" is
mostly already there (the catch block already unwinds one frame's handler stack);
the single-loop design AVOIDS v0's `call_target_frame` cross-bridge handler
leak (`vm.zig:372-373`) because there is one catch site. **Breaks/risk:** the ~30
reentrant `vt.callFn` callers (reduce/apply/lazy/sort/multimethod/watchers/print)
still re-enter `eval` → a nested host loop with its own frame array, so the
handler-scoping-at-reentry-boundary issue returns (v0's `call_target_frame`
problem). Contribution: the exception part is cheaper than billed; the subtle part
is the reentry boundary, which the ADR was silent on.

### Verdict (a): shared base-windowed vs per-frame-array — F-006

The shared stack is cleaner **only in Alt B's full unification** (one slice, one
invariant). The first draft's rejection of per-frame arrays "on memory grounds" is
a size argument dressed as correctness (a smell); the correctness fact is that
per-frame arrays = today's chained `EvalFrame` model (N slices), which already
works under torture — not unsafe, just N roots. In the draft's AMBIGUOUS half-state
(operands shared, locals separate-but-also-shared) F-006 is actively MORE dangerous
than per-frame arrays: the nil-init invariant spans a shared mutable array where one
frame's stale operands sit below another's base (the O-005 tail-slot class becomes
globally-coupled instead of per-call-isolated). **Recommendation: commit to Alt B's
full unification (one array/slice/invariant) or you get the worst of both; do not
ship the half-state.** Lead the rationale with rooting-simplicity, not memory.

### Verdict (b): is frame-aware exception unwind necessary?

Necessary, but the draft OVER-rates difficulty ("on par with the GC reshape").
It's a `while` loop around the existing catch (Alt C): pop frame, restore
consult-env + trace (NOT ns — v1 doesn't switch ns per call), retry handler check.
Handlers stay one shared array with per-frame `handler_base`. The genuinely-hard
part is the REENTRY BOUNDARY (a throw must not escape a `callFunction` re-entry to
be caught by the outer eval) — naturally solved IF handlers stay
per-`eval`-invocation (NOT a process-global stack). The ADR should (i) downgrade
the difficulty, (ii) reuse the existing catch, (iii) add the reentry-boundary
design + a "throw inside reduce caught by outer try" diff case (the single most
likely parity bug).

### Prerequisites the ADR ASSUMED but the code does NOT support

- **(a) MAJOR — no per-call ns switch.** v1 does NOT write `current_ns` on a fn
  call (grep: only `in-ns`/`ns`/binding-frame ops do). `Function.defining_ns` is
  read only by `calleeFrame` (`tree_walk.zig:1100-1101`) for the trace frame. The
  per-frame `saved_ns` slot the draft reserved (copied from v0 D68) is a PHANTOM —
  Reservation-as-bias. Drop it (or note the v1/v0 divergence explicitly).
- **(b) MAJOR — ~30 reentrant `vt.callFn` callers + handler scoping.**
  reduce/apply/lazy-seq force (`lazy_seq.zig:113`)/sort (`sorted.zig:99`)/
  multimethod (`multimethod.zig:329`)/watchers (`iref.zig:44`,`agent.zig:296`)/
  print (`print.zig:152`). Each re-enters → a fresh nested `eval` + frame array.
  State explicitly: handler stacks remain per-`eval`-invocation so reentry scopes
  handlers for free; add the reduce-throw-outer-try diff case.
- **(c) MODERATE — `loc_stack` must be windowed too** (`vm.zig:99`, parallel to
  operands; `op_call`'s `swapArgSources(loc_stack[sp+1..])` needs the right
  window). Name it in increment-1.
- **(d) MODERATE→SHARPEST for F-006 — the torture e2e must ALLOCATE per frame.**
  fib is fixnum-only (zero alloc; the profile confirms no GC leaf), so fib under
  `CLJW_GC_TORTURE` proves nothing about rooting. The locking e2e MUST be an
  allocating deep recursion (build a list/map per level) or torture is green for
  the wrong reason. (Good: increment-1 `frame_count==1` already exercises the new
  A1 shape under torture before flattening; multi-frame torture coverage arrives
  at increment-2.)

### Summary recommendation (non-binding)

Direction right, evidence solid. (1) Pick Alt B (full unification, one root slice)
per F-002 — but own that `bindCallFrame`'s signature changes and re-verify F-011.
Do NOT ship the ambiguous half-state. (2) Drop the phantom `saved_ns`. (3) Add the
reentry-boundary handler-scoping design + the reduce-throw-outer-try diff case
(highest parity risk). (4) Downgrade the exception-unwind difficulty. (5) Make the
torture e2e an ALLOCATING deep recursion, not fib. Closing judgement the main loop
must make consciously: whether v1's locals/operand split is essential architecture
(→ Alt A is v1's finished form) or incidental (→ Alt B's v0 unification). F-002's
"finished form wins" does not automatically mean "v0's finished form wins" — v1's
dual-backend architecture is a deliberate divergence from v0.

---

**Main-loop decision on the DA's closing judgement.** The split IS essential v1
architecture: it is the single seam that keeps `bindCallFrame` one-source across
TreeWalk (no operand stack) and the VM. Alt B forks that binder — a direct
regression of `ab1959c2` and the F-011 property. Therefore **Alt A is v1's
finished form** (chosen above), with the DA's prerequisite corrections (a)–(d) all
folded into the Decision. The DA's F-006 warning about the "ambiguous half-state"
is answered by Alt A's explicit base-windowing discipline: a frame reads only its
own `[base..sp]` / `[loc_base..loc_base+fs]` window (never a sibling's), and
`bindCallFrame` nil-inits each locals window on push (O-015) — so the shared
arenas carry the SAME nil-valid invariant as today, walked as 2 big slices instead
of an N-chain (simpler, not more dangerous). Verdict (a)'s "worst of both" only
applies to an UN-disciplined half-state; Alt A is the disciplined one.
