# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `bb0ce0c5`).
- **First commit on resume MUST be**: confirm the gate-cadence hook is
  live (it activates on this restart). Verify: an additive source commit
  prints `[gate_cadence] N/5`; a risky commit (build.zig* or an existing
  src/test line modified) with no fresh gate is blocked. Then resume the
  clojure.core coverage sweep — next clean batch is **numerator /
  denominator** (ratio accessors; investigated: `v.decodePtr(*const
  ratio.Ratio)` → `r.numer.m`/`r.denom.m` Managed → `big_int.allocFromManaged`;
  add `type_arg_not_ratio` to the catalog for the non-ratio case). After the
  clean batch is exhausted, the queued **intricate tier**: `doseq`/`for`
  (modifier grammar + laziness), **ADR-0056 Cycle 3** (lazy non-core
  bootstrap), **D-045** (HAMT >8-key), **D-139** (AOT param-name memory).
  `letfn` needs letrec.
- **Forbidden this session**: re-opening anything landed (AOT Cycles 0-2c,
  D-096, D-154, gate parallelization + gate-cadence hook, the RNG/float-div/
  predicate/bit-op/Math-transcendental coverage). Rushing D-139 or doseq/for
  modifier grammar at session-tail (subtle-bug risk — F-002). CPU-heavy
  subagent during a gate (cold_start false fail). Flipping
  `phase_at_least_14` / tagging v0.1.0 (release HELD).

## Current state

Mac gate **144/144** green, **~50s** (parallel e2e pool, `-P8`, `wait -n`;
was ~74s serial / 390s pre-opt). Perf + shared-binary-mutator steps stay
serial via `SERIAL_STEPS`; `--serial-e2e` restores the old path. **Gate
cadence now mechanically enforced** (`check_gate_cadence.sh` + `.dev/.gate_pass`):
additive coverage batches ≤5 per full gate, shared-code gates every time.
**AOT-bootstrap LIVE** (ADR-0056): all startup paths `runEnvelope`-restore
clojure.core from an embedded bytecode envelope (edge cold-start win).
This session also: **D-096**/**D-154** discharged; ~20 macros + many fns
(earlier); then RNG cluster (rand/rand-int/rand-nth/shuffle), **IEEE float
division** (`/ 1.0 0.0` → ±Inf/NaN, F-005 fix in promote.zig), int?/double?/
NaN?/infinite?, bit-set/clear/flip/test, 18 `Math` transcendentals.

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

AOT-bootstrap (edge-readiness) mechanism done. Coverage floor heavily
advanced. Remaining toward M: doseq/for/letfn → D-045 HAMT (>8-key wall) →
**Phase 15** concurrency (ADRs 0009/0010) → superinstruction/fusion →
narrow ARM64 JIT (D-133) → **M** → quality loop. cw-v0 gaps in
`.dev/cw_v0_parity_and_gap_plan.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-045** HAMT >8-key wall. **D-139** AOT param-name fidelity (memory-
  ownership). **D-134** doseq/for/letfn + format/re-seq + numerator/
  denominator residuals (RNG/bit-ops/Math-transcendental/tree-seq done).
  **D-085** keyword-as-fn `(:k m)`. **D-150**
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
