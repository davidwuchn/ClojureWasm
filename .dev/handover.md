# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (Phase-C library gap-hunt exhausted this session — ~16
  clj-parity fixes landed + corpus-backed + audited; see § Phase C below).
- **First commit on resume MUST be**: **open Phase B (concurrency) per ADR-0090**
  — the §7-redesign-vs-Zig-0.16 concurrency-mechanism design comes FIRST, then
  STM-txn / agent / locking / real-threading / Thread+arrays (F-004) / *out*·in·err
  (D-238) / reflection. Phase-B reading list: ADR-0089 (A→B→C re-cut) + ADR-0090,
  ROADMAP §7 + §9 Phase-B placeholder, project_facts F-004, debt D-242/244/245/246.
- **⚠ USER must act (time-sensitive, NOT AI-doable)**: see
  `private/clojure_conj_2026_cfp/DEFERRED_USER_ACTIONS.md` — (1) Sessionize submit
  by 6/13 (`SUBMIT_READY.md` copy-paste ready); (2) v0.1.0 tag/Release + make
  `cw-from-scratch` the default branch; (3) edge-demo CRUD `git push` + `fly deploy`.
- **Forbidden**: the 3 USER actions above (credential / product decisions — the
  safety layer blocks them); editing `.claude/rules/*` (permission-blocked →
  surface); pinning an in-progress zwasm v2 state / tag (F-001: v2 ONLY from
  `zwasm-from-scratch`); trusting `~/Documents/OSS/zig`.

## Phase C — library gap-hunt exhausted (2026-06-06, git log = SSOT)

The clj-diff differential sweep ran across all practically-probeable surfaces
(~300 probes: reader / numeric-tower / comparison / collections / higher-order /
regex / var-ns / string / transducers — common AND deep). ~16 clj-parity fixes
landed, each corpus- or e2e-backed; corpus regression 2045/2045 reproduce:

- **reader**: radix `2r1010` (D-263); octal `017` + octal-char `\o377` cap;
  `\uXXXX` lone-surrogate reject.
- **numeric tower**: biginteger≡bigint + AD-016 (D-265); unchecked-* FULL family
  (D-268); ratio-collapses-to-whole → BigInt `2N` (D-272, F-005); compare across
  the whole tower EXACTLY + `(compare ##NaN x)`→0.
- **seq/string**: lazy distinct/dedupe (D-264); subs / subvec / .substring
  bounds-check (was silent clamp); symbol/keyword `"ns/name"` split; nthrest
  (n≤0 keeps coll) / take-last (empty→nil).
- **analyzer**: qualified `ns/name` own-interns-only (D-261). **edn**: read-string
  EOF throws, not silent nil (D-269).

Remaining gaps are TRACKED sizable features or AD (not quick-fix), recorded in
debt.yaml: **D-057** Unicode case-fold (ASCII-only; full table = Phase 11 OR AD);
**D-270** Java primitive arrays; **D-086** record `__extmap` (F-003 structural);
**D-266** non-chunked lazy-seq perf; **D-267** format `%c`; **D-271** with-meta on
a raw range; re-matcher/re-groups; **D-258** dormant agent torture flake (D-244 #4).

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min;
  -P8 over-runs under load). Doc-only = no gate. Never poll a bg gate.
- A clj-diff probe runs many `cljw` processes — **never sweep concurrently with a
  running gate** (contends with the perf-threshold steps → false failures).
- clj-diff harness = `scripts/clj_diff_sweep.sh exprs --corpus <area>`; for
  classification, probe **per-expr** (cljw vs clj individually) — a batch desyncs
  when one expr is a clj READ error (e.g. `08`, `nan?`, a non-required
  `clojure.set/…`). `clj -M -e` → `timeout 20` + bound infinite seqs.
- Speed ONLY via `scripts/perf.sh` (never time Debug). Edit/Write TRANSCODES
  literal non-ASCII (keep source ASCII; splice non-ASCII via python). Default
  backend = VM (F-012).

## Cold-start reading order (tracked-only)

handover → **`.dev/decisions/0090_phase_b_concurrency_redesign.md`** +
**`0089_recut_concurrency_and_drift_methods.md`** → ROADMAP §7 (concurrency) + §9
Phase-B placeholder → `.dev/project_facts.md` F-004 (NaN-box arrays) / F-006 (GC) →
debt.yaml D-242/244/245/246 → CLAUDE.md (§ Project spirit + The only stop) →
`.dev/principle.md`.
