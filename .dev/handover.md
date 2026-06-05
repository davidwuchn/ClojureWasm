# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: pushed `7932d65e` (set! runtime thread-bound gate + clojure.main-
  style baseline binding frame, ADR-0096 / D-254). Active plan = ADR-0089
  (A->B->C), Phase B. The add-watch-IRef (atom/agent/ref/var) + set!-parity
  cluster is DONE.
- **First commit on resume MUST be**: the **zwasm v2 relative-path import spike
  — D-037 TRIGGER (user directive 2026-06-05, F-001 Revision).** The current
  cluster is done, so this user-wired trigger fires now (it was Phase-16-locked).
  Execute D-037's steps: (0) **guardrail FIRST** — zwasm v2
  (`~/Documents/MyProducts/zwasm_from_scratch`) is under active AI dev; `/add-dir`
  it, confirm `git log -1` + `zig build` there are at a usable/stable point, and
  **back off + re-defer with a dated note (no thrash) + do NOT pin** if mid-
  rewrite; (1) add it to `build.zig.zon` as a relative-path dep **behind
  `-Dzwasm-spike`** so the default gate never depends on zwasm; (2) minimal Zig-
  API smoke (Engine.init(cw allocator, F-006 separate spaces) -> load/instantiate/
  invoke a tiny wasm); (3) verify the 5 D-038 spec items directly in-repo; (4)
  report -> informs D-036 inline-vs-Pod (still Phase 16). Full FFI stays Phase 16.
- **Forbidden this session**: **pinning an in-progress zwasm v2 state** (D-037
  guardrail); turning auto-collect ON (user-owned #4a'); editing .claude/rules/*
  (permission-blocked -- surface to user); re-opening landed work (git log =
  SSOT); trusting ~/Documents/OSS/zig for 0.16 API.

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

**add-watch IRef generalization + set! parity** (git log = SSOT). add-watch/
remove-watch now span atom/agent/ref/var via the shared `iref.notifyWatches`
SSOT; `Var.watches` is GC-walked only via the ns_vars root walk (a var_ref is
GC-membrane-filtered). **ADR-0096 / D-254**: `set!` became a JVM-`Var.set`
parity runtime thread-bound gate in both backends (raise on unbound, never
setRoot; removed the analyze-time dynamic check that raced the eval-time flag +
the silent root-write) + a process-lifetime clojure.main-style **baseline
binding frame** (bootstrap, 8 existing standard config/print vars) so top-level
`(set! *warn-on-reflection* true)` works for the right reason. Env.deinit nulls
the threadlocal current_frame so the arena-owned frame can't dangle across
setupCore tests. Partial D-241 discharge (8 of ~21 baseline vars).

## Open carry-overs (actionable)

- **3 rules** carry a stale `src/runtime/host/**` glob (ADR-0029); the cleanup Edit
  is permission-blocked as self-mod (memory `claude-rules-edit-permission-block`).
- **D-243** = 8 re-opened deferrals: D-048/105/106 (Phase C) · D-104 · D-054/056/057 · D-049 (user-owned F-NNN).
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

handover → **`.dev/gc_rooting.md`** (the GC-rooting SSOT) + **`.dev/debt.yaml`
D-253/252/251** (the torture-green campaign + closed classes) +
`private/notes/torture-full-sweep-gaps.txt` (the 38-gap inventory) →
**`.dev/decisions/0094_*`/`0095_*`** (the rooting ADRs) → **`.dev/project_facts.md`
F-004/F-006/F-011** → CLAUDE.md (§ Project spirit + The only stop) →
`.dev/principle.md`.
