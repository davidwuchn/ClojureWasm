# ADR-0155 — Legacy / executor agent surface: per-function disposition (D-442)

Status: Proposed → Accepted (2026-06-20)

## Context

D-442 (the Track-R agent-parity micro-survey) left 8 agent-system functions
unimplemented after the `future-cancel` arc (ADR-0153). They are the
pre-1.0-deprecated + the 1.5 executor-configuration surface:
`agent-errors`, `clear-agent-errors`, `send-via`, `set-agent-send-executor!`,
`set-agent-send-off-executor!`, `shutdown-agents`, `*agent*`,
`release-pending-sends`. Each currently raises `unresolved-symbol`.

cljw's agent model (the classification baseline, from `runtime/agent.zig`):
**one DETACHED drainer thread per agent** (spawned on the empty→non-empty queue
transition, drains the FIFO serially, exits), **no shared executor pool**, a
real **`nested_pending` ThreadLocal** mirroring clj's `Agent.nested` (D-388),
and **no `*agent*` dynamic var**. This diverges from clj/babashka (both
JVM-pool-backed) AND from cljw v0 (its own worker pool + `*agent*` binding).

The classification must obey `provisional_marker.md` § "permanent no-op
forbidden": a function may not ship returning a default that masks a dropped
semantic. So a thin no-op is allowed ONLY where cljw genuinely satisfies the
observable semantic; otherwise the honest disposition is an explicit error
(accept-divergence) recorded as an AD. Survey:
`private/notes/D442-legacy-agent-surface-survey.md`.

## Decision

Three dispositions, by whether cljw's model makes the semantic meaningful:

| Function                                                                 | Disposition                   | Rationale                                                                                                                                                                                                                                                                                                                                                               |
|--------------------------------------------------------------------------|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `agent-errors`                                                           | **implement**                 | clj-deprecated 1.2; pure sugar over the existing `agent-error` (`(when-let [e …] (list e))`).                                                                                                                                                                                                                                                                          |
| `clear-agent-errors`                                                     | **implement**                 | clj-deprecated 1.2; `(restart-agent a @a)` — both halves exist.                                                                                                                                                                                                                                                                                                        |
| `*agent*`                                                                | **implement**                 | the drainer knows `a`; bind `*agent*` around each action body (clj's `binding [*agent* a]`).                                                                                                                                                                                                                                                                            |
| `release-pending-sends`                                                  | **implement**                 | the `nested_pending` buffer EXISTS — flush it + return the count (v0's `return 0` would now lie).                                                                                                                                                                                                                                                                      |
| `shutdown-agents`                                                        | **implement (real)**          | flip a process-global `agents_shut_down` flag; the send path then DROPS new dispatches — send returns the agent, no throw, action never runs (clj-faithful: clj's executor rejects + `Action.execute` swallows the exception). Detached drainers already don't block exit. Faithful in the common case; AD-046 scopes the `:error-handler` edge (see § Alternatives). |
| `send-via` / `set-agent-send-executor!` / `set-agent-send-off-executor!` | **accept-divergence (raise)** | cljw exposes NO executor object (no `java.util.concurrent.ExecutorService` to construct or pass), so there is nothing real to thread/configure. Silently ignoring the user's explicit executor is a masked-semantic lie (DA finding); raise an explicit "cljw has no configurable executor" error → AD-045.                                                            |

The `implement` group is real behaviour. The three executor-shaped functions all
raise: cljw genuinely has no executor concept, so neither a no-op (would mask the
dropped semantic) nor a real impl (would require a `java.util.concurrent` pool
subsystem cljw deliberately lacks) is honest — the explicit error is.

New ADs: **AD-045** (the three executor-shaped fns raise — cljw exposes no
configurable executor) + **AD-046** (post-shutdown send disposition; see below).

> **Premise correction (2026-06-20, part 2 landing).** This ADR originally claimed
> "`shutdown-agents` needs no AD: post-shutdown sends *reject*; only the error
> *Kind* differs, which AD-007 covers." The clj oracle proved that premise FALSE:
> after `(shutdown-agents)`, clj's `send` **returns the agent and does NOT throw**
> — `Action.execute` catches the executor's `RejectedExecutionException` and either
> routes it to the agent's `:error-handler` (if set) or swallows it; the action is
> dropped. So cljw must DROP, not throw. The common case (no handler) is
> byte-identical to clj; the only residual divergence is that cljw does not
> synthesize a fake rejection exception to fire a handler — recorded as **AD-046**
> (AD-007 is inapplicable: it governs error *Kind* when BOTH runtimes throw, and
> here clj does not throw at all).

## Alternatives considered (Devil's-advocate fork, fresh context — digest)

The DA fork (fresh context, F-NNN-constrained) produced three overall shapes and
stress-tested the two borderline calls; its findings REVISED this ADR:

- **Alt A (smallest-diff: make the executor setters no-ops too)** — rejected: a
  bare no-op on `set-agent-send-executor!` is the canonical masked-semantic lie
  (the user expects subsequent dispatch on their executor; cljw silently keeps its
  drainer). Violates `permanent_no_op_forbidden`.
- **Alt B (finished-form: a real `DispatchFn` seam so the setters + `send-via`
  become real)** — rejected on an F-NNN-adjacent ground the DA did not fully
  price: cljw has no `ExecutorService` TYPE and no way to construct one, so the
  user has no executor VALUE to pass; making the setters "real" would require the
  whole `java.util.concurrent` executor subsystem, which is a distinct large
  feature out of D-442's scope (and arguably the point — cljw exposes no
  executors). So within cljw's model the setters genuinely cannot be made real;
  raise is the honest disposition.
- **Alt C (raise on everything cljw can't satisfy, incl. `shutdown-agents`)** —
  rejected: `shutdown-agents` raising breaks any ported program's graceful-exit
  coda even though the *intent* (let the process exit) IS satisfied. Over-corrects.

Borderline corrections the DA forced (both adopted):

1. **`send-via`** — the draft's "accept-and-ignore the executor" was WRONG. The
   ADR-0093 D1 "pool choice is non-observable" precedent covers only the internal
   send/send-off split the user never named; `send-via`'s executor is passed
   EXPLICITLY, so ignoring it is a lie ("the user thinks work runs on their bounded
   pool"). Reclassified from silent-no-op to **raise** (joins the executor setters).
2. **`shutdown-agents`** — the draft's pure nil no-op did not just drop clj's "no
   new actions accepted" clause, it did the OPPOSITE (ran work clj guarantees won't
   run). Reclassified from thin-no-op to **real**: a cheap process-global
   `agents_shut_down` flag the send path checks. No F-006 interaction (a flag, not a
   thread/lock). **(Part-2 correction:** the DA + draft both assumed the flag should
   make the send *throw*; the oracle later showed clj DROPS the send without
   throwing. The landed behaviour is the clj-faithful drop, scoped by AD-046 — a
   second DA fork validated drop-vs-throw and chose drop on F-011 priority over the
   *letter* of permanent-no-op-forbidden.)

The four `implement (real)` calls (`agent-errors`/`clear-agent-errors`/`*agent*`/
`release-pending-sends`) were uncontested by the DA.

## Alternatives considered (part 2 — `shutdown-agents` send disposition, 2026-06-20 DA fork)

When part 2 landed, the clj oracle contradicted this ADR's part-1 premise (clj
drops, does not throw). A second Devil's-advocate fork (fresh context) stress-
tested three dispositions; its output, verbatim:

> **Alt A — match clj (send returns agent, action silently dropped, no throw).**
> Does better: pure F-011 parity, zero AD entropy, identical to clj for a ported
> cleanup-path send. The `permanent_no_op_forbidden` objection is weaker than it
> looks — that principle bans cljw-*invented* silent drops where the user expects
> an effect; here the user issued the terminal teardown and clj itself documents
> the drop, so "the drop IS the contract." Breaks: collides with the *letter* of
> permanent_no_op_forbidden, so it needs an explicit carve-out (an AD/ADR note)
> or a future audit re-flags it.
>
> **Alt B — keep the explicit throw, record AD-046.** Does better: honors the
> letter of permanent_no_op_forbidden with no interpretation; loud failure.
> Breaks: manufactures a *behavioral* F-011 divergence where clj has a clean
> observable behavior cljw could simply match — the worst kind of AD (elective,
> not forced by a missing subsystem). A ported program that sends post-shutdown
> runs clean on clj and CRASHES on cljw — exactly the portability hazard F-011
> exists to prevent. derives_from = permanent_no_op_forbidden is a misuse: that
> invariant protects against *cljw* dropping effects, not against *clj* defining
> a terminal no-op.
>
> **Alt C — route the dropped send to the error-handler if set, else drop.** Does
> better: most mechanically faithful to clj's `execute()` swallow-then-route.
> Breaks: highest-cost, lowest-value — clj's routing is an implementation artifact
> of catching `RejectedExecutionException`, not a contract anyone ports against;
> cljw would synthesize a fake exception of a type it lacks, CREATING a fresh DIFF
> (the fabricated `ex`'s class/message) in the path it's trying to make faithful.
> Net negative.
>
> **Recommendation: Alt A, with an AD recording the principle exception (not a
> behavioral divergence).** F-011 + clj-parity are the binding invariants, and
> only Alt A satisfies them with zero behavioral DIFF. The permanent_no_op
> collision resolves on inspection: that principle guards against cljw hiding its
> OWN unimplemented semantics behind a success return — it does not force cljw to
> *diverge from clj* to be louder than the reference. Alt B inverts the priority
> order (elevates the letter of a depth-4 heuristic above an F-NNN/F-011
> invariant). The AD's derives_from is F-011; its body records the audited
> permanent-no-op exception; ADR-0155's "no AD / AD-007 covers it" is corrected.

The main loop adopted Alt A. One refinement the loop added that the DA could not
see from outside: under Alt A `(await a)` after shutdown drops its barrier and so
**hangs forever** (clj-faithful — clj's `CountDownLatch` never trips either), so
no e2e exercises await-after-shutdown. The realized AD-046 also pins the
handler-routing edge the DA flagged in Alt C: the oracle confirmed clj fires a
set `:error-handler` with a `RejectedExecutionException` on the dropped send;
cljw drops without firing it (no exception type to synthesize).

## Consequences

- The deprecated-but-real surface (`agent-errors`/`clear-agent-errors`) +
  `*agent*` + `release-pending-sends` + a faithful `shutdown-agents` round out
  agent parity for ported code.
- One AD (AD-045) documents the no-executor divergence so it reads as designed.
- `*agent*` adds a dynamic-var binding in the drainer (small, real capability).
- `shutdown-agents` adds a process-global flag checked in the send path; faithful
  to clj's process-wide, irreversible pool shutdown.

## Revision history

- 2026-06-20: created; classifies the D-442 legacy/executor surface. DA fork
  revised two borderline calls: `send-via` silent-ignore → raise (a passed
  executor is observable); `shutdown-agents` no-op → real (flag + send-path
  reject). Alt B (DispatchFn seam) rejected — cljw has no executor type to make
  the setters real. Part 1 landed: the three executor raises (AD-045) +
  `agent-errors`/`clear-agent-errors` sugar.
- 2026-06-20 (part 2): landed `*agent*` (drainer binds it around each action via a
  cached `rt.agent_var`), `release-pending-sends` (flush `nested_pending` + re-arm
  to empty, return count), and `shutdown-agents`. **Premise correction**: the
  part-1 "`shutdown-agents` rejects/throws, no AD" claim was factually wrong (clj
  DROPS the post-shutdown send without throwing). A second DA fork validated
  drop-vs-throw → DROP (Alt A, F-011 priority); the landed behaviour is the
  clj-faithful silent drop, scoped by the new **AD-046** (handler-routing edge).
  No `agents_shut_down` catalog Code was added (the drop needs no error).

## Affected files (implementation plan)

- `src/lang/clj/clojure/core.clj` — `agent-errors` (`(when-let [e (agent-error a)]
  (list e))`) / `clear-agent-errors` (`(restart-agent a @a)`) defns.
- `src/lang/bootstrap.zig` — intern `clojure.core/*agent*` `^:dynamic` (root nil)
  + cache `rt.agent_var` (mirrors `*ns*` / `*data-readers*`, so the Layer-0 drainer
  can reach the Var pointer; NOT a core.clj `def`, which the drainer can't cheaply
  resolve). `src/runtime/runtime.zig` — the `agent_var` cached slot.
- `src/lang/primitive/agent.zig` — `release-pending-sends` primitive (flush
  `nested_pending`, return count), `shutdown-agents` (set the flag, nil), the three
  executor-shaped fns (raise the no-executor error).
- `src/runtime/agent.zig` — a process-global `agents_shut_down` flag set by
  `shutdown-agents` + checked in `enqueueDirect` (DROP new dispatches after
  shutdown, no throw); `releasePending` (re-arm-to-empty flush); bind `*agent*`
  around each action body in the drainer.
- `src/runtime/error/catalog.zig` — the `agent_executor_unsupported` Code (the
  no-configurable-executor message). No `agents_shut_down` Code — the post-shutdown
  drop is a clj-faithful no-op (returns the agent), so there is no error to raise.
- `.dev/accepted_divergences.yaml` — AD-045 (executor raises) + AD-046
  (post-shutdown drop / handler-routing edge), each pinned.
- e2e (`test/e2e/phase16_agent.sh`) for the implemented surface.
