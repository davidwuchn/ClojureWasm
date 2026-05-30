# Gate cadence (batch additive, gate shared-code)

Auto-loaded when editing the test runner / hook scripts / settings.
Codifies *when* the full Mac gate (`bash test/run_all.sh`, ~50s) must
run, and makes the policy **mechanically enforced** rather than prose.

## Why

The full gate is ~50s. Empirically (2026-05-30 session retrospective),
on **additive coverage** — a new `.clj` def, a new primitive, a new
`Math` method, a new e2e — the full gate caught **0 regressions** that
the per-feature smoke (`zig build` + `cljw -e` probes + the single new
e2e, ~2s) had not already caught. Additive changes cannot break the
other ~144 tests, so the full gate there is near-pure insurance.

Where the gate **earns its ~50s** is **shared-code** changes: editing
an existing primitive / `promote.zig` / analyzer / `eval/` path / the
VM, or `build.zig*`. Those carry real regression risk and are the only
place the dual-backend diff oracle (TreeWalk↔VM parity) can catch a
divergence the smoke does not.

So: **batch additive, gate shared-code.**

## The policy

| Commit class        | Definition                                                                                         | Gate requirement                                                            |
|---------------------|----------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| **Non-source**      | No `src/` / `test/` / `build.zig*` staged (docs, `.dev/`, `.claude/`, `scripts/`)                  | Exempt — never gated, never counted                                        |
| **Additive source** | Touches `src/` or `test/`, **pure insertion** (no existing line removed/modified), no `build.zig*` | May accumulate up to **5** commits since the last full gate; the 6th blocks |
| **Risky / shared**  | `build.zig*` staged, OR an existing `src/` or `test/` line removed/modified                        | **Fresh full gate every time**                                              |

"Fresh full gate" = `test/run_all.sh` ran to a full green (no `--only` /
`--skip`) on the exact state being committed.

## Mechanical enforcement (this is law, not advice)

- **`scripts/gate_state_hash.sh`** — prints a fingerprint of the source
  state (`src/` + `test/` + `build.zig*`, HEAD-folded; `bench/`
  excluded).
- **`test/run_all.sh`** — on a full green gate writes that fingerprint
  to `.dev/.gate_pass` (gitignored).
- **`scripts/check_gate_cadence.sh`** — PreToolUse hook on `git commit`.
  Classifies the staged diff (numstat: any deleted line in `src/`/`test/`
  ⇒ risky; `build.zig*` ⇒ risky; else additive). If the current
  fingerprint equals `.dev/.gate_pass`, the gate verified this exact
  state ⇒ authorise + reset the counter (`.dev/.gate_cadence`).
  Otherwise: risky ⇒ block; additive ⇒ consume a batch slot, block at
  the 6th.

`git commit --no-verify` is denied in `.claude/settings.json`, so the
hook cannot be bypassed. `GATE_MAX_BATCH` (default 5) is overridable
via env for a one-off.

## Workflow it produces

- Additive coverage sprint: edit → fast smoke (`zig build` + `cljw -e`
  + the new e2e) → commit. Up to 5 such commits ride without the full
  gate. Run `bash test/run_all.sh` on the 5th (or whenever convenient)
  to reset the batch — the commit whose state the gate verified is
  authorised and the counter zeroes.
- Shared-code change: edit → `bash test/run_all.sh` → commit (the gate
  stamped `.dev/.gate_pass` for this state, so the commit is authorised).

The fast per-feature smoke is still expected on **every** change — the
batching only defers the *full* gate, never the smoke.

## Forward-looking (framework_completion note)

Per `framework_completion.md`, a new hook must state its discovery
criterion + sweep. This hook is **forward-looking** (like
`orphan_prevention.md`): it constrains *future* commits' cadence and
retrofits no existing code, so there is no existing-site population to
sweep. The "discovery recipe" is the classifier in
`check_gate_cadence.sh` itself, applied per future commit.

## Stale-ness

Stale if: the full gate stops being ~50s (re-measure the additive vs
shared cost asymmetry); a new shared-risk surface appears that the
numstat-deleted heuristic misses (e.g. a config file that gates
behaviour); or the additive batch of 5 proves wrong in practice.

## Related

- `.claude/rules/orphan_prevention.md` — sibling forward-looking hook.
- `scripts/check_smell_audit.sh` — the other `git`-time blocking hook.
- CLAUDE.md § Autonomous Workflow Step 5 (test gate) / Step 6 (commit).
