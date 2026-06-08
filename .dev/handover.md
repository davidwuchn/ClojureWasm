# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: newest pushed = **7ba484ae** (docs: flow wiring). Error-display
  cycles 1 + 2 + 2.5 (locations + window + arg-precise caret) DONE + pushed
  (3673427a). Working tree clean of source.
- **First commit on resume MUST be: ADR-0119 Stage 1 — function naming on the
  value.** This is a settled FOUNDATIONAL effort (user-directed 2026-06-08):
  cw v1's redesign dropped the fn-name + defining_ns that cw v0, Clojure JVM
  (`Compiler.java:4558` — even anon → `fn__<id>`), and SCI all carry. The
  trace (old "cycle 3") is now **Stage 2** and consumes these names. Read FIRST:
  **`private/notes/phase14-cycle3-naming-investigation.md`** (the file:line map)
  + **`.dev/decisions/0119_callable_naming_surface.md`** (decision = Alt 3 "name
  on the value", NOT the DA-recommended Alt 2; the 3 naming cases; the
  arena-borrow string-ownership call).
- Stage 1 sites: `FnNode`(node.zig:212)+`Function`(tree_walk.zig:129) gain
  `name`+`defining_ns`; allocator literals tree_walk.zig:263/301/399 + VM
  reconstruct vm.zig:499 carry them; analyzer threading = `analyzeDef`
  post-patch (special_forms.zig:~547) + `analyzeFnStar` gensym-for-anon
  (bindings.zig:107) + `analyzeLetfn` post-patch; consumer = `pr`/`str` of a fn
  shows the name; dual-backend diff test on `(str a-named-fn)`.
- **Forbidden**: trusting a bg-gate notification's exit code (verify ONLY via
  `SENTINEL-EXIT` / Summary `failed: 0` + `.gate_pass` ==
  `bash scripts/gate_state_hash.sh`). Re-introducing a v0-style `defining_ns`
  current-ns restore (v1 resolves vars at analyze time → display-only, ADR-0119
  §4). `gpa.dupe`/intern for the fn-name (borrow the analyze arena like
  `params`, ADR-0119 §2). Editing `.claude/rules/*` (permission-blocked →
  carry-over). Pinning a zwasm v2 tag (F-001).

## Verification discipline (user-directed 2026-06-08)

Do NOT run the full e2e gate (`test/run_all.sh`, ~300s) every iteration.
During TDD use **lightweight local checks**: `zig build test` (unit, Debug,
fast) for the touched unit + `zig build` then `cljw -e '…'` probes written to a
file and Read back (tool channel corrupts stdout under load — never chain
echoes). Full gate (`timeout 1800 bash test/run_all.sh --serial-e2e`) only at
**commit boundaries** for shared-code changes (gate-cadence rule). Ubuntu =
lightweight/milestone checks, not per-iteration.

## ADR-0119 staging (callable naming → trace)

- **Stage 1 — naming on the value** (`pr`/`str` observable): NEXT. 3 naming
  cases (defn/def, anonymous gensym, letfn); case 2 `(fn name ..)` deferred
  (D-325).
- **Stage 2 — `Trace:`** (ADR-0118 cycle 3 trace, consumes the names):
  `calleeName` resolver (all callable kinds; elide builtin/collection/keyword) +
  revive info.zig frame stack + push at `treeWalkCall` (skip-on-`.var_ref`) +
  `Info.trace` snapshot pop-on-both + renderer `Trace:` + EDN `:trace` + decoder
  + parity (nested error identical; recur → 1 frame).
- **Stage 3 — deferred**: D-325 (fn self-name), D-326 (interop method frames),
  D-327 (builtin `pr` reverse-name).

## CFP brush-up (D-324) — de-prioritized

User said (2026-06-08) not to optimize for CFP timing; the naming route is a
deliberate foundational effort instead. D-324 (Playground / Edge Demo / docs /
usability, user-interactive) remains a future track, no longer a near-term
driver.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- `zig build` (NOT `zig build test`) rebuilds `zig-out/bin/cljw`; `zig build
  test` only builds the unit-test binary. Backend default = vm (F-012). Docs
  (`.dev/`, ADRs, this file) do NOT change the gate fingerprint. e2e use BARE
  exprs (cljw -e of `(prn X)` echoes X then nil).
- Both backends touched → dual-backend parity diff test mandatory in each
  source commit (ADR-0036).

## Cold-start reading order (tracked-only)

handover → **`private/notes/phase14-cycle3-naming-investigation.md`** (file:line
map, areas A-H + the 8 change groups) → **`.dev/decisions/0119_callable_naming_surface.md`**
(decision + Alternatives) → `.dev/decisions/0118_error_display_v0_level.md`
(Decision B, the trace consumer) → `.dev/debt.yaml` D-325/326/327 →
`src/eval/node.zig:212` (`FnNode`) + `src/eval/backend/tree_walk.zig:129`
(`Function`) → CLAUDE.md → `.dev/principle.md`.
