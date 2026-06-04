# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (`cw-from-scratch`). Gate green 246/0 (Mac, serial-e2e).
  debt ledger = `.dev/debt.yaml`. Active plan = **ADR-0089 re-cut (A→B→C)**.
- **First commit on resume MUST be**: continue **Phase A (consolidation)** per
  ADR-0089 — the comment-drift sweep is DONE (db3932e7 + fecdd248). Remaining
  Phase A housekeeping: the conservative **guard pass** (dead/redundant rules /
  scripts / ADRs only — 中庸) + **ROADMAP closed-phase archive-extract** (2607
  lines → smaller). Then close Phase A → **Phase B (D-242)** entry with its
  §7-redesign ADR + Structural-imagination + DA-fork. Phase A doc/scaffold = no
  per-item gate; a full `--serial-e2e` gate is still required on any src/ commit
  (the gate-cadence hook enforces it even for comment-only shared-line edits).
- **Forbidden this session**: cold-seizing **Phase B** (D-242, concurrency-led
  core) without its §7-redesign ADR + Structural-imagination + DA-fork at entry
  (spike the Zig-0.16 primitive first, principle.md). Also forbidden: minting a
  new F-NNN to restate F-011 (the F-013 idea was DROPPED — ADR-0089); adding a
  new rule/skill/audit-section where folding into an existing home works
  (compress-guards); "fixing" an AD-001..012 accepted divergence; re-opening
  landed work (git log = SSOT); perf without a Release `scripts/perf.sh` number.

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

Restores §9.2.R's Phase-15-first intent (the session had drifted by running the
quality loop pre-Phase-15). The clean-bounded clj-parity frontier is drained.

## Phase A work items

- DONE: exhaustive comment-drift fan-out (12 fresh-context subagents, one per
  `src/` subtree; catalogs in `private/comment-drift-2026-06-04/`). 121 files
  comment-only re-cut to finished form (db3932e7, gate green 246/0): module
  docstrings frozen at skeleton/early-phase scope, factual drifts (gc field
  shape, allocator names, dead `gc_mutex`/Code refs, class_name list), and
  concurrency `Phase 15`→`Phase B` renames. (b) inventory promoted to D-242;
  (c) fixed. Discharged-section audit (fecdd248): 141 rows = 86 resolved / 47
  parked-correctly / **8 fired-trigger-but-unbuilt** re-opened under **D-243**
  (D-048/104/105/106 HARD = Phase C host-surface+bench; D-054/056/057 soft;
  D-049 user-owned F-NNN). No false-discharge lies — Defer-to-amnesia only.
- **NEXT**: remaining Phase A housekeeping — conservative **guard pass**
  (dead/redundant rules/scripts/ADRs, 中庸) + **ROADMAP closed-phase
  archive-extract** (2607 → smaller). LOW: debt discharged-in-active compaction
  (clutter-only now D-243 captured the actionable rows; watch false-positives
  like D-210 standing-floor). After Phase A closes → **Phase B (D-242)**.

## Landed before the re-cut (git log = SSOT; one summary)

Post-M quality stream: random-sample · partitionv · the print-control var cluster
(`*print-length*`/`*print-level*`/`*print-namespace-maps*`/`*print-readably*`/
`*print-meta*` all bindable, ADR-0088 + DA-fork; deepRealize meta-preserve fix;
infinite-seq×*print-length* termination D-222 b) · regex `\p{}` POSIX classes +
`\s` \x0B fix + scoped `(?i:)`/`(?s)`/`(?m)` flags · thread-binding machinery
(`with-bindings`/`bound-fn`, D-241) · debt quality_floor hygiene.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (Phase B/C source work only): `timeout 1800 bash test/run_all.sh
  --serial-e2e` (~5min; -P8 over-runs under load). Phase A doc/scaffold = no gate.
- Never poll a bg gate. `clj -M -e` → `timeout 20` + bound infinite seqs. Speed
  ONLY via `scripts/perf.sh`. Edit/Write TRANSCODES literal non-ASCII (keep source
  ASCII; splice non-ASCII doc edits via python). Default backend = VM (F-012).
- comment-drift sweep + spike-mode are FOLDED into §E2.7 + principle.md (ADR-0089
  DA verdict) — NOT new mechanisms.

## Cold-start reading order (tracked-only)

handover → `.dev/decisions/0089_recut_concurrency_and_drift_methods.md` (the active
plan) → ROADMAP §9.2.R/§7 → `.dev/debt.yaml` (D-242 Phase-B anchor + D-238/D-239/
D-241) → CLAUDE.md (§ Project spirit + Autonomous Workflow + The only stop) →
`.dev/project_facts.md` (F-002/004/005/009/011/012) → `.dev/principle.md`.
