# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (D-356 require-closure embed + D-363 `cljw build -m`
  + D-365 serialize completeness all landed + pushed; each ADR/source commit
  pair gated `--serial-e2e` before push, stamping `.dev/.gate_pass`).
- **On resume, do these IN ORDER** (user-directed 2026-06-10):
  1. **Launch the Ubuntu full gate in BACKGROUND** —
     `timeout 1800 bash scripts/run_remote_ubuntu.sh` (look-ahead; the Linux
     gate is not per-commit per ADR-0049 and a LOT has landed since the last
     run). Do NOT block on it; keep working. When it reports, **root-fix any
     failure on the spot** (don't defer) — re-run after the fix.
  2. **D-366 — license attribution (FIRST source task).** Apply
     `private/20260609_license_research/PROMPT.md` § B VERBATIM (judgement
     already settled there): B-1 per-file EPL-2.0 headers on all
     `src/lang/clj/clojure/**/*.clj` (2 variants), B-2 root NOTICE, B-3
     `.claude/rules/clj_attribution.md`, B-4 `scripts/check_clj_attribution.sh`
     hook — B-3+B-4 land in the SAME cycle as B-1 (framework_completion). The
     zwasm side is already done; only the ClojureWasm side remains.
  3. **D-362 — Conj CFP runway** (user-collaborative: org-repo register/delete,
     fly deploy, zwasm `v2.0.0-alpha.2` tag + build.zig.zon pin, README) +
     **D-367 — README simplify** (logo/title/catchphrase/`[!NOTE]` no-Issues-
     PRs/features-no-perf/quickstart/Playground+Bookshelf URLs/ideal). Full
     rows in `.dev/debt.yaml`. The bookshelf demo already builds + runs as a
     single binary (`cljw build -A:cljw -m bookshelf.server -o bookshelf`).
- **Forbidden**: pushing to `main`; pinning a zwasm tag UNILATERALLY (D-362
  step 6 is an F-001-adjacent transition — confirm + log an F-001 Revision-
  history entry when taken).

## Just landed — bookshelf single binary works; D-365 serialize completeness

The D-356 (require-closure embed) + D-363 (`cljw build -m` main mode + A4-D4
deps `:main-opts`) chain now produces a **fully-working single binary** for the
bookshelf demo: `cljw-wasm build -A:cljw -m bookshelf.server -o bookshelf` →
`./bookshelf <port>` serves /api/config, /api/books (real SQLite-via-wasm seeded
data + Rust-wasm cover colors), and the static SPA — one 4.5 MB ReleaseSafe
binary (HTTP + SQLite-wasm + Rust-wasm + OIDC). De-risks D-362's fly deploy.

Getting there surfaced **D-365** — a chain of bytecode-serializer write↔read
INCOMPLETENESS gaps, all one structural class (write/read/archive/doc are 4
hand-synced places, no cross-symmetry gate; F-010/F-013 — the real lib exposed
them): (1) `regex` Value tag had wire-enum+read+archive+doc but NO writeValue arm
(`#","` → UnsupportedValueTag) — added the arm + a **Value-tag symmetry gate**
(exhaustive over ValueTag, a new tag is a compile error until it round-trips);
(2) `call_sites.descriptor`+`field_only` dropped → `(Integer/parseInt …)` static
call crashed at RUN with "missing descriptor" — serialize the fqcn + re-resolve
via `resolveJavaSurface`. KEY INSIGHT: a `cljw build` artifact ALWAYS runs on the
VM (payload = bytecode) while the default backend is tree_walk (F-012), so
embedded artifacts expose serialize-incompleteness + tree_walk/VM parity gaps
that `cljw run` never hits. D-365 RESIDUAL: a CHUNK round-trip gate (side-table +
field completeness, the 2 axes the Value-tag gate doesn't cover) + VM-parity
(D-196).

## Process discipline (SSOT)

- **Gate cadence**: per-commit run the fast **`--smoke <changed-e2e-step>`**
  (ADR-0107 two-tier) and **don't block** — launch it `run_in_background`, yield,
  commit+push when the stamp lands. The smoke tier authorizes shared-code commits
  too, up to 5 before a forced full gate. Batch the **full gate**
  (`bash test/run_all.sh --serial-e2e`) at the ceiling / Phase boundary /
  pre-release — backgroundable as a look-ahead. See memory
  `smoke_first_batch_full_gate`. The parallel e2e pool intermittently exceeds
  even a long timeout under host load (non-deterministic, not a hang) — use
  `--serial-e2e` for a deterministic green.
- **Linux gate is independent** (ubuntunote): `timeout 1800 bash
  scripts/run_remote_ubuntu.sh` against a pushed HEAD.
- Demo binary is `cljw-wasm` (separate from the gate's `cljw`); rebuild before
  any playground run.

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-366** = FIRST task (license); **D-362** = CFP
runway; **D-367** = README; D-356/D-363 DISCHARGED; **D-365** = serialize
completeness, PARTIAL w/ a structural follow-up) →
`.dev/decisions/0034_cljw_build_single_mode_tier0_metadata_edn_decode.md`
(am3 = require-closure embedding; am4 = `-m` main mode) →
`private/notes/D365-serialize-regex-symmetry.md` +
`…D363-cljw-build-main-mode.md` (session notes + residuals) → CLAUDE.md.

## Stopped — user requested

User (2026-06-10): 「コンテキスト増大してきたので、コミット完了、pushしたら、
次のクリアセッションからcontinueで再開できるように、配線・参照チェーン監査をして
止めてください」。Plus three wired follow-ups for the next session: (a) the
ClojureWasm-side license attribution — `private/20260609_license_research/PROMPT.md`
§ B, zwasm side already done — as the FIRST task (D-366); (b) the Ubuntu full
gate run in BACKGROUND at session start, root-fix issues as they surface; (c)
the README simplification policy (D-367). All three are in the resume-contract
ordered list above + tracked in `.dev/debt.yaml` (D-366/D-367). Resume via
`/continue`; the ordered list is the plan.
