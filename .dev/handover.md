# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (`cw-from-scratch`). Gate green 251/0 Mac + 250/0 Linux
  x86_64 (serial-e2e). debt = `.dev/debt.yaml`. Active plan = **ADR-0089 (A→B→C)**.
- **First commit on resume MUST be**: **D-253 torture-green campaign, cluster (a)**
  — the dynamic-var / binding-frame torture gaps (atom_watch 5 / with_redefs 4 /
  thread_bindings 3 / clojure_test 8 / with_open 2; ~20 of 38). Start at
  `root_set` `current_frame` + `atom.zig` watches/validator rooting (add-watch
  closure swept across `swap!` → `type_error`); a single shared-cause fix likely
  clears the cluster. THEN cluster (b) seq-realisers (partitionv/seq_tail/…, the
  EvalFrame exemplar) · (c) multimethod(C7)/syntax_quote/string_misc. Re-run
  `CLJW_GC_TORTURE=1 bash test/run_all.sh --serial-e2e` after each cluster; add
  closed programs to `test/e2e/phase16_gc_torture.sh`. Full inventory:
  `private/notes/torture-full-sweep-gaps.txt`. Heap-tag stays **64 slots** (F-004
  Rev 2026-06-05). src commits gate `--serial-e2e`. SSOT for the whole rooting
  surface: **`.dev/gc_rooting.md`** + `GC-ROOT:` markers; the D-252 latent
  candidates (C1/C4/C5) don't reproduce. Cold-start: `.dev/gc_rooting.md` +
  D-251/252/253 + `private/notes/phaseC-d251-root-cause.md`.
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
