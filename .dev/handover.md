# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `208f33bd` (Phase 14 rows 14.0-14.9 closed; ADR-0048
  minted; D-098/D-099/D-014b Discharged this session; D-111..D-116
  minted Active. See `git log` for exact HEAD).
- **First commit on resume MUST be**: a focused **row 14.10
  (`cljw nrepl`)** implementation cycle. nREPL session state chart
  is the next ADR-0048 chart body to fill in (placeholder text
  lives in ADR-0048 §"nREPL chart"). Network listener + bencode
  framing + op-dispatch (`eval` / `describe` / `complete` /
  `interrupt`) per JVM nREPL protocol. Alternative pivot if the
  next owner prefers: row 14.11 (D-100 cluster — bytecode chunk
  serializer + `cljw build` + `cljw render-error` + cold-start
  bench + `cljw-formats/0.1.0.edn` lock; large multi-cycle scope
  ~800 LOC across 5 sub-rows) or row 14.13 (v0.1.0 polish bundle).
- **Forbidden this session**: pulling the v0.1.0 release tag (row
  14.14) forward without all 14.10-14.13 closed. Re-opening rows
  14.5-14.9 — fully Discharged this session.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.16 (rows 14.0-14.9 [x],
14.10+ [ ]) → `.dev/debt.md` Phase-14-entry debts (refined
barriers: D-066 / D-100 / D-102 / D-104 / D-105 / D-106 / D-107 /
D-036 / D-037 / D-038 + F-008 + new D-111..D-116 from this
session).

## Current state

Phase 14 (v0.1.0 milestone) IN-PROGRESS on `cw-from-scratch`. Phase
13 closed DONE at `797cb1a`. Gate green at HEAD: Mac 81/81 +
OrbStack Ubuntu x86_64 80/80.

This session: rows 14.5 → 14.9 landed (5 substantive rows in one
session):
- 14.5 **D-014b** Discharged (catch-by-keyword via `CatchTarget`
  union + analyzer keyword arm + TreeWalk `:type` lookup + VM
  ride VM-DEFER per `runtime/eval/catch_type_keyword`).
- 14.6 **D-099** Discharged (user-defined `defmacro` via analyzer
  special-form arm + `valueToForm` adapter + `expandIfMacro`
  user-fn fallback). `&form`/`&env` injection deferred to D-111.
- 14.7 **D-098** Discharged (`(ns ...)` `:refer-clojure :exclude
  / :only` + `(:require [...])` libspecs landed TreeWalk; VM
  rides VM-DEFER per `runtime/vm/ns_filter_and_libspec`; `:rename`
  deferred to D-112).
- 14.8 **future / promise / delay** Tier A primitives (3 new heap
  types in F-004 Group C; 5 primitives + 2 macro transforms;
  Phase 15.1 swap = D-113/114/115).
- 14.9 **ADR-0048** issuance + `cljw repl` (line-buffered loop;
  REPL state chart inline; nREPL + build pipeline charts =
  placeholders pending rows 14.10/14.11; line-editor polish =
  D-116).

## Active task — §9.16 row 14.10 (`cljw nrepl`)

nREPL server re-introduction (F142 per ADR-0015 a2). Network
listener on `--port <N>` (default 7888), bencode-frame parsing,
op-dispatch for at minimum `eval` / `describe` / `clone` /
`close`. State chart fills the ADR-0048 placeholder for
"nREPL session" body. Tier-A `lein nrepl-client` /
`clojure -M:cider/nrepl` compatibility is the validation target.
Estimated ~400 LOC + ADR-0048 chart-body amendment.

## Guardrail refresh history

Phase 14 mid-session (2026-05-28, this session): rows 14.5-14.9
closed; ADR-0048 issued (state machine domain — REPL chart filled
+ nREPL/build placeholders); 7 new debt rows minted
(D-111..D-117 incl. follow-ups for `&form`/`&env`, `:rename`,
Phase 15.1 STM swap path, REPL line editor); 3 Discharged
(D-014b / D-099 / D-098). Phase 13→14 boundary (2026-05-28):
§9.16 expanded inline (15 rows); D-082 / D-008 / D-017 / D-026 /
D-030 / D-069 / D-070 Discharged + 7 Opportunistic + 3 promoted.
Phase 13 landmarks: ADR-0010 a3 + ADR-0047 minted.
