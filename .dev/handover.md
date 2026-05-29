# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `eaeef874`).
- **First commit on resume MUST be**: pick the next intricate-tier item —
  the clean `.clj`/macro coverage is harvested; what remains needs focused
  context. **Recommended: `doseq` + `for`** (the highest-frequency missing
  macros; need the `:when`/`:let`/`:while` modifier grammar + multi-binding
  + (for `for`) laziness — a recursive modifier-aware expansion, ~JVM
  core.clj's `doseq`/`for`). Alternatives, all queued: **ADR-0056 Cycle 3**
  (lazy non-core bootstrap files — eager-dep analysis; `cljw.error` is
  eager-required), **D-045** (HAMT >8-key map wall — survey done), **D-139**
  (AOT param-name fidelity — memory-ownership marker). `letfn` needs letrec.
- **Forbidden this session**: re-opening anything landed (AOT Cycles 0-2c,
  D-096, D-154, the test-speed work, the ~20 macros / ~17 fns). Rushing
  D-139's param-ownership or doseq/for modifier grammar at session-tail
  (subtle-bug risk — F-002). CPU-heavy subagent during a gate (cold_start
  false fail). Flipping `phase_at_least_14` / tagging v0.1.0 (release HELD).

## Current state

Mac gate **135/135** green, **~80s** (was 390s: build-once + zone_check
pure-bash + ReleaseSafe e2e). **AOT-bootstrap LIVE** (ADR-0056): build-time
`cache_gen` (build.zig) VM-compiles core.clj → an embedded bytecode
envelope; ALL startup paths (runner/repl/nrepl/built-apps) `runEnvelope`-
restore clojure.core instead of parse+analyze+eval (`bootstrap.setupCoreAot`/
`loadCoreAot`). Gate-faithful; edge/Wasm per-instance cold-start is the win.
**D-096** (println stdout) + **D-154** (JVM-faithful char printing)
discharged. This session added ~20 clojure.core macros (threading/
conditional/iteration/case/condp/when-not/if-not/comment/assert) + ~17 fns/
primitives (some-fn/every-pred/trampoline/replace/distinct?/partition-all/
splitv-at/not=/fnext/nnext/run!/peek/pop/find/subvec/int/char + earlier
merge-with/partition-by/etc.). gate 113→135.

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

AOT-bootstrap (edge-readiness) mechanism done. Coverage floor heavily
advanced. Remaining toward M: doseq/for/letfn → D-045 HAMT (>8-key wall) →
**Phase 15** concurrency (ADRs 0009/0010) → superinstruction/fusion →
narrow ARM64 JIT (D-133) → **M** → quality loop. cw-v0 gaps in
`.dev/cw_v0_parity_and_gap_plan.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-045** HAMT >8-key wall. **D-139** AOT param-name fidelity (memory-
  ownership). **D-134** doseq/for/letfn + format/re-seq/shuffle/rand-nth/
  tree-seq/lazy-cat residuals. **D-085** keyword-as-fn `(:k m)`. **D-150**
  VM ctor parity. **D-153** `(cons x lazy)` count. **D-152** diff oracle
  `.clj` closures. **D-131** built-app non-core files (partially advanced).
  **D-117/118** nREPL (Phase-15). **D-133** JIT floor. (D-076/D-096/D-130/
  D-136/D-137/D-154 discharged.)

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The only
stop) → `.dev/project_facts.md` (F-010 + edge mission) → `.dev/principle.md`
→ `.dev/decisions/0056_aot_bootstrap.md` (+ revision history) →
`private/notes/phaseA26-*.md` → `src/lang/bootstrap.zig` +
`src/eval/driver.zig` + `build.zig` (AOT) → ROADMAP §1 (mission) + §A26.
