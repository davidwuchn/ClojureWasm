# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Stopped — user requested

User instruction (2026-05-27):
「OK、すみません、コンテキストウィンドウ肥大につきここまでのサーベイをむだにせず、
次のセッションに引き継ぎ作業続行できるようにしたい。いまとめてもいいかんじかな
（区切り的に）」.

Clean break — last commit is `6907b79` (row 8.4 close: `--compare`
CLI flag). Row 8.5 (D-074 transients) has Step 0 survey at
`private/notes/phase8-8.5-survey.md` (479 lines) — do NOT re-run;
re-read at resume. No row 8.5 source landed; cycle 1 plan
(TransientVector + transient! / persistent! / conj! / pop! /
assoc!-arity-3 + 2 error codes) is recorded in the survey.

## Resume contract

- **HEAD**: `6907b79` (row 8.4 close — `cljw --compare` CLI flag).
- **First commit on resume MUST be**: §9.10 row 8.5 cycle 1 —
  TransientVector + 4-of-7 primitives (`transient!` / `persistent!`
  / `conj!` / `pop!`) + `transient_used_after_persistent` +
  `transient_kind_mismatch` error catalog Codes. Per
  `private/notes/phase8-8.5-survey.md` cycle decomposition (a):
  cycle 1 = TransientVector + scaffolding (3 of 7 primitives
  vector-only) → cycle 2 = TransientArrayMap → cycle 3 =
  TransientHashSet + discharge `feature_deps.yaml#clojure.set/map-invert`.
  HAMT `TransientHashMap` blocked on D-045 — cycle 2 stays
  ArrayMap-only.
- **Forbidden this session**: (a-j) per row 8.1 close handover
  carried forward (apply variadic threadlocal / pub-var injection
  / vector-with-metadata zipper etc.). (k) cw v0's 6.2K-LOC
  `collections.zig` mega-file shape — row 8.5 follows
  `.dev/structure_plan.md` + ROADMAP A2 with `runtime/collection/
  transient/{transient_vector,transient_array_map,transient_set}.zig`
  one-file-per-type. (l) `(and ...)` macro in non-core .clj
  defns — row 7.13 cycle 1 surfaced a bug; use explicit `if`.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.10 → `.dev/debt.md`
Step 0.5 sweep (D-074 active; D-045 HAMT blocking TransientHashMap;
D-093/D-094 opportunistic carry-overs) → re-read
`private/notes/phase8-8.5-survey.md` for the row 8.5 cycle 1 plan.

## Current state

Phase 8 IN-PROGRESS — §9.10 rows 8.0..8.4 all [x]. Row 8.5 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 60/60 +
OrbStack Ubuntu x86_64 59/59. ADR-0027 + bench/history.yaml +
`bench/record.sh` + `scripts/check_bench_regression.sh` (1.2x
informational gate, Mac/Linux locks seeded) + `cljw --compare`
all landed across rows 8.2-8.4.

## Active task — §9.10 row 8.5

D-074 — transients Tier-A surface (`transient!` / `persistent!` /
`conj!` / `assoc!` / `disj!` / `dissoc!` / `pop!`). Per F-006
3-layer allocator + `.dev/structure_plan.md` `runtime/collection/
transient/` subtree. Survey at `private/notes/phase8-8.5-survey.md`
recommends per-collection 3-cycle decomposition (TransientVector
→ TransientArrayMap → TransientHashSet+map-invert discharge);
TransientHashMap stays blocked on D-045 HAMT impl, cycle 2 raises
`transient_kind_mismatch` on `.hash_map` source (transient stub
shape, not silent fake). Tag slots 40/41/42 (transient_vector /
transient_map / transient_set) already reserved at
`src/runtime/value/heap_tag.zig:99-101` + `value.zig:87-89`; cycle
1 lands the first GC-traced impl behind those reservations.

## Extended challenge (per `.claude/rules/extended_challenge.md`)

- **Alt hypothesis**: rather than per-collection 3 cycles, land
  the TransientVector + TransientArrayMap + TransientHashSet trio
  in a single cycle to discharge `map-invert` PROVISIONAL atomically
  with all 7 primitives. Survey rejected this on smell-audit
  window + Step 5 bisect difficulty; resume could revisit if the
  per-collection scaffolding turns out near-zero overhead after
  cycle 1.
- **Next experiment**: write `src/runtime/collection/transient/
  transient_vector.zig` (~150 LOC) + add `transient_used_after_persistent`
  Code to `src/runtime/error/catalog.zig` + a TDD-red unit test
  `(persistent! (conj! (transient empty-vec) 42))` expecting a
  one-element persistent vector. Command: `zig build test 2>&1 |
  tail -30` after each Edit.
- **Explicit blocker**: none. All prereqs landed at HEAD.

## Guardrail refresh history

Phase 7 close + Phase 8 entry landmarks: ADR-0042 (apply variadic
bind-direct) + 0043 (defrecord ZipLoc) at Phase 7 close; ADR-0027
(bench/history.yaml schema, shape c per-commit aggregate +
cw-v1 machine bucket + distribution amendments) at Phase 8 row
8.2; row 8.1 `src/app/` split (cli/runner/error_render); row 8.3
1.2x regression gate informational mode + Mac/Linux locks; row
8.4 `cljw --compare` CLI flag (ADR-0005 full-bench remit).
