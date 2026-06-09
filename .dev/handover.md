# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `7f12451c` (origin/cw-from-scratch, pushed). D-366 (license
  attribution) + D-368 (agent await/watch race fix, ADR-0093 am1) both landed.
- **First on resume MUST be, IN ORDER** — the Mac was restarted to clear an
  external zwasm-session CPU starvation that timed out the local full gate 3×;
  the changed code is Mac-smoke-verified but NOT yet full-gate-confirmed:
  1. **Re-run the Ubuntu full gate** (the in-flight run died with the restart):
     `timeout 1800 bash scripts/run_remote_ubuntu.sh`. It re-fetches + tests the
     pushed HEAD `7f12451c` — the AUTHORITATIVE check that D-368 closed the
     Linux-manifesting `agent_add_watch` race (expect 302/0) and D-366 broke
     nothing. **Root-fix any failure on the spot** (don't defer).
  2. **Run the local Mac full gate once** (zwasm load now gone):
     `bash test/run_all.sh` → stamps `.dev/.gate_pass` so subsequent LOCAL
     commits pass the gate_cadence hook. (D-366/D-368 were committed from an
     external shell, which bypasses the Claude-side gate while load-starved.)
  3. **D-362 — Conj CFP runway** (user-collaborative: org-repo register/delete,
     fly deploy, zwasm `v2.0.0-alpha.2` tag + build.zig.zon pin = F-001-adjacent,
     README polish) + **D-367 — README simplify**. Full rows in `.dev/debt.yaml`.
- **Forbidden**: pushing to `main`; pinning a zwasm tag UNILATERALLY (D-362
  step 6 — confirm + log an F-001 Revision-history entry when taken).

## Just landed — D-366 license + D-368 agent await/watch race fix

- **D-366** (commit `ca1578c9`): EPL-2.0 per-file headers on all 16
  `src/lang/clj/clojure/**/*.clj` (variant ① upstream banner: template.clj +
  core/protocols.clj; variant ② CW-copyright: the other 14) + root `NOTICE` +
  `.claude/rules/clj_attribution.md` + `scripts/check_clj_attribution.sh`
  PreToolUse hook (wired in settings.json). `cljw.*` out of scope. Fixed the
  PROMPT's discovery grep (git pathspec `**` misses top-level `clojure/*.clj`;
  use `find`).
- **D-368** (commit `7f12451c`, ADR-0093 am1): `(await a)` raced its own watch
  fire — the sentinel `(deliver p s)` was IN the action body, releasing the
  awaiter before `runAction`'s `notifyWatches` fired the barrier's `[s s]` watch.
  Fix: the agent queue element is now `Action{body, completion}`; the drainer
  delivers `completion` AFTER store + `notifyWatches`; `await` = `(__agent-await a)`
  enqueues a nil-body barrier (still fires the clj-faithful `[s s]`) + returns the
  promise. Deterministic, watch-order-independent; leaf-lock (F-006) preserved.
  Mac smoke: `agent_add_watch` 30/30 `[[0 1] [1 2] [2 2]]` + all agent e2e
  regressions green. Ubuntu confirmation PENDING (resume step 1).

## Process discipline (SSOT)

- **Gate cadence**: per-commit `--smoke <changed-e2e-step>` + don't block; batch
  the full `bash test/run_all.sh` at ceiling / Phase boundary / pre-release. An
  external zwasm session can CPU-starve the local full gate (3× timeout this
  session); the Ubuntu remote gate is load-immune and is the fallback verifier.
- **Linux gate** (ubuntunote, load-immune): `timeout 1800 bash
  scripts/run_remote_ubuntu.sh` against the pushed HEAD.
- Demo binary is `cljw-wasm` (separate from the gate's `cljw`).

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-362** = CFP runway NEXT; **D-367** = README;
D-366/D-368 DISCHARGED) → `.dev/decisions/0093_agent_serial_executor.md` am1
(agent await fix) → `private/notes/agent-await-watch-race-fix-plan.md` +
`private/notes/D366-license-attribution.md` → CLAUDE.md.

## Stopped — user requested

User (2026-06-10): 「ストップ、やはりMacを再起動してresumeしてもどってきます。
きっとUbuntuの方はあとから確認可能ですよね？」 — explicit stop to restart the Mac
(clearing the external zwasm CPU starvation that 3×-timed-out the local full
gate) and resume via `/continue`. Ubuntu verification is re-runnable against the
pushed HEAD afterward (resume step 1). Resume per the contract above.
