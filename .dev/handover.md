# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `1b6f5a5f` (tokenizer overflow fix, pushed). Tree clean. Gate baseline
  is now **295/0** `--serial-e2e` (new e2e steps: fs_jail, tokenizer_long_input).
- **First action on resume: check the inbox** —
  `zwasm_from_scratch/private/security_handover_to_cljw_NN.md`, highest number with
  no `## CONSUMED` trailer (currently `_01` CONSUMED → none new). If a new one
  exists, do it (TDD, finished-form), gate, commit, push, append CONSUMED.
- **Else the security concrete backlog is DRAINED.** Every SE finding is
  dispositioned (fixed or scheduled debt) and every untrusted-input surface was
  audited (reader nesting = max_depth-safe; tokenizer overflow = FIXED; number
  literals = BigInt/clean-error-safe). Remaining work is phase-gated debt only:
  **D-338** SE-2 import allowlist (first host import), **D-339** SE-3 server
  slowloris (Phase-15 concurrency), **D-341** SE-8 eval-free build, **D-342**
  FS-jail symlink-safe, **D-343** require code-loading confinement, **D-344** regex
  global compile budget, **D-346** VM operand-stack on large literal. None are
  unblocked now. Self-select per CLAUDE.md § The only stop (quality-loop floor /
  a fresh audit surface), or await a zwasm handover / phase event.
- **Forbidden**: pushing to `main` / pinning a zwasm tag (F-001 relative-path
  co-dev). Two gates at once (share `/tmp/codev_gate.lock` — `mkdir` acquire,
  `rmdir` release all paths).

## Mode: security co-dev (cljw ⇄ zwasm), relative-path, /loop 10m

- F-001 = **relative-path co-dev** (`build.zig.zon` → `../zwasm_from_scratch`,
  lazy); a zwasm fix is live in cljw immediately; the default gate never resolves
  zwasm (lazy + `-Dwasm`-guarded). zwasm's embedder-hardening pass is landed
  (`to_cljw_01`). Loop runs via `/loop 10m` (cron 8b1e24d1) per CODEV_PROTOCOL.md.

## Landed this session (12 units, all pushed, all gated)

task4 (wasm GC finaliser), FIX-1 (wasm/load budget), FIX-2 (HTTP :status), FIX-3
(marshal range-check), FIX-4 (wasm-error taxonomy → catchable), INV-1 (regex
compile-bomb cap; matcher is Pike-NFA / ReDoS-immune), SE-5 (HTTP header CRLF +
std.http abort), ADR-0122/AD-026 (read-string eval-free), SE-6/7 (FS-jail v1,
ADR-0123), SE-9 (nREPL loopback lock), review NUL-fix (FS-jail lexical-vs-kernel),
tokenizer overflow fix (reader-DoS audit). `git log 65e4c184..1b6f5a5f` is the SSOT.

## Process discipline (SSOT)

- Shared-code gate: `bash test/run_all.sh --serial-e2e`; verify Summary
  `failed: 0` + `.dev/.gate_pass` == `scripts/gate_state_hash.sh`. Wasm work uses
  `zig build -Dwasm`; `test/e2e/phase16_wasm_ffi.sh` is opt-in (run for wasm
  changes). Shipped binary is ReleaseSafe — verify panic-class findings there.
- Audit log (gitignored): `private/security_audit/` (00..92) + `private/CODEV_STATUS.md`.

## Cold-start reading order

handover → `~/Documents/MyProducts/zwasm_from_scratch/private/CODEV_PROTOCOL.md`
(inbox + loop) → `.dev/debt.yaml` (D-338..346 = remaining security debt) →
`private/security_audit/50_sharp_edges.md` (finding catalogue) → CLAUDE.md.
