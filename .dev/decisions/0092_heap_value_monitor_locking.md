# ADR-0092 — Heap-value monitor for `locking` (header spinlock skeleton toward thin→fat inflation)

- Status: Proposed → Accepted (2026-06-05)
- Phase: B (concurrency), task #6
- Supersedes / Amends: realises the ADR-0009 `lock_state`-bit reservation
- Related: ADR-0090 (Phase B concurrency redesign), ADR-0091 (thread_roots
  GC walk), F-004 (NaN-box), F-006 (mark-sweep, no write barrier), F-011
  (behavioural equivalence), F-012 (VM backend)

## Context

`(locking obj body...)` must give Clojure's monitor semantics: **mutual
exclusion** across threads, **reentrancy** (the same thread re-acquires
without deadlock), and release on normal-or-error exit. JVM clj maps it to
an object's intrinsic monitor (reentrant + blocking). cljw has no JVM
object monitor; ADR-0009 reserved the heap header's `lock_state` (2 bits of
the `gc_and_lock` u32, the other 30 being `gc_mark`) for exactly this.

The design question: how to build a per-object monitor on an **arbitrary
heap value** under cljw's stop-the-world mark-sweep GC (F-006) where the
lock word shares a u32 with the GC mark.

## Decision

**Finished form = Option C (thin→fat inflation).** A `lock_state=1` thin
lock (a header CAS) for the uncontended fast path; on contention it
inflates to `lock_state=2` + an off-heap blocking monitor cell
(`Io.Mutex`/`Io.Condition`, owner-tid + recursion-count, allocated and
finalised like `FutureCell`, keyed in a side-table by the heap pointer —
stable because GC is non-moving, F-006). A contended waiter then BLOCKS
(OS-park) instead of spinning. This is clj's actual monitor shape and the
F-011-clean target (blocking-not-spinning is observable when a lock holder
itself blocks).

**This ADR lands Option A — Option C's uncontended fast path — as a
genuine, non-throwaway skeleton** (`runtime/concurrency/object_monitor.zig`):

1. **Header spinlock.** `enter` CASes `lock_state` 0→1 on the `gc_and_lock`
   u32, **preserving the gc_mark bits** (CAS the whole u32, set only the
   low 2 bits). `exit` CASes back to 0.
2. **Safepoint-polling spin (the #1 correctness rule).** The acquire spin
   is non-allocating, so it **polls `safepoint.gc_requested` and `park()`s
   every iteration**. Without this a concurrent stop-the-world collect's
   `stopWorld` waits forever for a park that never comes — a guaranteed
   deadlock against the GC, strictly worse than the contention spin. (The
   gc_mark-write vs lock CAS cannot otherwise race: the collect is STW, so
   no CAS is in flight during the mark window.)
3. **Reentrancy via a threadlocal held-set.** A fixed `[32]` per-thread
   array of (obj, depth). A re-acquire of an already-held object bumps the
   depth (no second CAS, no deadlock); the outermost `exit` clears the
   header bit. The held-set is **not** a GC root source — the locked object
   is already rooted via the `EvalFrame` operand-stack/locals walk
   (ADR-0091) for the body's duration; the set only counts re-entries.
4. **Immediates error.** `(locking <immediate>)` has no `HeapHeader` to
   lock → a clean `locking requires an object with identity` error
   (AD-014, derives_from F-004), where JVM clj locks the box.

Surface: the `locking` macro expands to `(__locking obj (fn* [] body...))`
(mirrors `dosync`); the `__locking` primitive holds the monitor across the
body thunk with a `defer` release (try/finally semantics).

Option A is a **clean subset** of Option C: the gc_mark-preserving header
CAS, the safepoint-poll discipline, and the reentrancy held-set carry
forward into Option C unchanged — C only ADDS the 1→2 inflation + the
off-heap cell + the side-table. So landing A shrinks the C rewrite (per the
project spirit's "each skeleton must shrink the final-form rewrite"), and A
itself ships a correct, reentrant, GC-safe, clj-result-equivalent
`locking`. The only gap vs C is blocking-vs-spinning under contention — a
resource divergence (identical committed results; the clj-diff oracle sees
no DIFF), tracked as **D-245**.

## Alternatives considered (Devil's-advocate subagent, fresh context, verbatim)

> ### Alt 1 (smallest-diff): Bare-header spinlock, NO reentrancy — better:
> minimal; the lock_state CAS + safepoint-poll spin is the smallest thing
> that gives mutual exclusion across threads, no threadlocal bookkeeping.
> breaks: NON-REENTRANT — `(locking x (locking x ...))` or any re-entrant
> code path (a method calling a `locking`-guarded helper on the same object)
> SELF-DEADLOCKS. clj guarantees reentrancy; this silently regresses it (a
> permanent-no-op-class lie: looks like it locks, deadlocks the same
> thread). Rejected — violates F-011 behavioural equivalence (reentrancy is
> user-observable).
>
> ### Alt 2 (finished-form-clean): Off-heap blocking monitor cell + thin
> header inflation (= Option C, JVM thin→fat) — better: this is the actual
> clj finished form. `lock_state=1` (thin) is Option A's fast uncontended
> CAS path; on contention it inflates to `lock_state=2` + an off-heap
> `Monitor{ Io.Mutex, Io.Condition, owner_tid, recursion_count }` cell
> (allocated/tracked exactly like `FutureCell` — off-heap infra alloc, tied
> to the heap object, freed by a finaliser, side-table `obj-ptr → *Monitor`).
> A contended waiter BLOCKS on the Io.Condition (OS-park) instead of
> spinning, so it does NOT burn a core and does NOT livelock when the holder
> itself blocks (the holder parked in `future`/`promise` `deref` still owns
> the monitor; the waiter sleeps and is woken on release). Reentrancy is the
> `owner_tid` + `recursion_count` in the cell — exactly clj's monitor.
> breaks: more machinery (a thread-safe side-table keyed by heap pointer +
> GC cleanup of dead monitor entries on sweep; `Io.Mutex.lock` needs `io`
> threaded through). The side-table must survive the locked object moving —
> cljw GC is non-moving mark-sweep (F-006), so the pointer key is stable;
> OK. This is the recommended finished form.
>
> ### Alt 3 (wildcard): Park-on-the-safepoint-condition spinlock (no separate
> monitor cell) — better: reuses the EXISTING `safepoint` park/condition
> machinery instead of allocating a per-object cell; a contended `locking`
> waiter registers interest and waits on a shared lock-wait condition (woken
> on any `monitor-exit`), so it blocks (not spins) with zero new heap
> allocation and zero side-table. breaks: thundering-herd (every release
> wakes ALL lock-waiters, who re-contend — O(waiters) wakeups per release);
> no per-object fairness/owner tracking without a side-table anyway, so
> reentrancy still needs a threadlocal held-set; and entangling the GC
> safepoint condition with user-level lock contention risks priority
> inversion against a pending collect (a lock-waiter parked on the GC
> condition could delay `stopWorld`). Interesting but the entanglement with
> the STW path is a correctness hazard. Rejected.
>
> ### Recommendation: Option C (= Alt 2), with Option A as a genuine
> non-throwaway skeleton — Option A's header `lock_state=1` thin-lock CAS
> (preserving gc_mark, polling the safepoint each spin) IS Option C's
> uncontended fast path verbatim; Option C only ADDS the `lock_state=1→2`
> inflation + off-heap blocking cell on contention. So Option A is a clean
> SUBSET of Option C, not a dead-end — landing A first shrinks the C rewrite.
> Per F-002 (finished-form wins, diff size is not a constraint) and F-011
> (blocking, not spinning, is user-observable), the finished form is C; A is
> the endorsed first skeleton toward it.
>
> The single most important correctness risk in Option A the main loop MUST
> handle: the spin loop is non-allocating, so it MUST call `safepoint.park()`
> (or poll `safepoint.gc_requested` and park) on EVERY spin iteration —
> exactly like the VM back-edge poll. If it spins on the bare CAS without the
> safepoint poll, a concurrent collect's `stopWorld` blocks forever (the
> spinner never parks) → the whole runtime hangs. Secondary, also
> load-bearing: the CAS must `cmpxchg` the WHOLE u32 to preserve `gc_mark`,
> and `(locking <immediate>)` must error since immediates have no header.
> Note the held object does NOT need pinning — it is already a GC root via
> the EvalFrame operand-stack/locals walk (ADR-0091) for the body's duration.
>
> ### F-NNN check: NONE violated. Alt 1 (non-reentrant) would VIOLATE F-011
> (reentrancy is user-observable) — recorded as the leading rejected
> alternative.

The main loop adopted the DA's exact recommendation: **Option A now** (with
the three load-bearing risks — safepoint-poll, whole-u32 CAS, immediate-
error — all handled), **Option C tracked as D-245.** Choosing A as the
first skeleton is the DA's prescribed A-then-C path, not a cycle-budget
defer: A is F-NNN-complete (correct results, reentrant, GC-safe), and the
only gap (spin-vs-block) is a resource divergence with no F-NNN requiring C
*now* (F-011 is result-parity; A's results match clj).

## Consequences

- `(locking obj body)` works: mutual exclusion (a concurrent non-atomic RMW
  under the lock lands all 400 increments), reentrancy (no deadlock), body
  closes over the lexical env, releases on error.
- A contended waiter spins (polling the safepoint) rather than parks → wastes
  a core while waiting. Acceptable for short critical sections; the blocking
  inflation is D-245. **Not** observable in committed results (no clj DIFF).
- `monitor-enter` / `monitor-exit` are not exposed as separate primitives
  (clj special forms); `locking` is the whole surface. Add later if needed.
- The safepoint-poll in the spin is correct only once every cljw-running
  thread is registered with the safepoint (so `park()` accounting is sound).
  Today auto-collect is OFF, so `gc_requested` is never set during locking
  and the poll is dormant; the main-thread/worker registration audit rides
  the **#4a' hardening** (D-244) before auto-collect turns ON.

## Affected files

- `src/runtime/concurrency/object_monitor.zig` (new) — the impl.
- `src/lang/primitive/locking.zig` (new) — the `__locking` primitive.
- `src/lang/macro_transforms.zig` — `expandLocking` + the `locking` BOOTSTRAP
  entry.
- `src/lang/primitive.zig` — register the locking primitive.
- `src/runtime/error/catalog.zig` — `locking_needs_object` /
  `locking_nest_overflow` / `locking_form_incomplete`.
- `src/main.zig` — test-aggregator import for `object_monitor.zig`.
- `test/e2e/phase16_locking.sh` (new) + `test/run_all.sh` registration.
- `.dev/accepted_divergences.yaml` — AD-014 (immediate errors).
- `.dev/debt.yaml` — D-245 (Option C blocking-monitor inflation).
