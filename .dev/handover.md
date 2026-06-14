# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` is the SSOT). **NORMAL PUSH MODE** (user 2026-06-15:
  local-accumulation LIFTED). After each unit's smoke-green commit, `git push origin
  main` immediately (Step 6). `build.zig.zon` `.zwasm` is **SHA-PINNED** to a pushed
  clojurewasm/zwasm commit (`#412966f7…` + content `.hash`, `lazy`) so others build
  reproducibly — NOT the local `../zwasm_from_scratch` path. Advance the pin via
  `zig fetch "git+https://github.com/clojurewasm/zwasm.git#<pushed-SHA>"` (prints the
  hash) then hand-edit `.url`+`.hash`+`.lazy` (the `--save` form mangles a prior
  `.path` entry). Procedure/rationale: zwasm `docs/consuming_prerelease_zwasm.md`.
  Per-commit = smoke; `-Dwasm` now fetches zwasm from git (default build is
  zwasm-lazy, untouched). NOTE: reproducibility-for-others also needs read access to
  the (currently pre-tag) clojurewasm/zwasm repo — user's external action.

- **First task on resume**: **self-select the next gap-area unit** (ROADMAP §9.0 /
  ADR-0142; the loop picks highest-value live per F-002/F-015 — see CLAUDE.md § "When
  the active work unit completes"). **Track R (D-440) substantive arc is COMPLETE**:
  R1 concurrency parity (D-441/await-for/swap-vals!/reset-vals!/io!), R2 accurate-position
  survey, R3 §9 completion-grade reframe (ADR-0142 + D-443), R4 future-row re-barriers
  (D-005/006/020/035/036/039 → gap-area), R5 (phase_at_least_N retired + CLAUDE.md
  phase-machinery + principle.md defer-narrowing → gap-area model). The three live gap
  areas + their highest-value drains:
  - **I Concurrency** — mostly drained; residuals D-442 (future-cancel/seque/legacy, infra
    /low-value), D-105 (java.time trio), AD-018 (`:volatile-mutable` cross-thread re-eval);
    hardening D-244 #4a' / D-245 Option C GATED-defer.
  - **II Wasm/edge-native** (F-014 differentiator) — D-404 (WIT marshalling), D-036/D-350
    (zwasm integration finished-form). zwasm is SHA-pinned now.
  - **III VM perf → JIT** — fusion surface + the narrow ARM64 JIT (milestone M); perf
    campaign (memory `perf_campaign_roadmap_9_2_s`, beat-Python north-star).
  - **Tidiness (low-priority, a Step-0.5 sweep absorbs):** R4 discharge-MOVES of done rows
    still in active (D-037/038/414/426/193 → discharged[]); a few "Phase boundary"
    gate-cadence prose mentions in CLAUDE.md (loosely-correct). D-443 (capability-matrix
    successor) opens only after the citations fully drain.
  - **Reads: `.dev/project_facts.md` F-015 + ADR-0142 + ROADMAP §9.0** + the gap-area's
    draining debt rows. (W1-remaining / Track S micro-units are fill-in below.)

- **This session landed (git log = SSOT)** — the full Track R (D-440) arc + the
  zwasm release:
  - **Track R R1-R5** (F-015 / ADR-0141 / **ADR-0142**): R1 concurrency parity
    (D-441 agent ctor options + await-for + swap-vals!/reset-vals! + io!, corpus-locked);
    R2 accurate-position survey; R3 §9 gap-area reframe (ADR-0142, **D-443** filed);
    R4 future-row re-barriers → gap-area; R5 retired `phase_at_least_N` +
    CLAUDE.md/principle.md → gap-area model. Stale agent e2e (the full gate caught it)
    updated for the landed options.
  - **zwasm SHA-pin + push restored**: `build.zig.zon` `.zwasm` is now a content-hash
    git pin (`#412966f7`); the 2026-06-14 local-accumulation/no-push override **LIFTED**;
    ~30 accumulated commits released to origin (memory `local-accumulation-sweep-phase`
    = ENDED). Two full gates green (356/356) against the git-pinned zwasm.

  SAFETY: `clj` oracle batches need `-J-Xmx2g` + bounded seqs (memory
  `clj_oracle_heap_cap`); register every new e2e in run_all.sh same-commit; **the
  `--smoke` tier does NOT run unnamed e2e steps** — name the changed e2e step, or the
  batched full gate catches the miss (it just did, for the agent options e2e).

  **State**: near-complete (F-015); §9 is the **gap-area model** (§9.0). zwasm
  SHA-pinned + interp-embedded. **Normal push mode** (Step 6 push per commit).

- **Forbidden this session**: `git push --force*`; bare `zig build` for any
  scripted / probe path (ADR-0133 — use a ReleaseSafe binary). (Local-accumulation /
  no-push is LIFTED — push per Step 6.)

## Cold-start reading order (resume)

handover → **`.dev/project_facts.md` F-015** (the completion-grade posture — read
FIRST) → **`.dev/decisions/0142_*.md`** (the §9 gap-area reframe; supersedes the
old phase-queue model) → **ROADMAP §9.0** (the gap-area model + the
phase-number→gap-area redirect) → the chosen gap area's draining `.dev/debt.yaml`
rows. Track R (D-440) substantive arc is DONE; the loop self-selects the next
gap-area unit (CLAUDE.md § "When the active work unit completes"). clj oracle =
`~/Documents/OSS/clojure/` + `clj -J-Xmx2g -M` (`timeout 60`). SAFETY: bounded seqs
+ `-J-Xmx2g`; name changed e2e steps to `--smoke` (unnamed e2e are NOT run);
register new e2e in run_all.sh same-commit; new debt rows via Edit (quoted id),
NOT `yq +=` (yaml_ssot_yq.md Golden-rule #4).

