# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `4b324737`).
- **First commit on resume MUST be**: implement **`format`**
  (clojure.core/format, printf-style) as a primitive — the highest-value
  remaining clojure.core gap. Common subset `%s` `%d` `%f` `%.Nf` `%x` `%%`
  `%n` (+ basic width). Parse the fmt string char-by-char; render each arg
  per spec into a `std.Io.Writer.Allocating`, then `string_mod.alloc`. Model
  the per-value rendering on `core.zig`'s `writeArgsSpaced` / `str`; the
  fiddly part is runtime float precision (`%.Nf`) — use `std.fmt.formatFloat`
  with a runtime `.precision`, or render+pad manually. New `lang/primitive/`
  primitive (or a `format.zig`). If `format` proves blocked, self-select the
  next-best unit (do NOT ask — Direction-ask smell). Other candidates:
  **letfn** (needs a letrec foundational feature — mutual recursion),
  **D-153 + ADR-0054 cycle-2** (nested-lazy print/count — Cons layout,
  intricate), `for` :let-threaded `:while` + `mapcat` multi-coll (deferred
  edges), **D-045** HAMT, **D-139** AOT param-name memory.
- **Forbidden this session**: re-opening anything landed (AOT, D-096/D-154,
  gate parallelization + gate-cadence hook + counter-reset, the coverage
  batch [RNG, IEEE float-div, int/long/double/float/num, parse-long/double/
  boolean, bit-ops, Math transcendentals, numerator/denominator, reductions-
  2arg, split-at, counted?/reversible?], **doseq + for** incl `:while`-after-
  binding). Using `AskUserQuestion` to pick the next task (Direction-ask
  smell). CPU-heavy subagent during a gate (cold_start false fail). Flipping
  `phase_at_least_14` / tagging v0.1.0 (release HELD).

## Current state

Mac gate **152/152** green, **~50s** (parallel e2e pool, `-P8`, `wait -n`;
`SERIAL_STEPS` keeps perf + shared-binary-mutator steps serial; `--serial-e2e`
restores the old path). **Gate cadence mechanically enforced + robust to
batched `git add && git commit`** (`check_gate_cadence.sh` classifies via
`git diff HEAD`; `gate_state_hash.sh` content-hash; a full green gate clears
the batch counter): additive coverage batches ≤5 per gate, shared-code gates
every time. **AOT-bootstrap LIVE** (ADR-0056): startup paths `runEnvelope`-
restore clojure.core from an embedded bytecode envelope (edge cold-start win).
Landed since (git log is the SSOT): **doseq + for** (full binding grammar
`:let`/`:when`/`:while`, multi-binding; for is lazy via mapcat) + a wide
clojure.core coverage batch (numeric coercions, parse-*, ratio accessors,
bit-ops, Math transcendentals, reductions-2arg, split-at, predicates).

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

AOT-bootstrap (edge-readiness) mechanism done. Coverage floor heavily
advanced. Remaining toward M: doseq/for/letfn → D-045 HAMT (>8-key wall) →
**Phase 15** concurrency (ADRs 0009/0010) → superinstruction/fusion →
narrow ARM64 JIT (D-133) → **M** → quality loop. cw-v0 gaps in
`.dev/cw_v0_parity_and_gap_plan.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-045** HAMT >8-key wall. **D-139** AOT param-name fidelity (memory-
  ownership). **D-134** letfn + format + re-seq + mapcat-multi-coll + for
  :let-threaded :while residuals (doseq/for/numerator/denominator/coercions/
  parse-*/bit-ops/Math/reductions-2arg/split-at/predicates done).
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
