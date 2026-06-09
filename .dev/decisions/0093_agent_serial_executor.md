# ADR-0093 — Agent: serial async executor (single-drainer handoff, leaf-lock queue)

- Status: Proposed → Accepted (2026-06-05)
- Phase: B (concurrency), task #6 (first slice)
- Related: ADR-0090 (Phase B concurrency redesign), ADR-0091 (thread_roots GC
  walk), ADR-0092 (heap-value monitor), F-004 (NaN-box), F-006 (mark-sweep STW,
  no write barrier), F-011 (behavioural equivalence), F-012 (VM backend)

## Context

`(agent init)` holds state mutated only by ACTIONS dispatched with `(send a f &
args)` / `(send-off a f & args)`. Actions on one agent run ONE-AT-A-TIME in send
order; different agents run concurrently. `@agent` is a non-blocking state read;
`(await a)` blocks until the actions sent so far have run. JVM Clojure uses an
`AtomicReference<ActionQueue>` + two thread pools (send=fixed, send-off=cached);
the pool choice is a non-observable throughput property.

The design question under cljw's stop-the-world mark-sweep GC (F-006): how to
build the serial-execution queue + worker so the queue is GC-rooted and no thread
can deadlock the collector.

## Decision (first slice)

**Agent heap type** (tag 33, reserved): `extern { header, state: Value, rt, env,
cell: *AgentCell }`. `state` is read (`deref`) / written (drainer) atomically
(acquire/release) — the drainer is the SOLE writer (one drainer per agent at a
time), `@agent` the reader, so a single-word atomic load/store suffices (no CAS;
reuses the atom fix pattern).

**Off-heap `AgentCell` (gpa-allocated, finaliser-freed)**: `{ mutex: Io.Mutex,
draining: bool, actions: ArrayList(Value), head: usize }`. The pending-action
queue is this **off-heap gpa list**, NOT a Value PersistentQueue — see the
leaf-lock invariant below.

**Single-drainer handoff (serial execution)**: the thread that transitions the
queue empty→non-empty sets `draining=true` under `cell.mutex` and spawns the sole
drainer; the drainer pops actions until empty, then clears `draining` and exits.
`draining` is checked/set under `cell.mutex`, so a `send` either sees
`draining==true` (the live drainer picks its action up) or `draining==false` (it
spawns a fresh drainer). **Invariant: the drainer's "queue-empty test → clear
`draining` → release mutex → return" is ONE critical section** — never split it,
or an action can be stranded with no live drainer.

**`cell.mutex` is a LEAF lock (the load-bearing GC invariant)**: under the STW
collector, a thread BLOCKED on `cell.mutex` is not at a safepoint, so if a collect
armed while it blocked, `stopWorld` would wait for a park that never comes. So
`cell.mutex` is held ONLY across the gpa queue push/pop — which never allocates on
the GC heap and never parks — NEVER across `callFn`, a GC allocation, or a park.
The action vector `[f & args]` is built (GC-allocated) BEFORE the lock; the action
runs (callFn + setState) AFTER the unlock. **This is why the queue is an off-heap
gpa list and not a Value PersistentQueue: `conj` would GC-allocate under the
mutex, breaking the invariant** (a parked-mid-conj drainer holding `cell.mutex`
would hang `stopWorld` for any peer blocked on that mutex).

**GC**: `traceGc` marks `state` + every queued action in `cell.actions[head..]`, so
the queue is a root source the collector walks (mutators parked during a collect →
the list is quiescent while traced). The drainer registers a `ThreadGcContext`
like `future.worker`, so its in-flight action mid-`callFn` is rooted by its
operand stack. The fabrication window (a fresh action vector held only as a Zig
local in `send` before it is queued) rides the #4a' `gc_self_guard` hardening —
dormant while auto-collect is OFF, as today.

**`await`** (core.clj, no new primitive): sends a sentinel action that delivers a
`promise` to each agent (so agents drain concurrently), then blocks on each
promise. A promise IS cljw's cross-thread latch (clj uses a CountDownLatch), held
alive by the sentinel action in the agent's queue. The sentinel returns state
unchanged. This is clj's latch-action semantics — NOT a "wait until idle" poll,
which the DA showed can hang a program that terminates under clj.

**Spawn-per-drain-episode, no pool**: send/send-off share one path; the two-pool
starvation avoidance is non-observable (F-011). A real bounded pool / `send-via`
is a later perf tier.

**Deferred to later slices**: watches/validator on agents (+ the shared IRef
substrate extraction the DA recommends, decided WHEN that surface lands and a
second consumer is concrete — Alt 2); error modes (`:continue`/`:fail`,
`agent-error`, `restart-agent`, `set-error-handler!`, `set-error-mode!`);
`send-via`; STM `send`-deferral; `*agent*`; nested-send/`release-pending-sends`;
`shutdown-agents`; `await-for` timeout. `(agent init opts...)` and add-watch /
set-validator! on an agent raise a clear "not yet" error (transient stubs, not
silent drops).

## Alternatives considered (Devil's-advocate subagent, fresh context, verbatim)

> ### Alt 1 (smallest-diff): Lock-free MPSC action queue (AtomicReference head)
> instead of mutex-guarded queue Value — better: removes the cell.mutex from the
> enqueue/drain hot path entirely; the empty→non-empty handoff becomes a single
> CAS on the queue head (the `draining` flag is folded into a tagged head
> pointer), so send/send-off never block and there is no "drainer holds cell.mutex
> at a non-safepoint" window. The `await` cond is the only remaining mutex use.
> breaks: it abandons the draft's "queue is a traced Value field" simplicity — a
> lock-free linked list of actions is NOT a single persistent-collection Value the
> existing `traceGc` can mark in one call, so it forces a NEW GC root source (the
> off-heap node chain must be walked by the collector, or each node must itself be
> a heap Value with its own tag). That re-opens exactly the #4a' concern the draft
> closed "by construction," and an off-heap atomic node chain mutated by the
> drainer concurrently with the STW collector's read needs its own memory-ordering
> proof. Net: smaller hot-path diff, larger GC-rooting surface — a smallest-diff
> bias against F-002's finished form.
>
> ### Alt 2 (finished-form-clean): Generalized IRef/handoff substrate shared by
> atom + agent (+ future ref/STM) — better: clj implements agent, atom, ref, and
> var watches/validators over ONE `IRef`/`ARef` machinery; the draft re-implements
> watches+validator+meta as fresh Agent fields duplicating atom's. F-011
> (commonization outranks effort) + F-009 (neutral impl home) point hard at
> extracting a shared `runtime/concurrency/iref.zig` (watch-notify, validator-
> check, meta) and a shared `runtime/concurrency/handoff.zig` (the single-drainer
> empty→non-empty episode spawner) that BOTH agent and any future serial-executor
> reuse. The single-drainer handoff is the agent's distinctive logic; isolating it
> as a tested substrate means `await`, error-mode (:continue/:fail), and
> restart-agent later slices bolt onto a proven core instead of re-deriving the
> race each time. This is the cleanest finished form and I recommend it per F-002
> even though it is a bigger diff than the draft. breaks: nothing F-NNN. It
> enlarges THIS slice (extract + retrofit atom's watches/validator onto the shared
> iref), and the watch/validator extraction touches already-shipped atom code
> (ADR-0081) — a depth-2/3 surgery, not a green-field add. The risk is over-
> abstracting the handoff before the second consumer (STM `send` deferral, agent
> pools) exists to validate the shape; mitigate by extracting only what atom+agent
> demonstrably share NOW (watch/validator/meta) and leaving the handoff agent-local
> until a second serial-executor appears.
>
> ### Alt 3 (wildcard): Pool-less but drainer-reuse via a parked-worker handoff
> (no spawn-per-episode) — better: instead of `std.Thread.spawn` per drain-episode,
> keep ONE long-lived drainer thread per agent that parks on `cell.cond` when the
> queue empties (instead of exiting) and is signalled by `send`. Eliminates per-
> episode OS-thread spawn/teardown cost, and a persistently-registered
> `ThreadGcContext` means the collector's root walk shape is stable instead of
> churning register/unregister every episode (the very churn the D-244 stress test
> was added to harden). breaks: it converts the agent into a permanently-live
> thread + permanently-registered GC root context that never exits until
> `shutdown-agents` — so a program that creates many short-lived agents leaks one
> parked OS thread each (clj's pool bounds this; a per-agent permanent thread does
> not). It also makes `shutdown-agents` (a deferred slice) a CORRECTNESS
> prerequisite rather than a nicety, because without it the process cannot exit
> cleanly (parked threads block join). Higher infra cost for a throughput win that
> is non-observable (F-011) — wildcard, not recommended for the first slice.
>
> ### Handoff-race verdict: race-free, with one required ordering constraint the
> draft already states. [the stranding interleaving cannot occur because the
> drainer's `draining=false` write and a send's `draining` read are both under
> `cell.mutex`; if a send enqueues before the drainer's empty-check, the drainer
> sees non-empty and keeps draining; if after the drainer cleared draining+
> unlocked, the send reads draining==false and spawns a fresh drainer. Required
> invariant: the empty-test→clear-flag→release-mutex→return is a single critical
> section.]
>
> ### GC-queue verdict: traced-Value-field is sufficient for MARKING (STW means no
> concurrent mutator during traceGc), but the draft has a latent LIVENESS bug that
> is decisive: a worker reaches a safepoint ONLY at the alloc-prologue park or the
> VM back-edge poll. A thread BLOCKED on `cell.mutex` is NOT at a safepoint, so if
> a second thread is blocked on cell.mutex when STW arms, stopWorld hangs forever.
> The fix the main loop MUST apply: never hold `cell.mutex` across a VM call or an
> allocation — pop under the lock, UNLOCK, then run callFn+setState, re-lock for
> the next. (This is why the queue is gpa-backed, not a Value PersistentQueue whose
> conj allocates under the mutex.)
>
> ### await verdict: wait-until-idle is an observable divergence (a program that
> terminates under clj can HANG under cljw if another thread keeps sending). Ship
> the latch action (a sentinel that fires a per-await condition / promise), not
> wait-until-idle.
>
> ### Recommendation: Alt 2 (shared IRef/handoff substrate) for the surface
> (watches/validator/meta), with the draft's mutex-guarded queue + single-drainer
> handoff as the agent-local core — and ship the latch-based `await`. The single
> most important correctness risk: `cell.mutex` must be a LEAF lock, never held
> across `callFn`, an allocation, or a park.
>
> ### F-NNN check: none violated. Alt 1's lock-free off-heap node chain brushes
> against F-006 (recorded as the reason it is the rejected smallest-diff option).
> Alt 2/3 are F-NNN-clean. The latch-`await` strengthens F-011. `@agent` reusing
> atom's single-word atomic load is torn-read-free.

The main loop adopted: the draft core (mutex-guarded queue + single-drainer
handoff) **with the off-heap gpa queue** (the leaf-lock invariant the DA proved
load-bearing forces gpa-backed over a Value PersistentQueue, since conj would
alloc under the mutex — this is a refinement of the draft, not a rejection), the
**latch-based `await`** (DA's correction over wait-until-idle), and **defers
watches/validator + the Alt 2 IRef extraction to the watches/validator slice**
(per the DA's own caution against over-abstracting before the second consumer is
concrete). Deferring watches/validator (a separate surface) is feature slicing,
not a cycle-budget defer — the iref extraction lands WITH that surface.

## Consequences

- `(agent init)` + send/send-off + `@agent` + await work, serial-per-agent +
  concurrent-across-agents, clj-result-equivalent: send 100 → 100; (+5 then *3)
  → 15; send-off conj → (2 1); 4×100 concurrent sends to one agent → 400 (handoff
  race-free, 30/30 ReleaseSafe); 8 agents each +50 → all 50.
- An action that throws leaves state unchanged and draining continues (clj
  `:continue` mode). clj's default (no handler) is `:fail`; the configurable
  error-mode + `agent-error`/`restart-agent` is a later slice — recorded so the
  default-mode divergence is not a silent drop.
- A fire-and-forget agent is `gc.pin`ned while its drainer runs (unpinned on
  drainer exit), so it is not swept mid-drain.
- Process exit with a still-running drainer is an orphan (same limitation as a
  still-running future worker); `shutdown-agents` is a later slice.

## Affected files

- `src/runtime/agent.zig` (new) — the Agent type + cell + single-drainer engine.
- `src/lang/primitive/agent.zig` (new) — `agent` / `send` / `send-off`.
- `src/lang/clj/clojure/core.clj` — `await` (latch over send + promise).
- `src/lang/primitive/stm.zig` — `deref` dispatch for `.agent`.
- `src/runtime/runtime.zig` — register the agent GC hooks.
- `src/runtime/error/catalog.zig` — `agent_options_unsupported`.
- `src/main.zig` — test-aggregator import for `agent.zig`.
- `test/e2e/phase16_agent.sh` (new) + `test/run_all.sh` registration.

## Revision history

### am1 (2026-06-10) — `await` delivers AFTER `notifyWatches` (deliver-in-body race fix, D-368)

**Symptom.** The Ubuntu x86_64 full gate failed `e2e_phase16_agent`
`agent_add_watch`: `got '[[0 1] [1 2]]', want '[[0 1] [1 2] [2 2]]'`. The clj
oracle (ground truth, F-011) reliably yields the 3 fires `[[0 1] [1 2] [2 2]]`
— the `[2 2]` is `await`'s own count-down action's no-op watch fire. Mac/JVM
usually win the race; Linux x86_64 lost it.

**Root cause.** `await` was `(send a (fn* [s] (deliver p s) s))` — the sentinel
delivered its promise INSIDE the action body. `runAction` runs the body
(step "newstate = callFn"), THEN stores, THEN `notifyWatches`. So `(deliver p s)`
released the awaiting thread BEFORE the sentinel action's own watch fired; the
awaiter could read `@log` before the `[2 2]` `swap!` ran. The e2e comment
documented the intended CONTRACT ("await guarantees every fire ran, incl. its own
`[2 2]`, matching JVM ARef") — the implementation violated its own contract. A
real concurrency-correctness bug, not a flaky test (user-directed root-fix
2026-06-10).

**Decision.** Move `await`'s promise delivery from the action BODY to a
drainer-side step AFTER `notifyWatches`. The agent queue element becomes an
`Action { body: Value, completion: Value }`: `body` is the `[f & args]` vector
(nil = a pure barrier with no state change), `completion` is an optional promise
the drainer delivers AFTER the action stores its state AND fires its watches.
`await` is now `(__agent-await a)` — a primitive that enqueues a nil-body barrier
(which still fires the clj-faithful `[s s]` no-op watch via `notifyWatches`) and
returns the completion promise; `await` maps it over its agents then
`(dorun (map deref …))`. Deterministic, watch-order-independent, clj-faithful.
The fix is the **minimal** form of the Devil's-advocate Alt 2 below — the typed
2-field `Action` (NOT the full tagged-union `.normal/.barrier` + 3-phase
`runAction` refactor + speculative generic continuation slot, which is
gold-plating for post-action hooks no current slice needs; F-003 / excessive-
skeleton smell).

**Leaf-lock invariant (F-006) preserved**: the completion deliver runs in the
drainer AFTER the action's pop+unlock, outside `cell.mutex`; promise.zig's own
leaf lock does not nest with the agent's. **Behaviour preserved**: send_await,
serial_order (100), send_args, send_off, concurrent_sends (400/4-thread),
concurrent_agents (8), remove_watch (`[1 1]`), nested_send, multi-agent await —
all verified green; `agent_add_watch` now deterministically `[[0 1] [1 2] [2 2]]`
(30/30 on Mac).

**Affected files (am1)**: `src/runtime/agent.zig` (`Action` struct; `send`→
`enqueueAction`; new `sendAwait`; `runAction` body-or-barrier + post-notify
deliver; `traceGc` marks body+completion; `promise.zig` import) ·
`src/lang/primitive/agent.zig` (`__agent-await` primitive + registration +
`promise.zig` import) · `src/lang/clj/clojure/core.clj` (`await` over
`__agent-await`).

#### Alternatives considered (Devil's-advocate fork, fresh context, 2026-06-10)

> The bug: `await`'s sentinel action delivers its promise from *inside* `callFn`
> (step 2 of `runAction`), so the awaiting thread can wake before step 4
> (`notifyWatches`) fires the sentinel action's own `[s s]` watch. The fix must
> move the deliver-equivalent wakeup to *after* the sentinel action's
> `notifyWatches` completes, deterministically, matching clj's 3-fire output
> `[[0 1] [1 2] [2 2]]`. All three options preserve the `[2 2]` fire (F-011) and
> never move work under `cell.mutex` (F-006). None requires a vtable hop for the
> wakeup, since `promise_mod.deliver` is directly callable from the drainer.
>
> **Alt 1 — Smallest-diff: barrier action recognised by a sentinel marker,
> deliver in a post-`notifyWatches` hook.** The await action vector carries a
> recognisable barrier marker (distinguished first element); after `runAction`
> returns, the drainer checks "was this a barrier?" and delivers the promise
> riding as element 2. Better: minimal new surface, one post-action branch. Risks:
> a per-action head type-test in the hot serial loop; couples the queue element
> shape to "first elem is fn OR barrier-marker" (a mild representation smell). F-006
> preserved (deliver post-unlock). Multi-agent await preserved.
>
> **Alt 2 — Finished-form-clean: typed `Action` queue with a post-notify
> continuation.** Refactor `runAction` into compute→store→notify and make the
> queue `ArrayList(Action)` with `.normal([f&args])` / `.barrier(promise,[f&args])`
> variants; the drainer runs the action's continuation after `notify` (for
> `.barrier`, `deliver(p,new)`). Better: the await ordering becomes a structural
> property, not a magic-head convention; no per-action head type-test; the natural
> home for future post-action coordination (validators, completion callbacks). The
> variant tag is the dispatch; `traceGc` marks both the body vector and the barrier
> promise by construction. Risks: larger diff (queue element type change ripples
> through `send`/`restart`/`traceGc`/`finaliseGc` + every `vector.nth(action,…)`);
> more GC care. Per F-002 the larger diff is NOT a downgrade reason — the typed
> queue is the cleaner contract. F-006 preserved (deliver is a post-notify,
> post-unlock continuation). Multi-agent await preserved. **DA recommendation.**
>
> **Alt 3 — Wildcard: per-agent monotonic completed-counter + condvar, no barrier
> action.** `await` snapshots the enqueue index and waits until `completed >=
> target`. **Violates F-011 (leading entry):** a pure read-side counter barrier
> produces only `[[0 1] [1 2]]` — it does NOT enqueue a real action, so the
> clj-faithful `[2 2]` count-down fire never happens. A hybrid (counter + a no-op
> action to fire `[2 2]`) is strictly worse than Alt 2 (two mechanisms for one
> behaviour). F-006 is technically satisfiable (the condvar wait parks at a
> safepoint), but F-011 disqualifies it. Recorded so the rejection is visible.
>
> **Recommendation (non-binding): Alt 2** — the finished-form-clean shape under
> F-002. Alt 1 is the fallback only on a real F-NNN block on the `Action` struct
> (none). Alt 3 is disqualified by F-011.

**Main-loop choice**: Alt 2's principle (typed `Action` carrying the completion),
in its **minimal** form (a 2-field struct `{body, completion}` + a nil-body
barrier), NOT the full tagged-union + 3-phase-refactor + generic continuation
slot. Rationale: the structural cleanliness the DA recommends (completion bound to
the action, no magic-head type-test) is captured by the 2-field struct; the
generic post-action-coordination substrate (validators/callbacks) is speculative
for needs no current slice has (F-003 defer-to-owner + the excessive-skeleton
smell). This stays finished-form-clean for the await need without gold-plating.
