---
paths:
  - "bench/quick_baseline.txt"
  - "bench/quick.sh"
---

# `bench/quick_baseline.txt` commit policy

Auto-loaded when editing bench infrastructure. Codifies how the
auto-appended baseline log lands in commits without anchoring
issues. Surfaced 2026-05-24 after a user audit found silent
default-shift (= the loop had stopped including the file in
source-bearing commits without recording the policy change);
landed explicit in commit `bda8b4d`; lifted from CLAUDE.md Step 6
to this rule file at Wave 16 W16-8.

## The policy

`bench/quick_baseline.txt` is auto-appended by `bench/quick.sh`
on every gate run. Treat it as **source-coupled telemetry**:

- **Source-bearing commit**: include `bench/quick_baseline.txt`
  in the same commit. The numbers line up with the source diff
  that may have caused them.
- **Doc-only / chore commit**: do NOT include. The numbers have
  no source explanation to anchor against.
- **Phase boundary**: if doc-only commits left bench deltas
  dangling, the Phase boundary review chain (continue skill)
  sweeps them into one
  `bench: accumulated samples through <phase>` commit.

## Why this is a rule and not a CLAUDE.md inline

The default for `bench/quick_baseline.txt` shifted silently
between commit `025dea9` (staged in source commits) and commit
`4.6` (stopped staging) without any committed text recording the
change. Surfacing this as a Silent default-shift smell led to
landing the explicit policy in `bda8b4d` + a CLAUDE.md inline at
the same time. W16-8 lifts the CLAUDE.md inline to a dedicated
rule file so:

1. Editing `bench/quick.sh` auto-loads the policy.
2. The policy lives in one place, not duplicated in CLAUDE.md
   Step 6.
3. Future changes carry a frontmatter `paths:` matcher that
   pins the policy at the right edit point.

## Cross-references

- `.dev/principle.md` Silent default-shift smell entry — the
  original rationale.
- `bench/quick.sh` — the script that auto-appends.
- ROADMAP §10 — bench / observability shape.
