# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT). **PUSH RESTORED** — the no-push
  relative-path experiment is OVER: `build.zig.zon` `.zwasm` is now a **tag pin**
  (`v2.0.0-alpha.3`, `fc7ff0b3b`), pushed to `origin/main`. Per-commit = smoke;
  commit **and** push (CLAUDE.md § atomic Step 6).
- **First commit on resume MUST be**: continue the **stdlib/contrib clj-parity
  differential sweep** (user's overnight directive + memory
  `clj_stdlib_contrib_sweep_campaign`). Method: core-coverage-gap probe
  (`(resolve sym)` over clj's ns-publics) + `scripts/clj_diff_sweep.sh` vs the clj
  oracle; fix real DIFFs, corpus-lock them, skip AD/known. Productive next vein =
  reader/number/interop edges (D-509 came from it). Lower-priority queued: ns-unalias
  (safe) + ns-unmap/remove-ns (needs a Var-lifecycle ADR, depth-2).
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm` (false fails —
  memory `zig_build_test_needs_dwasm`); bare `zig build` for a probe (ADR-0133 —
  ReleaseSafe). A reader-macro / syntax-quote NS-qualification stays `rt/`, not
  `clojure.core/` (AD-038/AD-049).

## Last landed (git log = SSOT)

**clj-parity sweep arc (D-502..D-509), 2026-06-23/24 — full gate GREEN (392/0).**
spec.alpha was already complete (D-475/D-476 discharged at resume — stale rows).
The session ran the stdlib/contrib clj-parity sweep:
- core gap-fill: `tap>`/`add-tap`/`remove-tap` (D-502, agent-async), `flush` +
  `future-call` (D-503), `load-string` + `memfn` + `xml-seq` (D-504).
- cl-format directive surface drained vs clj: ~A/~S padding + ~:d group (D-505),
  ~A aesthetic + ~:{ sublist + ~?/~@? recursion (D-506), radix ~@ sign + ~: group +
  sign-magnitude (D-507), ~:C/~@C char (D-508).
- interop: `(Class/FIELD)` parenthesized static-field read (D-509).
Clean (no bug, only AD-001/AD-022/D-470): clojure.string/set/data/walk + `format`.
New memory: `bootstrap-clj-forward-ref-needs-declare`.

## North star (ACTIVE)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
The embedded **zwasm** JIT engine (ADR-0200) is now the cljw DEFAULT (`.auto`). The
remaining north-star step is **components-through-the-JIT** — zwasm-side (components
are interp-pinned there, D-500; Win64 wrapper-thunk gap). Live ledger + the
read-at-boundaries convention: `.dev/zwasm_capabilities.md`.

## Cold-start reading order (resume)

handover → memory `clj_stdlib_contrib_sweep_campaign` (the overnight directive) +
`docs/works/ladder.md` (library ladder) → `.claude/rules/clj_diff_sweep.md` +
`scripts/clj_diff_sweep.sh` (the sweep harness + corpus-lock discipline) →
`private/notes/sweep-D502-509-arc.md` (this arc's findings). memories
`char_literal_e2e_oracle` (FILE not `-e "$big"`), `verify_actual_pattern_not_proxy`.
