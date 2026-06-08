# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: newest pushed = **17033efc** (D-334 execution-point trace lines).
  The error-display overhaul is comprehensively landed this session — see
  "Done" below. Working tree clean of source.
- **First commit on resume MUST be: ADR-0120 D-336 — carry the TRACE across the
  thread boundary (the last trace facet).** Cross-thread errors (future/agent)
  now carry kind/message/location/class (Stage B) but an EMPTY `Trace:` — the
  worker's trace doesn't cross. Plan: widen `ExInfo` with a GC-owned
  `StackFrame[]` (the snapshot array deep-copied; frame strings are
  analyzer-arena-owned = session-lifetime, so copying the ARRAY may suffice but
  DUPE the strings too for safety), populate in a fuller `allocExceptionLoc`
  variant from `info.trace`, free in `finaliseGc`, and `buildThrownInfo` reads
  it. This ALSO closes the in-thread `(throw (ex-info))` trace gap. Read FIRST:
  **`.dev/decisions/0120_cross_thread_error_fidelity.md`** (Stage A note + the
  verbatim DA) + `.dev/debt.yaml` D-336. After D-336: D-333 (decoder `:trace`).
- **Forbidden**: trusting a bg-gate notification's exit code (verify ONLY via
  `SENTINEL-EXIT` / Summary `failed: 0` + `.gate_pass` ==
  `bash scripts/gate_state_hash.sh`). Skipping `zig build lint` (~2s) before the
  full gate when you delete/delegate a body or add a file — `no_unused` fires
  ONLY in the full gate (memory `zlinter_unused_only_full_gate`). Re-introducing
  a v0-style `defining_ns` current-ns restore (display-only, ADR-0119 §4).
  Editing `.claude/rules/*` (permission-blocked → carry-over). Pinning a zwasm
  v2 tag (F-001).

## Done this session (error-display overhaul, user-directed)

- **Caret** (ADR-0118 cycle 2.5, 3673427a): arg-precise carets on the culprit.
- **Naming** (ADR-0119 Stage 1, 2987c69f): functions carry name+defining_ns on
  the value (restored the v1-redesign regression; clj/v0/SCI all have it).
- **Trace** (ADR-0119 Stage 2, 5bf5ba61): runtime `Trace:` + EDN `:trace`,
  dual-backend, pushed at the shared `treeWalkCall` choke point.
- **Trace discipline** (D-332/AD-024, b21875fd): show USER frames, elide
  `clojure.*`/`cljw.*` stdlib + host builtins via the uniform `isUserNs` rule
  (not ad-hoc) — user-directed.
- **Cross-thread fidelity** (ADR-0120 A+B, a8b88c35 + cd874800): ExInfo carries
  `origin_loc`; a neutral `worker_error.{capture,reraise}` marshals a worker's
  error into a GC-heap exception (kind-class+message+location) for future/agent
  — `@(future (/ 1 0))` shows the real error, catchable by its class. Fixed the
  agent wrong-class bug. pmap is sequential (no wiring).
- **Execution-point lines** (D-334, 17033efc): frames show their OWN file/line
  (`info.updateTopFrame`), fixing the cross-module ns/file mismatch.
- **Verified** (f403c6a2): per-thread isolation (D-329 DISCHARGED), multi-module
  require traces (D-331).

## Remaining tail (tracked)

- **D-336**: trace across the thread boundary (next; see resume contract).
- **D-333**: post-mortem `render-error` decoder reads EDN `:trace` (nested parse).
- **D-328**: `pr`/`str` of a fn shows its name (couples to `(class fn)` format).
- **D-325**: `(fn name ..)` self-name (needs an analyzeFnStar self-name arm).

## Process discipline (SSOT = memory + rules)

- Full gate (shared-code): `timeout 1800 bash test/run_all.sh --serial-e2e`;
  verify Summary `failed: 0` + `.gate_pass` == `gate_state_hash.sh`. `zig build`
  (not `zig build test`) rebuilds `zig-out/bin/cljw`. Backend default = vm
  (F-012). Tool channel corrupts stdout under load — verify cljw output via
  per-cmd files + Read, not chained echoes.

## Cold-start reading order (tracked-only)

handover → **`private/notes/phase14-d336-trace-across-boundary.md`** (turn-key
D-336 plan + the arena-string-lifetime insight) →
`.dev/decisions/0120_cross_thread_error_fidelity.md` (Stage A note + DA) →
`.dev/decisions/0119_callable_naming_surface.md` (naming + trace discipline) →
`.dev/decisions/0118_error_display_v0_level.md` (caret/cycle base) →
`.dev/debt.yaml` D-336/333/328/325 → `src/runtime/collection/ex_info.zig` (the
carrier) + `src/runtime/concurrency/worker_error.zig` → CLAUDE.md →
`.dev/principle.md`.

## Stopped — user requested

User instruction (2026-06-08): "さて、では、次のクリアセッションから継続できる
形に、配線・参照チェーンを確認して止めてOK" (verify the wiring + reference chain
so the next clean session can continue, then stop). Verified: working tree clean
of source (only this handover edit), HEAD 17033efc is gated (`.gate_pass` ==
`gate_state_hash.sh`), all reference-chain files + debt rows D-336/333/328/325
exist. Resume at D-336 (the "First commit MUST be" above). This section applies
to the previous session only — the next `/continue` deletes it and resumes the
loop unchanged.
