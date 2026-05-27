# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (Phase 9 close commits — rows 9.0..9.6).
- **First commit on resume MUST be**: §9.12 Phase 10 task list
  open commit. Run the Phase 9 → 10 boundary review chain
  (`audit_scaffolding` + built-in `simplify` on the Phase 9 diff
  + built-in `security-review` on unpushed commits — parallel
  fan-out), then expand the §9.12 Phase 10 placeholder inline
  (mirror §9.11 structure) and commit alone with
  `git commit -m "roadmap: open Phase 10 task list"`.
- **Forbidden this session**: re-introducing `modules/<name>/<name>.zig`
  co-location without the build.zig surgery D-095 names — Zig
  0.16 `@import`/`@embedFile` reject cross-module-path access.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.12 placeholder →
`.dev/debt.md` Step 0.5 sweep (D-045 HAMT still blocking
TransientHashMap + map-overflow paths; D-085 keyword-as-fn
callable; D-086 defrecord `__extmap`; D-095 modules/<name>/.zig
co-location pending build.zig surgery).

## Current state

Phase 9 **DONE** — §9.11 rows 9.0..9.6 all [x]. Phase 10 is the
next PENDING phase per the §9 master table. Branch
`cw-from-scratch`. Gate green: Mac 69/69 + OrbStack Ubuntu
x86_64 68/68. Highlights of Phase 9:

- `modules/` top-level reservation + zone rule (row 9.1, D-034
  discharged)
- `clojure.edn/read-string` + formToValue widened to vector/map/set
  (row 9.2, side-effect: `(quote [1 2 3])` now JVM-parity)
- `clojure.data.json/{read-str,write-str}` via std.json (row 9.3)
- `clojure.data.csv/{read-csv,write-csv}` RFC 4180 hand-rolled (row 9.4)
- `clojure.tools.cli/parse-opts` minimum surface (row 9.5)
- Phase 9 exit smoke + D-007 self-host viability discharged (row 9.6)
- Phase 8 → 9 audit absorbed: ADR-0027 collision repaired
  (bench-schema renumbered to ADR-0044)

## Active task — §9.12 Phase 10 entry

Phase 10 placeholder ("namespaces + require + standard libraries
Tier A") needs scope reconciliation similar to Phase 9: cw v1
already has `require` + `(ns ...)` (Phase 6.16+) + 5 standard
libraries embedded (`clojure.string` / `.set` / `.walk` / `.zip`
+ Phase 9's `.edn` / `.data.json` / `.data.csv` / `.tools.cli`).
Phase 10 entry owner reviews what's actually outstanding —
likely candidates: `clojure.pprint`, `clojure.java.io` (cw-native
rewrite), `clojure.java.shell`, host stdlib second wave per
ADR-0029 D5 (Java time / regex / BigDecimal), namespace
require/refer/alias polish.

## Extended challenge (per `.claude/rules/extended_challenge.md`)

Not applicable — the loop is rolling through Phase 9 close into
Phase 10 open; no user-requested stop is in flight.

## Guardrail refresh history

Phase 9 landmarks (closed 2026-05-27): formToValue collection
lift (analyzer.zig) + 4 new namespaces + new top-level `modules/`
reservation + ADR-0044 (renumbered from ADR-0027 bench schema)
+ D-034 / D-007 discharged + D-095 minted for the future
build.zig modules co-location migration.
