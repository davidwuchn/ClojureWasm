# ADR-0166 — Public-ization polish sweep (the post-perf operating mode)

- **Status**: Accepted as the operating mode after the §9.2.S perf campaign's
  accessible levers were exhausted (2026-06-24, user-directed). Repeatable, like
  the F-010 quality-loop floor — NOT a one-shot phase. Each `/continue`
  self-selects ONE polish-sweep category and drains it highest-value-first.
- **Relates to**: ADR-0165 + Amendment 1 (perf accessible levers exhausted —
  O-051 was the last cheap one; the rest is GC-arch / JIT-fenced), F-002
  (finished-form), F-010 (quality-loop operating mode this mirrors), F-013
  (single-binary public artifact). Drains via `quality_floor: "public-ization: …"`
  debt rows (D-522…D-529). ROADMAP §9.2.T.

## Context — why this mode now

The perf campaign (§9.2.S / ADR-0148) reached the boundary of its cheap levers
this session (O-051 keyword-map-get was the last clean constant-factor; the
remaining 9-bench gaps need a GC-arch change (L4 variable-length objects) or the
fenced/risky VM-dispatch/JIT frontier — ADR-0165 Amendment 1 + D-520/D-386). The
project is otherwise **near-complete** and is a **public artifact** (public repo,
single static binary, EPL-2.0). Its scaffolding, however, still reads as a
**private dev environment**: per-session `private/notes/` memos baked into the
loop, comments that are terse **pointers** to ADR/debt numbers rather than
self-contained explanations, docs written against an older code state, and a
large auto-loaded rules corpus. The next high-value work is **polishing the
project for an outside reader/contributor who clones it into their own
environment** — not new runtime capability.

The user's framing (2026-06-24, verbatim intent): work `(b)` — the finite quality
sweeps that were deferred as "low ROI" — now becomes the standing `/continue`
mode. Source the sweep from the categories below; many are "あと少しが欠落"
(almost-done, small gap) or "古い" (stale-vs-code-truth) items.

## Grounding (measured 2026-06-24 — the scale of each category)

| Category                           | Measured scale                                                      |
|------------------------------------|---------------------------------------------------------------------|
| ADR/debt pointer comments in `src` | 1409 `ADR-NNN` + 1528 `D-NNN` lines across `src/**/*.zig`           |
| Marker comments                    | PROVISIONAL 4 · PERF 65 · GC-ROOT 41 · VM-DEFER 0                |
| Auto-loaded rules                  | 31 files / 3736 lines (`.claude/rules/`)                            |
| Docs                               | 29 `*.md` (`docs/ja`, `docs/spec`, `docs/works`, `docs/ja/archive`) |
| Per-session notes                  | 853 files under `private/notes/`                                    |
| Java-interop surface               | 49 `runtime/java/**/*.zig` files / 92 `compat_tiers.yaml` fqn rows  |

## Decision — the sweep categories (each a standing debt row, drained by Step 0.5)

The loop self-selects highest-value-first; the rows are the menu, ADR-0166 is the
intent. A correctness/clj-parity floor still outranks pure polish (CLAUDE.md).

1. **D-522 — Comment de-pointering + condensation.** Replace pointer comments
   (`[refs: D-NNN]`, "per ADR-NNN", "see D-NNN") with **self-contained
   explanation** — a reader without the ADR/debt ledger should understand the
   code. ADR documents themselves STAY (they are the rationale record); only the
   in-code *pointers to them* become prose. Condense over-verbose comments. This
   is the largest category (≈3000 lines) — explicitly **gradual, a little each
   `/continue`**. Keep the `Why`-non-obvious comments (CLAUDE.md comment rule).
2. **D-523 — Doc audit vs code-truth.** The docs were written against an older
   code state. Audit each against what the code actually does; fix, **simplify**,
   delete what is no longer meaningful, **archive** (move to `docs/ja/archive/`
   or similar) what is historically meaningful but dead.
3. **D-524 — `private/` decoupling + per-session-note abolition.** `private/` is
   gitignored and assumes the user's machine; the loop's Step 7 writes a per-task
   note every cycle (853 accumulated). For a public artifact this should not be
   load-bearing. Decouple CLAUDE.md / the `continue` + `code_learning_doc` skills
   from `private/notes/`; retire the mandatory per-task note (or make it opt-in).
4. **D-525 — Rules + skills public-ization review.** 31 rules / 3736 lines auto-
   load into every turn. Review for an outside contributor: prune/merge stale or
   redundant rules, ensure each earns its context cost, de-private-ize wording.
   Same for the skill set.
5. **D-526 — Java-interop static-member gap catalog + fill.** Some static members
   are missing. If they cannot be enumerated mechanically, the FIRST step is to
   **catalogue** them (extend `compat_tiers.yaml` / a coverage doc), then fill the
   "あと少し欠落" tail.
6. **D-527 — clj-parity alignment with upstream progress.** Clojure itself has
   advanced; align with new upstream behaviour **where meaningful**. Folds into
   the standing D-175 `quality-loop floor: clj-parity` (sweep surfaces DIFFs).
7. **D-528 — Real `deps.edn` famous-library usage.** Load real, popular Clojure
   libraries via their actual `deps.edn` and run them — surface bugs / unimplemented
   surfaces from real-world use, not synthetic tests.
8. **D-529 — Marker-comment inventory + validity.** Walk the 110 markers
   (PROVISIONAL / PERF / GC-ROOT); validate each is still accurate + earning its
   keep; retire stale ones; keep the meaningful.

## Consequences

- The codebase + scaffolding converge on a **clean public artifact** an outside
  reader can navigate without the private ledger.
- Pure polish; **no behaviour change** is the default (doc/comment/scaffolding
  edits). Where a sweep DOES touch code (D-526 interop fill, D-527 parity, D-528
  bug fixes), the normal gate (diff oracle + corpus) applies.
- The §9.2.S perf campaign is **paused** (`.dev/.perf_campaign_active` removed) —
  its remaining levers (D-520 collection / D-386 dispatch / D-005 JIT) stay in
  standing debt for a future deliberate decision, not the active mode.

## Alternatives considered

- **A one-shot "cleanup phase" with a fixed task list** — rejected: the categories
  are open-ended (de-pointering ≈3000 lines, doc audit across 29 files) and better
  drained incrementally per `/continue` (the F-010 repeatable-mode shape), so a
  fixed list would either under-scope or stall.
- **A dedicated big-bang "大整理" cycle (D-436)** — D-436 remains the epic for
  finished-form *code* deviations; this ADR is the broader **public-ization** mode
  (docs / comments / scaffolding / interop / parity), drained alongside it.
- **Leave the scaffolding as-is** — rejected: the project is public; private-env
  scaffolding + pointer-only comments are a real barrier to outside contribution.
