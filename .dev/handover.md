# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `bd240d25` (FIX-1, pushed). Tree clean. FIX-1 = `(wasm/load path
  {:fuel N :max-memory-pages M})` budget surface (default = zwasm's finite
  default; `0`/negative axis = unmetered), gated 293/0 `--serial-e2e`.
- **First commit on resume MUST be: FIX-4** (wasm-error taxonomy). Convert every
  `raiseInternal` in `src/runtime/cljw/wasm/surface.zig` + `marshal.zig` (Kind
  `.internal_error` = NOT catchable / exit 70) to a `wasm_*` Code family on
  catchable Kinds (`type_error` / `value_error` / `arity_error` / `io_error` /
  `not_implemented`), so a request-derived bad wasm arg or a trapping module is
  `(catch Throwable …)`able, not process-ending. One uniform sweep over the whole
  wasm surface (F-011 even taxonomy). Full design: `private/security_audit/91_codev_resume_plan.md`
  §FIX-4. cljw-internal, no zwasm dep. Then INV-1 (regex ReDoS), then design-gap
  ADRs (SE-2/3/5/6/7/8).
- **Forbidden this session**: pushing to `main` / pinning a zwasm tag (F-001 is
  relative-path co-dev mode). Running two gates at once (share
  `/tmp/codev_gate.lock` with the zwasm session — `mkdir` acquire, `rmdir`
  release in all paths).

## Mode: security co-dev (cljw ⇄ zwasm), relative-path, /loop 10m

- F-001 amended 2026-06-09 to **relative-path co-dev** (`build.zig.zon` →
  `../zwasm_from_scratch`, lazy). A zwasm fix is live in cljw immediately; the
  default gate still never resolves zwasm (lazy + `-Dwasm`-guarded).
- Two sessions hand off via numbered mailboxes in `zwasm_from_scratch/private/`
  (`security_handover_{from,to}_cljw_NN.md`; consumed by appending
  `## CONSUMED by <repo> @ <sha>`). cljw inbox = `to_cljw_NN` (currently `_01`
  CONSUMED → none new). zwasm's embedder-hardening pass is landed (`to_cljw_01`):
  `instantiate(.{})` finite-default-bounded, facade always interp, decoder
  fuzzed, `_exit` CLI-only.
- Loop runs via `/loop 10m` per CODEV_PROTOCOL.md: each tick checks the inbox,
  else advances one non-blocked backlog unit, gates, commits, pushes. 10-min
  cadence staggers the gate lock with the zwasm session.

## Live queue + process discipline (SSOT)

- Live queue: `private/security_audit/91_codev_resume_plan.md`. Backlog after
  FIX-4: INV-1 (regex ReDoS), design-gap ADRs (SE-2/3/5/6/7/8).
- Shared-code gate: `bash test/run_all.sh --serial-e2e`; verify Summary
  `failed: 0` + `.dev/.gate_pass` == `scripts/gate_state_hash.sh`. Wasm work uses
  `zig build -Dwasm` (resolves the relative-path zwasm tree); the leak-checked
  `test/e2e/phase16_wasm_ffi.sh` is opt-in (ALLOWLISTed out of the default gate
  per F-001) — run it explicitly for wasm changes.
- Audit log (gitignored, do NOT commit): `private/security_audit/` (00..91) +
  `private/CODEV_STATUS.md`. zwasm-side relay: `zwasm_from_scratch/private/`.

## Cold-start reading order (security co-dev, overnight)

handover → `private/security_audit/91_codev_resume_plan.md` (live queue + FIX-4
design) → `~/Documents/MyProducts/zwasm_from_scratch/private/CODEV_PROTOCOL.md`
→ `private/security_audit/50_sharp_edges.md` (finding catalogue) → CLAUDE.md.
