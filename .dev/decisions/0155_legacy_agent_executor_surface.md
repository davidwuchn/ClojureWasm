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

| Function                                              | Disposition                | Rationale                                                                                          |
|-------------------------------------------------------|----------------------------|----------------------------------------------------------------------------------------------------|
| `agent-errors`                                        | **implement**              | clj-deprecated 1.2; pure sugar over the existing `agent-error` (`(when-let [e …] (list e))`).      |
| `clear-agent-errors`                                  | **implement**              | clj-deprecated 1.2; `(restart-agent a @a)` — both halves exist.                                    |
| `*agent*`                                             | **implement**              | the drainer knows `a`; bind `*agent*` around each action body (clj's `binding [*agent* a]`).       |
| `release-pending-sends`                               | **implement**              | the `nested_pending` buffer EXISTS — flush it + return the count (v0's `return 0` would now lie).   |
| `shutdown-agents`                                     | **implement (real)**       | flip a process-global `agents_shut_down` flag; the send path then rejects new sends (clj's "no new actions accepted"). Detached drainers already don't block exit, so the exit semantic also holds — fully faithful, no AD. |
| `send-via` / `set-agent-send-executor!` / `set-agent-send-off-executor!` | **accept-divergence (raise)** | cljw exposes NO executor object (no `java.util.concurrent.ExecutorService` to construct or pass), so there is nothing real to thread/configure. Silently ignoring the user's explicit executor is a masked-semantic lie (DA finding); raise an explicit "cljw has no configurable executor" error → AD-045. |

The `implement` group is real behaviour. The three executor-shaped functions all
raise: cljw genuinely has no executor concept, so neither a no-op (would mask the
dropped semantic) nor a real impl (would require a `java.util.concurrent` pool
subsystem cljw deliberately lacks) is honest — the explicit error is.

New AD: **AD-045** (the three executor-shaped fns raise — cljw exposes no
configurable executor). `shutdown-agents` needs no AD: the flag makes it faithful
(post-shutdown sends reject, exit unblocked); only the error *Kind* on a rejected
send differs, which the existing AD-007 covers.

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
   `agents_shut_down` flag the send path checks, reproducing clj's reject-subsequent
   -sends exactly. No F-006 interaction (a flag, not a thread/lock).

The four `implement (real)` calls (`agent-errors`/`clear-agent-errors`/`*agent*`/
`release-pending-sends`) were uncontested by the DA.

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
  the setters real.

## Affected files (implementation plan)

- `src/lang/clj/clojure/core.clj` — `agent-errors` (`(when-let [e (agent-error a)]
  (list e))`) / `clear-agent-errors` (`(restart-agent a @a)`) defns;
  `(def ^:dynamic *agent* nil)`. `send-via` + the two executor setters raise via a
  thin rt primitive (or a `clojure.core` defn that throws the catalog error).
- `src/lang/primitive/agent.zig` — `release-pending-sends` primitive (flush
  `nested_pending`, return count), `shutdown-agents` (set the flag, nil), the three
  executor-shaped fns (raise the no-executor error), `*agent*` var interning.
- `src/runtime/agent.zig` — a process-global `agents_shut_down` flag set by
  `shutdown-agents` + checked in `enqueueDirect` (reject new sends after shutdown);
  bind `*agent*` around each action body in the drainer.
- `src/runtime/error_catalog.zig` — a `agent_executor_unsupported` Code (the
  no-configurable-executor message) + an `agents_shut_down` reject Code.
- `.dev/accepted_divergences.yaml` — AD-045 (+ pin).
- e2e + corpus for the implemented surface.
