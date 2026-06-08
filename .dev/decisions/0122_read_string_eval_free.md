# ADR-0122 — `read-string` is eval-free by design (`#=` read-eval unsupported)

- **Status**: Proposed → Accepted (2026-06-09)
- **Resolves**: SE-8 (security audit, `private/security_audit/50_sharp_edges.md`) —
  the secure-by-default property that reading data never executes code. Adds AD-026.
- **Composes with**: F-011 (behavioural equivalence — security-improving
  divergences are recorded, not silently matched), AD-002/AD-003/ADR-0059 (cljw is
  not a JVM reimplementation).

## Context

JVM Clojure's `clojure.core/read-string` reads with `*read-eval*` **true** by
default, so `#=(form)` (the read-eval reader macro) is **executed at read time**:
`(read-string "#=(+ 1 2)")` returns `3` on the JVM. This is a well-known
remote-code-execution footgun — `read-string` on untrusted input is `eval` on
untrusted input.

cljw's `read-string` is the same full-reader `readOne → formToValue` path as
`clojure.edn/read-string`: the reader has **no `#=` reader function**, so
`(read-string "#=(+ 1 2)")` raises `No reader function for tag =` — it reads data,
it never evaluates. This is the secure-by-default property SE-8 confirmed
(`read-string` is `#=`-free; only `read-string` + `eval` form the eval surface,
and they are separate calls).

The question this ADR settles: is cljw's `#=`-free reader an **intentional,
permanent** design property (a deliberate divergence from clj, to be locked), or
merely an unimplemented reader macro that a future "clj parity" sweep might "fix"
back into an eval-on-read footgun? **It is intentional and permanent.**

## Decision

cljw's reader (`read-string` and the EDN reader it shares) is **eval-free by
design**. `#=` / read-eval is **not supported and will not be added**: reading a
string or EDN never executes code. Evaluation is reached only via an explicit,
separate `eval` call on already-read data.

This is recorded as **AD-026** (an accepted clj-divergence) with
`derives_from: ADR-0122`, pinned by `test/e2e/phase14_read_string.sh`
(`rs_no_read_eval`: `(read-string "#=(+ 1 2)")` must NOT yield `3`). A future
clj-diff sweep that sees cljw diverge from clj's `3` here must treat it as the
locked decision, never a gap to close.

## Consequences

- `read-string` is safe on untrusted input w.r.t. read-time code execution
  (the SE-8 secure-by-default property is now a mechanically-checked guarantee,
  not an accident of a missing reader macro).
- Divergence from clj is explicit (AD-026), so it reads as "designed", not
  "broken", when a user hits it.
- This does NOT confine the separate `eval` / nREPL surface — that is the
  eval-free-deploy-build item (SE-8 second half), tracked as debt **D-341**.

## Alternatives considered

Sourced from a fresh-context devil's-advocate review of the whole SE-2/3/6/7/8
"design-gap" cluster (the disposition question: how to record + schedule the
cluster in one unit). Its findings, verbatim-in-substance:

- **Smallest-diff** — skip any ADR; just add debt rows + an AD entry. Better: no
  ceremony, debt rows are the project's deferral SSOT (F-003). Risk: the `#=`-free
  property needs a *named invariant* to be a legitimate AD (the
  accepted_divergences discipline forbids an AD without `derives_from`) — a bare
  debt row does not supply one. **This ADR exists precisely to be that invariant**
  (the narrow, specific decision), which is why the DA's broader "skip the ADR"
  applies to the *umbrella* posture ADR, not to this one.
- **Finished-form-clean** — build the two implementable-now items (SE-2 import
  allowlist, SE-6/7 FS-jail) this unit; debt-row only SE-3/SE-8. The DA rated this
  its recommendation. Adopted in part: SE-6/7 (FS-jail) is the next build unit
  (D-340). SE-2 is NOT built now — there is **zero host-import-providing code path
  today**, so an allowlist would gate nothing (the "excessive skeleton" smell the
  DA itself flagged); it lands in the same commit as the first host import (D-338).
- **Wildcard** — an executable security-property corpus asserting today's true
  secure-by-default facts (no `#=` eval, zero-import-only load). Adopted in spirit:
  the `#=`-free fact is locked as the `rs_no_read_eval` pin; the others become
  debt-row barriers rather than a corpus of not-yet-built behaviour (a corpus for
  unbuilt behaviour is itself a skeleton).

The DA explicitly rejected a single **umbrella "deploy-mode posture" ADR** as
over-ceremony / an excessive skeleton, since 3 of 4 cluster items gate nothing
today. This ADR is therefore deliberately **narrow** (one already-true property,
locked), and the remaining cluster lives as scheduled debt rows
(D-338 SE-2, D-339 SE-3, D-340 SE-6/7, D-341 SE-8), not as a posture skeleton.
