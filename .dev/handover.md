# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (`cw-from-scratch`). Gate green 250/0 (Mac, serial-e2e).
  debt ledger = `.dev/debt.yaml`. Active plan = **ADR-0089 re-cut (A→B→C)**.
- **First commit on resume MUST be**: **Phase B #6 — agent slice 2: error modes**
  (`:continue`/`:fail` + `agent-error` + `restart-agent`). The agent FIRST slice
  (ADR-0093) is landed; an action that throws currently continues silently
  (`:continue`), but clj's no-handler default is `:fail` — an **F-011 gap** to
  close (a thrown action must fail the agent + `agent-error` returns the error +
  `restart-agent` clears it). Then agent watches/validator (with the ADR-0093
  Alt 2 shared-IRef extraction decision), `await-for`, `send-via`, STM
  send-deferral, `*agent*`, `shutdown-agents`. The Phase B concurrency PRIMITIVES
  are otherwise complete + gated (see Recently landed): GC handshake, real-thread
  `future`/`promise`/`delay`, full STM, `locking` (ADR-0092), atomic
  atom/volatile/ref, and the agent core — all clj-verified, a ReleaseSafe
  concurrency-stress step guards the lost-update class. rework-OK + test guards
  (F-002); each src commit gates `--serial-e2e`. Cold-start: `private/notes/`
  `phaseB-6-agent.md` + `phaseB-concurrency-atomicity-sweep.md` +
  `phaseB-6-agent-survey.md`.
- **Forbidden this session**: turning auto-collect ON before the **#4a'**
  runtime-wide fabrication-window + in-txn-map GC-root audit (collect stays
  explicit/test-triggered; the safepoint + per-thread root publication are wired
  so any collect is safe, but the in-txn `vals`/`commutes` maps + a future's
  result are NOT yet a GC root source); editing `.claude/rules/*` (permission
  classifier blocks it as self-mod — surface to user, see memory); "fixing" an
  AD-001..013 accepted divergence (AD-013 = STM no-barge, landed); re-opening
  landed work (git log = SSOT); perf without a Release `scripts/perf.sh` number;
  trusting `~/Documents/OSS/zig` for 0.16 API (post-0.16 master — wrong tree; use
  pinned nix-store std / cw v0).

## Active plan — ADR-0089 post-M re-cut (2026-06-04)

```
Phase A  Consolidation — doc/guard drift sweep + exhaustive comment-drift sweep.
Phase B  KNOWN-unimplemented CORE, concurrency-led (D-242): §7 redesign vs Zig
         0.16 FIRST, then STM-txn / agent / locking / real-threading / Thread +
         arrays (F-004) / *out*·in·err (D-238) / with-local-vars (D-237) /
         reflection. finished-form, rework-OK with test guards. North star =
         user-observable parity, internals free (F-011 §2 + no_jvm).
Phase C  Library-driven gap-hunt (was the quality loop) on the concurrency base;
         workaround remediation folds in here.
```

## Recently landed (git log = SSOT)

**Phase B concurrency PRIMITIVES complete** (ADR-0090/91/92/93), all clj-verified
+ a ReleaseSafe `phase16_concurrency_stress.sh` step (loops each invariant ×20,
catching the rare lost-update class). (1) **GC STW handshake** + thread-major
`thread_roots` walk + `safepoint.zig`. (2) **Real-thread `future`/`promise`/
`delay`**. (3) **STM** (`lock_tx.zig`) — `dosync`/`ref-set`/`alter`/`commute`/
`ensure`, multi-ref, deadlock-free; AD-013. (4) **`locking`** (ADR-0092,
`object_monitor.zig`) — header `lock_state` spinlock + threadlocal reentrancy +
safepoint-poll; Option C blocking inflation = D-245. (5) **`agent` first slice**
(ADR-0093, `agent.zig`) — serial single-drainer handoff, leaf-lock gpa queue,
latch `await`. **Two real memory-ordering races found + fixed (ReleaseSafe-only,
Debug masks them)**: the STM `doGet` stale read (now reads under the Ref lock) and
the atom being non-atomic (`swap!`→CAS-retry, `current`/`compare-and-set!` atomic,
`swap-vals!`/`reset-vals!` CAS-retry; volatile/ref reads synchronized). D-246 =
remaining low-freq metadata visibility (atom watches/validator, var root).

## Open carry-overs (actionable)

- **3 rules** carry a stale `src/runtime/host/**` glob (→ `runtime/java/**`, ADR-0029);
  the cleanup Edit was declined by the permission classifier as agent-config
  self-mod — awaits user authorization (harmless; rules still load via other
  globs). Memory `claude-rules-edit-permission-block`.
- **D-243** = 8 re-opened deferrals: host-surface impls D-048/105/106 (Phase C) ·
  bench D-104 · regex/string D-054/056/057 · D-049 (user-owned F-NNN).
- **D-244** = the **#4a' hardening** (the capstone, high-risk): `gc_self_guard`
  setters at the fabrication sites + GC-root publication for the in-txn maps /
  future result / agent action-fabrication window + per-thread registration audit
  (the `locking` safepoint-poll + agent drainer share it) + turning auto-collect
  ON — all dormant while nothing fires a collect. **D-245** = `locking` Option C
  blocking-monitor inflation. **D-246** = low-freq concurrency-metadata visibility.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (Phase B/C source work only): `timeout 1800 bash test/run_all.sh
  --serial-e2e` (~5min; -P8 over-runs under load). Doc-only = no gate.
- Never poll a bg gate. `clj -M -e` → `timeout 20` + bound infinite seqs. Speed
  ONLY via `scripts/perf.sh`. Edit/Write TRANSCODES literal non-ASCII (keep source
  ASCII; splice non-ASCII doc edits via python). Default backend = VM (F-012).
- Swept fake GC test Cells use a finaliser-free tag (`.vector`), NOT `.string`
  (its finaliser reads a data ptr a 16-byte fake Cell lacks → crash).

## Cold-start reading order (tracked-only)

handover → `private/notes/phaseB-6-agent.md` (latest; agent + next-task cluster) +
`phaseB-6-agent-survey.md` → **`.dev/decisions/0093_agent_serial_executor.md`**
(agent + DA) + **`0092_heap_value_monitor_locking.md`** (locking) +
**`0090_phase_b_concurrency_redesign.md`** (§3 STM + Alt B spine) →
**`.dev/debt.yaml` D-244** (#4a' capstone) + D-242 → ROADMAP §9.2.R/§7 → CLAUDE.md
(§ Project spirit + Autonomous Workflow + The only stop) → `.dev/project_facts.md`
(F-002/004/005/006/009/011/012) → `.dev/principle.md`.
