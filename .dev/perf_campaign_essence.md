# Perf-campaign essence (the relentless-lookahead injection SSOT)

> Machine-injected at every wait-point by `scripts/perf_campaign_remind.sh`
> (PostToolUse:Bash on a gate / bench / background launch) and at SessionStart.
> Kept SHORT so it can be force-injected often without diluting; the existing
> `gate_continue_remind.sh` / `post_commit_remind.sh` are the model. The campaign
> runs under ROADMAP §9.2.S; the smell-audit + gate-cadence hooks are the
> *blocking* guards, this is the *don't-drift* guard.

## The one rule

**A wait is never idle. While ANY background work runs (a gate, a bench, a
ScheduleWakeup), do LOOKAHEAD SURVEY + PREP — never end a turn on a bare
"awaiting X".** Rework from a survey that a later fix invalidates is cheap (AI
speed); an idle wait is the only real waste.

## What to do during a wait (tree-clean, no build / no bench)

The `private/` area is gitignored scratch — work there freely; nothing here
needs to land to be useful.

- **Mine v0** (`~/Documents/MyProducts/ClojureWasm/`) for the next lever's proven
  shape — re-derive cljw-clean (F-004), never copy. v0 beat Python 17/20; its
  catalogue (`.dev/perf_v0_baseline.md`): 24A.4 arith fast-path, 37.2-3
  superinstructions + compare-branch fusion, 37.4 ARM64 hot-loop JIT.
- **Survey the next Python-target** (the losing benches) + draft its attack.
- **Draft the next change** into `private/` (code sketch + the gate it must pass)
  so it applies instantly once the wait clears.
- **Re-profile / re-read** the hot path; update the survey note's plan.

## The campaign does not stop until

1. cljw beats Python on EVERY `bench/` workload (cold µs), THEN
2. cljw closes on cw v0's numbers (fib 16 ms, arith_loop 4-5 ms, …) using v0's
   proven levers (superinstructions → JIT), THEN
3. the user explicitly says stop (CLAUDE.md § The only stop).

Current front: **D-386 per-instruction dispatch** (kill stepOnce's per-op
sp/ip copy+writeback v0-style; batch the polls; superinstructions; then JIT).
Live state: `.dev/handover.md` + `private/notes/9.2.S-flat-frame-survey.md`.

## Guard level

This is a *don't-drift* injection, not a blocking gate. But treat it with the
same non-negotiable force you give the commit guards (smell-audit, gate cadence):
when it fires, you ACT on it — pick a lookahead task and do it — you do not
acknowledge-and-idle.
