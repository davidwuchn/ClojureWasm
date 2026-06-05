# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: pushed `46203644` (cljw.http.server, ADR-0098). **edge-demo is LIVE**
  (https://clojurewasm-edge-demo.fly.dev/). Active plan = ADR-0089 (A->B->C),
  Phase B — but the CFP campaign (below) runs first.
- **First commit on resume MUST be**: **continue the Clojure/conj 2026 CFP campaign
  (D-256).** Read BOTH `private/clojure_conj_2026_cfp/PRIORITY.md` AND `…/CFP_v2.md`
  TOGETHER — both carry a **2026-06-06 PIVOT note: Fly + native cljw, NOT Cloudflare
  + wasm** (cljw serves HTTP itself via `cljw.http.server`; edge-demo LANDED). Then
  **execute PRIORITY.md IN FULL, P0->P9 — the deadline (2026-06-14; P6 submission by
  06-13) gates submission but is NEVER a reason to drop a later step; do ALL of it
  (AI speed is dramatically faster than it feels — user 2026-06-06).** CFP work spans
  repos: cljw (e.g. `cljw.http.server` request `:body` = D-257, for edge-demo CRUD —
  cljw gate applies), `clojurewasm/edge-demo` + `clojurewasm/playground` (their own
  commit/deploy, no cljw gate; `FLY_API_TOKEN` is in cljw `.envrc` via direnv, org
  `clojurewasm`; deploy = `fly deploy --remote-only`).
- **Never stop, never ask (user asleep 2026-06-06).** A step needing a user-only
  action (recording a demo, an account-level setting) → record a deferred note +
  **proceed to the next AI-doable step**; do NOT stop, do NOT ask (Direction-ask
  smell). **After PRIORITY.md is exhausted, transition autonomously to the cljw
  Phase B/C remaining work** (debt.yaml self-select per the loop) — never idle. The
  only stop is a NEW user-explicit stop.
- **Forbidden**: pinning an in-progress zwasm v2 state / a zwasm tag or v1 (F-001:
  v2 ONLY from `zwasm-from-scratch`; wasm findings = zwasm-side feedback-note
  no-code, cljw-side real fix); turning auto-collect ON (user-owned #4a'); editing
  .claude/rules/* (permission-blocked → surface); re-opening landed work (git log =
  SSOT); trusting ~/Documents/OSS/zig for 0.16.

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

**cljw.http.server** (ADR-0098, 46203644). cljw serves HTTP itself on Zig 0.16
std.Io.net + std.http.Server: `(cljw.http.server/run-server (fn [req] {:status N
:body "…"}) {:port P})`, Ring req `:request-method`/`:uri` (headers/body = D-257).
Surface = runtime/cljw/http/server.zig + runtime/cljw/_host_api.zig (the java
_host_api pattern; lang/primitive/* may not import a surface). Powered the **LIVE
edge-demo** on Fly (scratch ~3.7MB, native musl cljw — `clojurewasm/edge-demo`).
Prior this session: **with-local-vars** (ADR-0097/D-237, Env-owned anon Vars,
AD-015); **zwasm v2 spike** (D-037/F-001, lazy build.zig.zon dep behind
`-Dzwasm-spike`); **set! JVM-Var.set parity** (ADR-0096/D-254); **add-watch IRef**.

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

## Cold-start reading order (tracked-only)

handover → **`.dev/gc_rooting.md`** (the GC-rooting SSOT) + **`.dev/debt.yaml`
D-253/252/251** (the torture-green campaign + closed classes) +
`private/notes/torture-full-sweep-gaps.txt` (the 38-gap inventory) →
**`.dev/decisions/0094_*`/`0095_*`** (the rooting ADRs) → **`.dev/project_facts.md`
F-004/F-006/F-011** → CLAUDE.md (§ Project spirit + The only stop) →
`.dev/principle.md`. **For the CFP campaign (D-256, the resume task), read
`private/clojure_conj_2026_cfp/PRIORITY.md` + `CFP_v2.md` TOGETHER first.**

## Stopped — user requested

User instruction (2026-06-06, going to sleep): the edge-demo is LIVE + verified, so
hand off to **fully autonomous overnight execution**. Wired here: resume = **execute
the CFP campaign (D-256) PRIORITY.md IN FULL — do not abandon any step citing the
deadline (AI speed is dramatically faster than it feels); on a user-only-action
blocker, defer + proceed to the next step (never stop, never ask); after PRIORITY.md
is exhausted, transition autonomously to the cljw Phase B/C remaining work**. User
asked to audit the wiring / reference chain, commit+push, then stop THIS session.
The next `/continue` deletes this section and runs the wired plan to completion. The
only stop is a NEW user-explicit stop.
