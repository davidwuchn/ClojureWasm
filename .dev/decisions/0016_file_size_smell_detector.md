# 0016 — File size as a smell detector, not a hard metric

- **Status**: Accepted
- **Date**: 2026-05-23
- **Author**: Shota Kudo (drafted with Claude)
- **Tags**: file-size, refactor, discipline, smell-detector, phase-5-6

## Context

cw v0 produced `collections.zig` at 6,269 lines and three other
files over 1,500 lines. Each was perfectly intentional in isolation,
yet the aggregate ended up hard to read and audit. zwasm v2 landed
ADR-0099 to reframe its own file-size discipline from "drive the
metric down" to "trigger investigation when the metric trips."

zwasm v1 itself, in `src/vm.zig` (10,550 lines) and `src/jit.zig`
(8,701 lines), evolved into what its own ARCHITECTURE.md calls
"implicit-contract sprawl" — the file size grew because each new
opcode or backend feature dropped in alongside existing ones with
no extraction trigger. The external evidence is direct: the same
project that uses Zig 0.16 in a similar runtime domain reached
10K+ LOC in two files and identifies it as a structural problem.
A 2,000-line hard cap with explicit exemption markers would have
forced the conversation about extraction long before the 10K
threshold.

cw v1 needs the same reframe before the Phase 5 collections work
lands, since RRB-tree vector + HAMT hashmap + ChunkedSeq + persistent
list could otherwise repeat the cw v0 outcome.

## Decision

`file_size_check.sh` reports two thresholds:

- **Soft cap**: 1,000 lines per `.zig` file. Crossing the soft cap
  triggers a smell investigation, not an automatic split.
- **Hard cap**: 2,000 lines per `.zig` file. Crossing the hard cap
  fails the merge gate unless the file carries a
  `FILE-SIZE-EXEMPT: <reason> (ADR-NNNN)` marker (per ROADMAP §A14).

A smell investigation answers:

### Positive criteria (extract iff at least one holds)

- **P1**: a spec-defined closed sublanguage (≥300 LOC of code, not
  comments) lives in the file (e.g., a SIMD validator).
- **P2**: pure-data dominance — a single declaration block exceeds
  40% of the file (e.g., a large `pub const Table = .{ ... }`).
- **P3**: an independent change cadence + a deep interface (≥3 public
  symbols with ≥2 callers each) makes the section extractable.
- **P4**: test surface isolation — the section can be unit-tested
  without the rest of the file's setup.

### Negative criteria (do NOT extract if any holds)

- **N1**: helper-circular import — the child would re-import the
  parent's private helper.
- **N2**: forced pub-leak — a previously private function would have
  to become `pub` to satisfy the extraction.
- **N3**: shallow module — the proposed child is <100 LOC and would
  collapse two-step navigation onto every existing caller.
- **N4**: test fixture pub-leak — extraction forces test helpers to
  become public.

### Marker convention

Files that intentionally exceed a cap carry one of:

- `FILE-SIZE-EXEMPT: <reason> (ADR-NNNN)` — file size cap exemption.
- `SIBLING-PUB: <reason> (ADR-NNNN)` — cross-file struct method
  pattern.
- `SKIP-<reason>` — test filtering rationale.

`scripts/file_size_check.sh` activates as a hard gate when this ADR
moves to Accepted (Phase 5-6 entry).

## Alternatives considered

### Alternative A — "Aim for under 1,000 lines always"

- **Sketch**: treat the soft cap as a strict metric.
- **Why rejected**: every file under 1,000 lines can still aggregate
  to an unreadable codebase if extraction creates micro-modules.
  This is the failure mode ADR-0099 (in zwasm v2) reframed.

### Alternative B — No file size policy

- **Sketch**: rely on review judgment.
- **Why rejected**: cw v0 had no policy and produced the 6,269-line
  outcome. A trigger is cheap insurance.

## Consequences

- **Positive**: triggers investigation at the right moment, not
  every commit. Avoids fragmentation into useless ~50-line files.
- **Negative**: requires explicit justification when a file
  exceeds the hard cap.
- **Neutral / follow-ups**: status moves to Accepted when Phase 5
  collections split work begins.

## References

- ROADMAP §A12 (File size — smell, not metric)
- ROADMAP §A14 (Structural discipline markers)
- zwasm v2 ADR-0099 (precedent reframe)

## Revision history

- 2026-05-23: Status: Proposed (initial landing). Activation deferred
  to Phase 5-6 when collections work begins.
- 2026-05-23 (amendment 1): Status promoted Proposed -> Accepted.
  External evidence added to Context: zwasm v1's `src/vm.zig`
  (10,550 lines) and `src/jit.zig` (8,701 lines) reached
  "implicit-contract sprawl" exactly because no 2,000-line hard
  cap forced an earlier conversation. Source:
  `private/research-2026-05-23/INSIGHTS_ZWASM_V1.md`. Phase 5-6
  activation timeline unchanged; the promotion is from "future
  policy" to "active policy with documented external evidence".
