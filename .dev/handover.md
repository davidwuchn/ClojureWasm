# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: pushed `51750c54` (with-local-vars, ADR-0097 / D-237). Active plan =
  ADR-0089 (A->B->C), Phase B. DONE this session: add-watch-IRef (atom/agent/ref/
  var) + set!-parity (ADR-0096) + the zwasm v2 relative-path import spike (D-037,
  consumable, no issues) + with-local-vars (ADR-0097, Env-owned anon Vars).
- **First commit on resume MUST be**: **D-256 — the Clojure/conj 2026 CFP campaign
  (TOP PRIORITY, deadline-driven, user 2026-06-06).** Start by **reading BOTH
  `private/clojure_conj_2026_cfp/PRIORITY.md` AND `…/CFP_v2.md` TOGETHER** (they
  are co-dependent), then execute PRIORITY.md's fully-sequential plan P0->P9 (no
  branching; top-down one at a time). **HARD DEADLINE 2026-06-14 23:59 ET;
  submission (P6) by 2026-06-13** (today 2026-06-06, ~7 days). The files are the
  SSOT — do not re-derive the plan; follow it. (Phase B leftovers — reflection,
  D-255 slotmap, owner-gated concurrency — yield to this until the CFP ships.)
- **Forbidden this session**: **tidying / cleaning the repo before the CFP submits**
  (PRIORITY.md P0 — the cleanup urge burns the deadline budget); **pinning an
  in-progress zwasm v2 state / using a zwasm tag or v1** (F-001 — v2 ONLY from the
  `zwasm-from-scratch` branch; wasm findings: zwasm-side = feedback note no-code,
  cljw-side = real fix); turning auto-collect ON (user-owned #4a'); editing
  .claude/rules/* (permission-blocked -- surface to user); re-opening landed work
  (git log = SSOT); trusting ~/Documents/OSS/zig for 0.16.

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

**with-local-vars** (ADR-0097 / D-237, 51750c54). `-create-local-var` mints
anonymous dynamic Vars on a sentinel `__local` ns; core.clj macro = let +
push-thread-bindings + try/finally pop. Anon Vars are Env-owned (`env.local_vars`)
+ freed at Env.deinit — NOT at the extent — so an escaped var_ref stays deref-safe
(Alt C; free-at-extent UAFs, never-free trips the DebugAllocator). Escaped deref
-> nil = **AD-015**; per-extent reclamation slotmap = **D-255**. clj-matched
12/20/3. Prior this session: **zwasm v2 embedding spike** (D-037/F-001, lazy
`build.zig.zon` dep behind `-Dzwasm-spike`, consumable, gate zwasm-free); **set!
JVM-Var.set parity** (ADR-0096/D-254: runtime thread-bound gate both backends +
baseline binding frame); **add-watch IRef** (atom/agent/ref/var).

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
`.dev/principle.md`. **For the CFP campaign (D-256, the resume task), read
`private/clojure_conj_2026_cfp/PRIORITY.md` + `CFP_v2.md` TOGETHER first.**

## Stopped — user requested

User instruction (2026-06-06): finish with-local-vars (done — 51750c54 / ADR-0097),
then **wire the Clojure/conj 2026 CFP as the next autonomous trigger** — "read
`PRIORITY.md` AND `CFP_v2.md` together, then begin investigation / planning / work"
(D-256; deadline 2026-06-14) — and **audit the wiring / reference chain so the next
clean session resumes normally via `/continue`.** Resume at **D-256** (read both
CFP files together, execute PRIORITY.md P0->P9 sequentially). This stop applies to
THIS session only; the next `/continue` deletes this section and resumes the loop.
