# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (`cw-from-scratch`). Gate green 251/0 Mac + 250/0 Linux
  x86_64 (serial-e2e). debt = `.dev/debt.yaml`. Active plan = **ADR-0089 (A→B→C)**.
- **First commit on resume MUST be**: **D-244 #4 — the multi-thread future-worker
  torture hang/crash**. The single-thread GC-torture campaign is RESOLVED (D-253:
  all 38 full-suite-sweep gaps fixed; the confirmation run is 0 DRIFTs/0 panics
  through the diff corpus + single-thread e2e). The confirmation run then
  HUNG/crashed in `e2e_phase14_future_promise_delay`: `(future (reduce + (range
  1 100)))` torture-hangs (124), `(mapv #(future (* % %)) (range 1 5))` crashes
  (134). A WORKER thread's torture back-edge poll triggers a MULTI-THREAD STW
  collect = the D-244 #4 dormant / highest-risk path (real threads + safepoint
  STW + worker root publication); ADJACENT to the user-owned auto-collect-ON
  decision. Investigate the worker-side rooting + the STW handshake under a
  WORKER-initiated collect. Repro: `CLJW_GC_TORTURE=1 zig-out/bin/cljw -e '(let
  [f (future (reduce + (range 1 100)))] @f)'`. Single-thread fixes = ADR-0094/0095
  + D-252/253; heap-tag stays **64 slots** (F-004). src commits gate
  `--serial-e2e`. SSOT for the rooting surface: **`.dev/gc_rooting.md`** (§A/E) +
  `GC-ROOT:` markers. Cold-start: `.dev/gc_rooting.md` + D-253/244/250 +
  `private/notes/torture-full-sweep-gaps.txt`.
- **Forbidden this session**: turning auto-collect ON (collect stays explicit/
  test-triggered). The safepoint + per-thread root publication + the in-txn-map
  rooting (self+worker) + the fabrication-window audit are now ALL done — so any
  EXPLICIT collect is safe — but the auto-collect-ON flip is the remaining highest-
  risk step (a full runtime-wide root re-audit + user-awareness first; it can
  destabilize the whole runtime); editing `.claude/rules/*` (permission
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

**GC-torture root-cause campaign + the GC-rooting SSOT** (git log = SSOT;
ADR-0094/0095). 10 swept-intermediate classes fixed: Function.header@0, reduce
(EvalFrame), persistent-waypoint mark-membrane (`clearPersistentMarks`), bytecode
constant pool (`EvalFrame.constants`), the `isGcManaged` membrane SSOT (Alt D),
dormant fn chunk constants, defprotocol, C9 CLI-print pin, C2/C3 every?/some?
cursors, C6 clojure.walk rebuild accumulators. Delivered `.dev/gc_rooting.md`
(SSOT for every rooting site + moving-GC migration checklist) + `GC-ROOT:` markers
+ D-252. The FIRST full-suite torture sweep (D-250 tier-2) then found **38 more
DRIFTs in 12 areas** → D-253 (the next campaign; clustered, cluster (a) first).

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
