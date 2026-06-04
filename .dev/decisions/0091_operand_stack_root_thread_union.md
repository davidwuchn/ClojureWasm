# 0091 — Operand-stack GC root publication via a thread-roots union cursor (Phase B #3b-step1)

- **Status**: Proposed → Accepted
- **Date**: 2026-06-05
- **Author**: autonomous loop (Phase B #3b implementation, D-244)
- **Tags**: gc, concurrency, root-set, vm, phase-b
- **Supersedes-in-part**: ADR-0028 §5 root-source table rows 2 (`current_frame`)
  + 7 (`macro_root_slot`) — subsumed into a single `thread_roots` union source
  (ADR-0028 gains amendment 2 pointing here).
- **Implements**: ADR-0090 "D-244 decision" (Alt B) §3 — "Publication is a
  per-thread CHAIN of operand-stack frames"; D-244 barrier #3b.

## Context

Phase B #3a landed the worker-thread GC-root registry (`ThreadGcContext` +
`thread_registry`) and a UNION walk: the `current_frame` and `macro_root_slot`
cursors each iterate a per-thread dimension (source index 0 = the collecting
thread's TLS, k>=1 = registered worker k-1). That dimension was FOLDED into the
two existing cursors because a worker's binding frames + macro slot are the
SAME KIND of root as the self thread's.

#3b must root a genuinely NEW kind of state: the VM **operand stack**. `vm.eval`
(`src/eval/backend/vm.zig:79`) holds `stack: [256]Value` (only `stack[0..sp]`
valid — above `sp` is `undefined`) + `locals: []Value` (256, nil-initialized);
and it recurses (`op_call → treeWalkCall → callMethodImpl → evalChunkErased →
eval`), so each thread holds a CHAIN of operand-stack frames. Today these are
NOT rooted, which is safe ONLY because `collect()` is invoked exclusively from
tests at quiescent top-level points (grep-confirmed: zero live auto-collect;
`alloc` never calls `collect`). For #4 (real worker threads) a worker mid-`eval`
holds un-rooted operand Values → a concurrent collect sweeps them → UAF
(ADR-0090's leading finding).

The structural question this ADR resolves: **how is the operand-stack root
wired into the source-ordered `RootIterator`?** A mandatory Devil's-advocate
fork (depth ≥ 2, touches the ADR-0028 §5 root-source reservation table) reviewed
three shapes; its output is reflected verbatim below.

## Decision

Adopt the DA's **Alternative 2**: extract the per-thread union as a first-class
`thread_roots` `RootSource`, with the operand stack as its third sub-walk.

1. **`thread_roots` subsumes `current_frame` + `macro_root_slot`.** The
   `RootSource` enum drops both per-thread E-sources and gains one
   `thread_roots`; the enum count goes 10 → 9. One `threadContextAt(idx)` helper
   (idx 0 = self TLS, k>=1 = `thread_registry[k-1]`, `.end` past the cap)
   replaces the triplicated `frameSourceAt`/`macroSourceAt`/(would-be)
   `evalFrameSourceAt` addressing helpers — the F-011 commonization that
   shipping the operand stack as its own source (clean Option B / DA Alt 1)
   would have triplicated.
2. **The `thread_roots` cursor walks thread-major**: for each thread index, it
   walks that one thread's complete root contribution — binding-frame chain
   (each frame's `BindingMap` values) → macro slot → eval-frame chain (each
   `EvalFrame`'s `stack[0..sp.*]` + all `locals`) — then advances to the next
   thread. This mirrors the #3b-step2 safepoint's mental model 1:1 ("for each
   parked thread, mark its roots"), which a source-major scatter would not.
3. **Operand-stack publication**: `EvalFrame { stack, sp, locals, parent }` +
   `threadlocal var eval_frame_head: ?*EvalFrame` are declared in `root_set.zig`
   (Layer 0 — same home + downward-import pattern as `macro_root_slot`; the
   fields are raw `Value` pointers, no VM-type leak into Layer 0). `vm.eval`
   pushes its frame on entry + `defer`-pops on return. `ThreadGcContext` gains
   `eval_frame_slot: *const ?*EvalFrame`.
4. **Runtime-inert today (like #3a)**: with no live auto-collect + single
   thread, `collect()` runs only at quiescent points where `eval_frame_head ==
   null` (no `vm.eval` on the C stack) and the registry is empty → the
   `thread_roots` walk yields exactly today's `current_frame`+`macro` roots.
   The existing gate stays green by construction.
5. **Scope boundary**: this ADR is #3b-**step1** (publication infra, inert). The
   alloc-boundary **safepoint** + liveness back-edge poll + collecting-thread
   self-guard (#3b-step2) couple to #4 (force-VM worker thunks) and land later.

**Alt 3 (full thread-driven iterator spine, retiring `RootSource` as the
iteration driver) is recorded as the Phase-15/JIT-era re-conception candidate**,
not adopted now — it spends a large extra diff to neutralize the "how many
sources" question that Alt 2 already neutralizes, and sacrifices the
iterator-as-checklist property (every source accounted-for in `next()`).

This stays strictly inside F-006 (precise roots, STW-at-safepoint at #3b-step2,
no write barrier) and F-012 (backend-agnostic publication; tree_walk never runs
on a worker, so only VM workers publish an eval chain).

## Alternatives considered (Devil's-advocate fork, fresh context, 2026-06-05, verbatim)

Briefed with F-002 / F-003 / F-006 / F-011 / F-012 as hard constraints, grounded
in a direct read of `root_set.zig` (#3a registry + union walk), ADR-0028 §5,
ADR-0090's D-244 decision, `.dev/debt.yaml` D-244, and `vm.zig` `eval`.

### Framing the actual question

The narrow question is "Option A (fold into `current_frame` source #2) vs Option B (new 11th `RootSource`)". But the grounding makes a third axis visible that neither A nor B sit cleanly on: the just-landed `RootIterator` is **source-ordered with a per-thread sub-dimension grafted into two of its cursors** (`current_frame.src_idx`, `macro_root_slot.src_idx`). The operand-stack chain is a *third* per-thread source. So the real design tension is not "fold vs add an enum row" — it is **"how many places does the per-thread-union dimension want to live: 0, 2, or 3+ cursors, and is source-ordered iteration even the right spine once 3 of N sources are per-thread?"** I keep that axis in view throughout.

One load-bearing structural fact, verified against `root_set.zig` and the D-244 #3a barrier: the `ThreadGcContext` today is `{ frame_slot, macro_slot }` — two pointers into a worker's TLS. #3b's plan adds `eval_frame_slot` (a third). The registry, the union-addressing helpers (`frameSourceAt`/`macroSourceAt`), and the `src_idx` cursor pattern are **already a three-fold-repeated mechanism after #3b** (frame, macro, eval-frame), each re-deriving "index 0 = self TLS, k>=1 = registry[k-1], .end terminates". That repetition is the F-011 (DRY/commonization) signal that dominates my analysis.

### Alternative 1 — smallest-diff: new `.operand_stacks` source (Option B), no iterator re-shape

The smallest *correct* diff is **not** Option A — it is Option B done minimally. This is the inversion the brief should hear first.

**Shape.** Add `operand_stacks` as an 11th `RootSource` between `macro_root_slot` and `typed_instances` (or after `permanent_roots` — placement is free). Add an `OperandFrameCursor { src_idx, frame: ?*EvalFrame, slot_idx, primed }` to the `Cursor` union. Add `evalFrameSourceAt(idx)` mirroring `frameSourceAt`. Walk `stack[0..sp.*]` then all of `locals` per frame, then `frame.parent`, then advance `src_idx` to the next thread. Extend `ThreadGcContext` with `eval_frame_slot: *const ?*EvalFrame`. Declare `threadlocal var eval_frame_head` in `root_set.zig`. Amend the two tests (`"RootSource enum lists 10 sources"` → 11) and ADR-0028 §5 (add row 11, E-shape).

**Why "smallest-diff" and not Option A:** Option A (fold into `current_frame`) looks smaller (no enum change, no ADR-0028 amendment) but it is smaller *in the wrong ledger*. It saves a doc edit and a test-constant bump while **conflating two semantically distinct root kinds inside one cursor's state machine** — `CurrentFrameCursor` would have to carry both `frame: ?*BindingFrame` (a Clojure dynamic-binding concept) and `eval_frame: ?*EvalFrame` (a VM-backend concept), interleaving their drains. That conflation is itself a future "split this back out" rework (see §future-horizon). The diff Option A saves is doc-shaped; the debt it creates is code-shaped. By F-002's own ordering (finished-form > avoiding-rework > diff-size), Option A trades a clean-shape loss for a doc-edit saving — the wrong direction.

**Better than the others:** Each `RootSource` stays one root *kind*. Matches the existing precedent exactly — `current_frame=#2` and `macro_root_slot=#7` are *already* distinct sources for distinct per-thread execution roots; the operand stack is a third such root and gets the third number. A reader doing `rg operand_stacks src/` finds the whole walker. The `nextOperandStack` body is independently testable in isolation (mirrors the existing per-source test shape). It is the **shape most consistent with what #3a already built** for macro_root_slot: #3a did NOT fold macro into current_frame even though both are per-thread — it gave macro its own cursor + its own `macroSourceAt`. The operand stack is more distinct from binding-frames than macro is, so if macro earned its own source, the operand stack certainly does.

**Breaks / costs:**
- Breaks the `test "RootSource enum lists 10 sources per ADR-0028 §5"` assertion (root_set.zig:388) — must bump to 11.
- Requires an ADR-0028 §5 amendment adding row 11 (E-shape, "VM operand-stack frame chain per live thread") + bumping "Live entry-point walkers (E): 4 → 5". This is exactly the amendment the #3a barrier's guidance (iv) said folding "avoids".
- Does **nothing** about the three-fold repetition of the union-addressing pattern. After this lands, `frameSourceAt` / `macroSourceAt` / `evalFrameSourceAt` are three near-identical functions, and three cursors each re-implement the `if (primed) src_idx += 1 else primed = true; switch (sourceAt(src_idx))` walk. F-011 left on the table.

**F-NNN compliance:**
- **F-002** ✓ — finished-form-clean *for the source-ordered iterator as it stands*; the enum-count "10" is correctly treated as a memo, not a contract (the bump is right).
- **F-003** ⚠ — correct for #3b in isolation but does not discharge the structural-imagination horizon (the per-thread dimension is now in 3 cursors; Phase 15/JIT will add more thread-state roots).
- **F-006** ✓ — precise root, owns the operand-stack representation, no write barrier, STW-at-safepoint. In envelope.
- **F-011** ⚠ — leaves the 3-fold union-addressing duplication uncommonized; that is the exact "shared mechanism outranks effort" case F-011 names.
- **F-012** ✓ — `EvalFrame` is a VM concept but the published-root shape is backend-agnostic; tree_walk never runs on a worker so only VM publishes. Clean.

### Alternative 2 — finished-form-clean: extract the per-thread union as a first-class `ThreadRootCursor`, operand stack is its third sub-walk (RECOMMENDED)

This is the shape the F-011 + F-003 reading points at. It is bigger than Alt 1 and I recommend it anyway per F-002.

**Diagnosis first.** After #3b, the iterator has **three** per-thread sources (current_frame, macro_root_slot, operand_stacks) and **two** non-per-thread sources (ns_vars, permanent_roots). The per-thread dimension is the dominant structure, but #3a expressed it as an ad-hoc `src_idx` field copy-pasted into each per-thread cursor, with a parallel `xSourceAt(idx)` helper per source. That is the duplication. The finished form names the per-thread union **once**.

**Shape.** Introduce one cursor that, for a given thread-source-index `k` (0 = self, k>=1 = `thread_registry[k-1]`), walks that *one thread's complete root contribution*: its binding-frame chain, its macro slot, its eval-frame chain. The `RootSource` enum collapses its three per-thread rows into a single `.thread_roots` source whose cursor carries `{ thread_idx, sub: enum { binding_frames, macro_slot, eval_frames }, ...inner state... }`. `ns_vars` stays source #1, `thread_roots` is source #2 (subsuming old #2 and #7), `permanent_roots` stays last; the deferred tag-trace/documentary rows (#3-#9) stay as documentary enum members but the *iterator's* live-source count drops from "4 of 10" to "3 of N". One `threadContextAt(k)` helper returns a small struct `{ frame_head: ?*BindingFrame, macro: ?Value, eval_head: ?*EvalFrame }` for thread k (self reads TLS directly, k>=1 reads the registry) — replacing the three `xSourceAt` helpers with one.

**Why this is the finished form (structural-imagination horizon).** The brief asks which shape ages best across #3b-step2 (safepoint), #4 (real workers), and the JIT. Walk it:
- **#3b-step2 (safepoint):** the collector walks "the union of all live threads' roots". With `.thread_roots`, that union is *literally one cursor iterating thread indices* — the safepoint's mental model ("for each parked thread, mark its roots") maps 1:1 onto the iterator. Under Alt 1, the same parked-thread's roots are smeared across three different sources visited at three different times in source-order; the collector still works, but the code no longer mirrors the safepoint's per-thread quiescence argument.
- **#4 (real workers):** every new per-thread root (the binding conveyance frame from ADR-0090 §6, `*out*`/`*err*` per-thread routing from D-238, a future thread-local transducer scratch) becomes a new `sub` arm on the *one* cursor + a new field on the *one* `threadContextAt` struct — not a new enum row + new cursor + new `xSourceAt` + new test-count bump each time. Alt 1's cost is paid once per future per-thread root; Alt 2's is paid once, total.
- **JIT (Phase 15+):** when JIT'd frames need to publish their live-Value spill slots, they publish *another sub-walk of the same thread context*. The thread-centric cursor is exactly where a JIT frame's root contribution slots in. A source-ordered iterator would need yet another top-level source.

**Better than Alt 1 & Alt 3:** Commonizes the union-addressing pattern that #3b would otherwise triplicate (F-011 directly). Makes the "10 sources" → "N sources, 3 live, one of which is the per-thread union" the *honest* description of the post-Phase-B root set — which is what ADR-0028 §5 should say anyway. The per-thread walk becomes unit-testable as "given a thread context with {frames, macro, eval-chain}, the cursor yields all three" — one test covers the shape for self and workers identically.

**Breaks / costs (be concrete):**
- **This is a rewrite of the just-landed #3a iterator**, four commits old (`6ca347ae` root-walker union, `cc6881b5` registry foundation). #3a folded the worker dimension into `current_frame`/`macro_root_slot` cursors; Alt 2 says that fold was the smallest-diff-correct move for #3a-in-isolation but the *wrong cursor topology* once a third per-thread source arrives. So Alt 2 unwinds `frameSourceAt`/`macroSourceAt` + the two `src_idx` cursors and re-expresses them under `.thread_roots`. Per F-002 this rework is a feature, not a cost — but it IS a rework of green, tested, pushed code, and the brief should see that plainly.
- Touches every per-source test (`current_frame walker`, `macro_root_slot walker`, `union walk`) — they move from asserting per-source to asserting per-thread-sub. The two #3a robustness tests (registry churn) are unaffected (registry API unchanged).
- ADR-0028 §5 amendment is *larger* than Alt 1's: it re-tables rows 2 and 7 into a single "thread-roots union (binding frames + macro slot + operand stack), per live thread" E-row, and re-states "Live entry-point walkers: 4 → 3 (one being a 3-part per-thread union)". This is a more invasive doc edit, but it makes §5 *more* truthful about the post-Phase-B shape.
- **Risk concentration:** the root walker is, per the D-244 barrier, "the most correctness-critical module." Collapsing three sources into one cursor concentrates more logic in one state machine. Mitigation: the sub-walk is a flat `switch (sub)` with the same drain-then-advance shape already proven in #3a; the per-thread test asserts all three sub-walks. But a reviewer should weigh that the #3a barrier explicitly counselled "proceed in the smallest tested steps" *because* this module is delicate — Alt 2 is the opposite of a small step.

**F-NNN compliance:**
- **F-002** ✓✓ — cleanest finished form; treats "10 sources" and the #3a fold as memos (both reshaped). Larger diff accepted per F-002's explicit "diff size is not a constraint."
- **F-003** ✓✓ — directly discharges the structural-imagination horizon: the per-thread union is named once and every Phase 15-20 per-thread root extends it without new top-level structure.
- **F-006** ✓ — identical GC envelope to Alt 1 (precise, STW-at-safepoint, no write barrier); only the iterator topology differs.
- **F-011** ✓✓ — the headline win: one `threadContextAt` + one `.thread_roots` cursor replaces three `xSourceAt` + three cursors. This is the commonization F-011 ranks above effort.
- **F-012** ✓✓ — backend-agnostic by construction; the thread context carries the VM `eval_head` but the cursor shape is identical whether a thread has an eval chain or not (self/main thread at top-level has `eval_head` populated during eval, empty between).

### Alternative 3 — wildcard: thread-centric outer iterator, source-ordered inner (full re-conception)

Alt 2 collapses three sources into one cursor but keeps the source-ordered *spine* (ns_vars → thread_roots → permanent_roots). The wildcard goes further: **invert the iteration nesting entirely.** Make the outer loop "for each root-bearing entity" where entities are {the shared ns/permanent roots} ∪ {self thread} ∪ {each registered worker thread}, and each entity contributes its sub-roots. The iterator becomes `for thread in {self, workers}: yield thread.{binding_frames, macro, eval_frames}; then yield shared.{ns_vars, permanent_roots}`.

**Shape.** A two-level iterator: outer `entity_idx` over `[shared, self, worker_0, worker_1, …]`; inner dispatch picks the sub-walk set for that entity (shared entity → ns_vars + permanent_roots; thread entity → the 3-part per-thread walk). The `RootSource` enum is *retired as the iteration driver* and survives only as documentary classification in ADR-0028 §5 (the E/T/D taxonomy is a *description* of root kinds, not the iterator's control variable). Effectively `RootSource`-as-enum-order stops being load-bearing.

**Better:** Maximally mirrors the GC's actual mental model under Phase B — "mark the shared roots, then mark each live thread's roots" is *exactly* what STW-at-safepoint does. The safepoint collector's loop and the root iterator's loop become the same loop. Cleanest possible base for #4 and the JIT: a thread is the unit, full stop. Fully decouples the iterator from the "how many RootSources" question — the enum-count test stops existing because the count stops being meaningful (the iterator is thread-driven, not source-driven).

**Breaks / costs (disqualifying-adjacent):**
- This discards the source-ordered `RootIterator` *and its contract* wholesale — every existing per-source test is rewritten, not just amended. The deferred-source early-return symmetry (the `.fn_closures, .lazy_seqs, … => advance()` arm that documents tag-trace/documentary sources *in the iterator*) loses its home; ADR-0028 §5's careful E/T/D shape taxonomy, which currently maps 1:1 onto enum members the iterator visits, becomes pure documentation with no code mirror. That mirror has review value (a reader sees all 10 sources accounted-for in `next()`); the wildcard trades it away.
- The `ns_vars` + `permanent_roots` "shared entity" is a slightly forced grouping — they are not per-thread and bundling them as "entity 0" is a touch artificial (they have nothing in common except "not per-thread"). Alt 2 keeps them as honest top-level sources, which reads better.
- Biggest single diff of the three; highest review surface on the most correctness-critical module; furthest from the #3a barrier's "smallest tested steps" counsel.
- **No additional F-006/F-011/F-012 win over Alt 2** that I can identify — it buys "the enum-count question disappears" but Alt 2 already neutralizes that question (the count becomes "3 live, one a union" which is fine). So the wildcard pays a large extra diff for a marginal conceptual-purity gain over Alt 2.

**F-NNN compliance:**
- **F-002** ✓ — finished-form-clean, arguably the *most* conceptually pure; diff size correctly not a constraint.
- **F-003** ✓✓ — same horizon discharge as Alt 2, slightly more thorough (thread is the literal unit).
- **F-006** ✓ — same envelope.
- **F-011** ✓ — commonizes the union but at the cost of the source-enum mirror's documentary value; net DRY win is real but partially offset.
- **F-012** ✓✓ — backend-agnostic, thread-as-unit.
- **Verdict:** strongest conceptual match to the safepoint model, but it spends a large extra diff over Alt 2 to neutralize a question Alt 2 already neutralizes, and it sacrifices the iterator-as-checklist property (every RootSource visibly accounted for in `next()`) that has genuine review value on this module. Recommend *not* for #3b; **note it explicitly as the Phase-15/JIT-era re-conception candidate** — if/when JIT frames add a fourth and fifth per-thread root and the shared/per-thread split becomes the dominant axis, revisit the thread-driven spine then.

### On the precedent-tension the brief flagged (is "fold, don't add a source" binding here?)

This deserves a direct answer because it is the crux. The #3a barrier guidance (iv) said: *"FOLD it into the current_frame/macro_root_slot cursors rather than add an 11th RootSource … adding a source needs an ADR-0028 amendment — folding avoids it."*

**That guidance does not bind the operand-stack question, and invoking it here would itself be the Reservation-as-bias smell.** Two independent reasons:

1. **Different KIND.** #3a's fold was the *worker dimension of an existing root* — a worker's binding frames are the *same kind of root* as the self thread's binding frames, "just from another thread" (the brief's own words, and root_set.zig:155-163 confirms: source-index 0 = self, k>=1 = worker, *same FrameSource type*). Folding same-kind-different-thread into one cursor is correct: it is one root kind with a thread dimension. The operand stack is a *different root kind* (VM-backend execution state vs Clojure dynamic-binding state). #3a's precedent is "don't split one root kind across threads into N sources" — it says nothing about "don't give a genuinely new root kind its own source." Macro_root_slot proves the point: #3a gave macro its *own* source (#7, own cursor, own `macroSourceAt`) precisely because it is a different kind from binding-frames, *and then* folded the worker dimension into that source. The operand stack is the same situation as macro: new kind → own treatment, with the worker dimension folded into it.

2. **The stated rationale was "avoid an ADR-0028 amendment."** That is a process-cost-avoidance rationale, not a finished-form rationale. F-002 §4 names obeying a reservation *because it is reserved / because amending costs effort* as the Reservation-as-bias smell, forbidden. "Folding avoids the amendment" is exactly "obey the 10-count because changing it is a hassle." The amendment is a memo edit; if the finished form wants 11 sources (Alt 1) or a re-tabled union (Alt 2/3), the amendment follows the code, per ROADMAP §17. The #3a barrier was right *for #3a* (the worker dimension genuinely is not a new source); carrying its "avoid the amendment" reflex into #3b is the bias F-002 forbids.

So: the precedent is real but *scoped to same-kind-different-thread*. For the different-kind operand stack, it is silent at best and a bias-trap at worst.

### Synthesis / recommendation

**No finished-form-clean option requires violating any F-NNN.** All three alternatives sit inside F-006 (precise roots, STW-at-safepoint, no write barrier) and F-012 (backend-agnostic publication, VM-only workers). I state that explicitly as the brief requested.

**Recommendation: Alternative 2** — extract the per-thread union as a first-class `.thread_roots` cursor with the operand stack as its third sub-walk, rewriting #3a's `frameSourceAt`/`macroSourceAt`/`src_idx`-cursor triplication into one `threadContextAt` + one cursor.

The reasoning chain, F-002-first:
- **Option A (fold into current_frame) is rejected outright** — it conflates a Clojure dynamic-binding root with a VM operand-stack root inside one cursor, which is a different-kind conflation that a future reader/maintainer would have to split back out (the "fold creates future split-out rework" hazard the brief asked me to weigh — it lands on A, not on B/Alt2). Its only advantage is dodging a doc amendment, which is the Reservation-as-bias trap.
- **Between Alt 1 (clean Option B) and Alt 2 (the union extraction)**, F-011 is decisive. After #3b, the per-thread union-addressing pattern is *triplicated* (frame, macro, eval-frame, each with its own `xSourceAt` + `src_idx` cursor). Alt 1 ships that triplication; Alt 2 commonizes it. F-011 ranks shared-mechanism above effort, and F-002 forbids me from downgrading to Alt 1 on the grounds that Alt 2 reworks just-landed code. Per the Cycle-budget-defer smell, "Alt 1 is a smaller diff because it doesn't touch #3a" is *not* a valid reason to prefer it — and that is precisely the instinct I am required to override here.
- **Alt 3 (thread-driven spine) is the cleaner *conceptual* match** to the safepoint model, and I record it as the **Phase-15/JIT-era re-conception candidate**, but it is not the right call for #3b: it spends a large extra diff over Alt 2 to neutralize the "how many RootSources" question that Alt 2 already neutralizes, and it sacrifices the iterator-as-checklist property (every root source visibly accounted-for in `next()`'s switch, mirroring ADR-0028 §5's E/T/D taxonomy) that has real review value on the most correctness-critical module in the tree.

**The one honest tension in recommending Alt 2:** the D-244 #3a barrier explicitly counsels "the GC root walker is the most correctness-critical module, so proceed in the smallest tested steps." Alt 2 is a rewrite of green pushed code, not a small step — it is in direct rhetorical tension with that counsel. I resolve it in Alt 2's favor because (a) F-002 outranks step-size (step-size, like diff-size, is not an F-NNN constraint), (b) the rewrite is mechanically guarded — the existing per-source tests + the #3a union-walk test + the churn-robustness tests pin the *behaviour*, so the topology change is refactor-under-green, exactly the F-002-endorsed move, and (c) #3a's own commit message called itself "Phase B #3a-step2" / "foundation" — it was always the bounded first step, and reshaping a foundation when the third pillar arrives is the structural-imagination call F-003 mandates, not a regression. The "smallest tested steps" counsel is satisfied by *how* Alt 2 lands (refactor under the existing green tests, then add the operand-stack sub-walk + its test), not by choosing the smaller-topology Alt 1.

If the main loop's instinct after reading this is "Alt 1 is less risky on the critical module, take it" — that instinct is the Cycle-budget-defer / Smallest-diff bias the loop is required to override unless Alt 2 hits a real F-NNN block. It does not. Pick Alt 2.

### Main-loop adoption note

Adopted Alt 2 verbatim. The main loop's own instinct WAS the "Alt 1 is less
risky on the critical module" pull the DA names in its closing paragraph; the
DA correctly identifies the mitigation (refactor-under-green: the #3a per-source
+ union + churn tests pin behaviour, so the topology change is a guarded
refactor, not a leap). The decisive non-cycle-budget reason is the #3b-step2
safepoint mapping (§Decision 2) + the F-011 addressing commonization (§Decision
1). To honour the barrier's "smallest tested steps" *within* Alt 2, the source
landing keeps the existing #3a tests green through the refactor and adds the
operand-stack sub-walk + its own tests in the same commit (one cohesive,
fully-tested unit — not an Alt-1 way-station, which would be an excessive
skeleton that step-1b rewrites).

## Consequences

- **ADR-0028 §5** gains amendment 2: rows 2 (`current_frame`) + 7
  (`macro_root_slot`) are subsumed into a single `thread_roots` E-row (binding
  frames + macro slot + VM operand-stack chain, per live thread); live E
  walkers 4 → 3; the `RootSource` enum count 10 → 9.
- **`root_set.zig`** gains `EvalFrame` + `threadlocal eval_frame_head` +
  `ThreadGcContext.eval_frame_slot` + `threadContextAt` + the `thread_roots`
  cursor; `frameSourceAt`/`macroSourceAt` + their two cursors are removed.
- **`vm.zig`** `eval` pushes/`defer`-pops its `EvalFrame` (a PERF-relevant
  hot-path write — candidate for a `// PERF:` marker + O-NNN if it shows on a
  Release `scripts/perf.sh` number; not marked speculatively).
- **Runtime-inert** today (no behaviour change; gate green by construction).
  The safepoint that makes auto-collect / worker-collect actually fire is
  #3b-step2 (couples to #4).
- **Alt 3** (thread-driven iterator spine) is the recorded Phase-15/JIT-era
  re-conception candidate.

## Affected files

- `.dev/decisions/0028_mark_sweep_gc_three_layer_allocator.md` — amendment 2
  (§5 re-table, pointer here).
- `src/runtime/gc/root_set.zig` — the `thread_roots` union cursor + `EvalFrame`
  publication infra + tests.
- `src/eval/backend/vm.zig` — `eval` EvalFrame push/pop.
- `.dev/debt.yaml` D-244 — #3b-step1 landed; #3b-step2 (safepoint) remains.

## References

- ADR-0090 ("D-244 decision" Alt B) — the parent decision this implements.
- ADR-0028 §5 — the root-source table this re-tables.
- `.dev/debt.yaml` D-244 — the #3 implementation checklist.
- `.dev/project_facts.md` F-002 / F-003 / F-006 / F-011 / F-012.
- `private/notes/phaseB-3b-operand-stack-publication.md` — the Step 0.6 re-lay.
