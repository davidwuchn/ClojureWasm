# 0005 — Dual-backend differential testing as oracle

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: phase-4-entry, testing, differential, ci-gate, dual-backend

## Context

cw v0 implemented `EvalEngine.compare()` to verify TreeWalk and VM
returned identical results, but it ran as a test-only mode behind an
opt-in flag. The two backends were never required to stay in sync at
CI time; this allowed silent drift between them. cw v1 must avoid
this regression.

Phase 4 introduces the VM. From task 4.10 onward, TreeWalk and VM
both execute the entire e2e suite, and any divergence is a build
failure. From Phase 17 onward, if JIT is added, it joins the same
comparison.

## Decision

The implementation of `Evaluator.compare(rt, env, src)` (task 4.10) is
CI mandatory from Phase 4 onward. There is no opt-out flag.
`test/run_all.sh` invokes the comparison runner. Any mismatch between
backends fails the build.

The comparison protocol (Phase 4):

1. Compile `src` once to the analyzer AST.
2. Run TreeWalk and VM separately against the same AST.
3. Compare the two results bit-for-bit (Value, environment changes,
   exception data).
4. Mismatch -> exit non-zero with both result dumps.

In Phase 17+, the same protocol extends to JIT (TreeWalk = VM = JIT).

## Alternatives considered

### Alternative A — Test-only `--compare` flag

- **Sketch**: ship `cljw eval --compare` for developer use; CI runs
  only one backend.
- **Why rejected**: this is the cw v0 mode that allowed drift. Optional
  comparison is not used routinely.

### Alternative B — Sample-based comparison (10% of tests)

- **Sketch**: compare a random sampling each CI run.
- **Why rejected**: drift can land in the 90% that is not compared.
  Comparison cost is acceptable for full coverage.

## Consequences

- **Positive**: TreeWalk and VM stay observably equivalent. Bugs in
  either surface immediately. A useful invariant for cw v1 textbook
  status.
- **Negative**: CI time approximately doubles for the eval suite.
  Acceptable trade-off for Phase 4-15.
- **Neutral / follow-ups**: Phase 17 JIT activation extends the
  comparison runner to a third backend. ADR amendment required at
  that time.

## References

- ROADMAP §A10 (Differential testing oracle)
- ROADMAP §9.6 task 4.10 (Evaluator.compare CI mandatory)
- cw v0 `EvalEngine.compare()` as cautionary precedent

## Revision history

- 2026-05-23: Status: Proposed -> Accepted (initial landing).
