# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Operating mode (user directive 2026-05-27)

完全自律で進める。`[x]` flip / feature_deps status flip / ADR
"Selected:" 確定 / DA subagent の "Recommendation" 採用 等の
framework boundary では **pause + PushNotification しない**。
CLAUDE.md § The only stop の "only user explicit stop halts the
loop" を operative rule として運用し、autonomous-tick framing の
"Reaching for justifications, wait" heuristic は採らない。row /
ADR / cycle 境界はそのまま次の Step 0 survey に roll する。

## Resume contract

- **HEAD**: see `git log` (Phase 7 close + Phase 8 opened is HEAD).
- **First commit on resume MUST be**: §9.10 row 8.1 — Step 0
  survey for D-031 `main.zig` → `src/app/` split. The anticipated
  `src/app/` layout lives in `.dev/structure_plan.md`; the split
  must land before the self-host loader (Phase 10 nREPL) /
  build-runner (Phase 12) modes pile on. Reference: ROADMAP §9.10
  row 8.1 + D-031 in `.dev/debt.md` + `.dev/structure_plan.md`.
- **Forbidden this session** (carried from Phase 7): (a) `return
  error.NotImplemented` in VM compile arms without `// VM-DEFER:`
  marker. (b) direct `TypeDescriptor.lookupMethod` — route via
  `dispatch(...)`. (c) widening `BytecodeChunk.call_sites` /
  `.libspecs` beyond ADR-0040 / row 7.10 cycle 3. (d) manual
  `defer rt.gc.infra.destroy(...)` for ProtocolDescriptor /
  ProtocolFn / TypeDescriptorRef. (e) accessing dropped flat
  `FnNode.arity/.has_rest/.params/.body`. (f) cw v0 threadlocal
  `apply_rest_is_seq` — row 7.9 ADR-0042 diverges. (g) widening
  `isRestSeqShaped` tag set without ADR-0042 amendment. (h) cw v0
  `pub var exception_matches_class` injection — row 7.11/7.12
  diverge. (i) cw v0 vector-with-metadata zipper — row 7.13
  ADR-0043 permanent finished form. (j) `(and ...)` macro in
  non-core `.clj` defns — zip.clj cycle 1 surfaced a bug; use
  explicit `if` until audit.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.10 → `.dev/debt.md`
Step 0.5 sweep (D-031 row 8.1 + D-007 / D-074 / D-089 entry
debts + D-093 / D-094 carry-overs).

## Current state

**Phase 7 DONE** (closed 2026-05-27, commit `6a339c1`). Phase 8
IN-PROGRESS — §9.10 expanded; row 8.0 boundary work
[x] (absorbed into this commit). Row 8.1 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 58/58 +
OrbStack Ubuntu x86_64 57/57.

## Active task — §9.10 row 8.1

D-031 — `main.zig` → `src/app/` split. The current `main.zig` is
~270 LOC including bootstrap-loader, REPL wiring, top-level error
renderer, build-options test, and the test-aggregator block.
Phase 8 entry split before Phase-10 nREPL / Phase-12 build-runner
modes pile on. `.dev/structure_plan.md` (F-003 structural plan)
predicts an `src/app/` layout with `src/app/repl.zig` / `src/app/
runner.zig` / `src/app/builder.zig` / `src/app/{cli,error_render}.zig`
sub-files; the split itself is mechanical extraction with `main.zig`
shrinking to a thin dispatcher (mode selector based on argv).
Step 0 survey expected.

## Open questions / blockers

None testable from inside the loop. Outstanding debt: D-007
(self-host viability, Phase 8 entry candidate), D-074 (transient!
surface, Phase 8 row 8.5), D-089 (row 7.7 retro-audit cluster,
Phase 8+ row 8.6), D-081 (multimethod ergonomic, blocked-by D-012
Phase 15), D-083/D-085/D-086/D-087/D-088/D-090/D-091/D-092
(Phase 7+ opportunistic), D-093 (regex `$N` sugar — D-051
cycle 3), D-094 (clojure.string/escape Pattern A migration).
D-048 host-class wire-up unblocks shared `host_instance` arm.

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`.
Phase 7 landmarks: ADR-0036 (dual-backend parity contract), 0037
(symbol heap value), 0038 (analyzer def pre-register), 0039
(reified instance), 0040 (VM method dispatch opcodes), 0041
(multi-arity fn*), 0042 (apply variadic peel-and-pass), 0043
(defrecord ZipLoc — clojure.zip representation). Row 7.11 +
7.12 introduced `host_class.zig` + `class_name.zig` shared
predicates (Layer 1 → Layer 0 direct import, cw v0 pub-var
injection rejected). Row 7.13 closed clojure.zip 31 vars per
ADR-0043 forward-commitment. Phase 7 closed at row 7.14 +
7.15 (`6a339c1`).
