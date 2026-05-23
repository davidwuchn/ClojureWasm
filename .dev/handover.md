# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).
> Updated at session end; reads in < 30 sec at cold start.

## Next 6 files to read (cold-start order)

1. `.dev/handover.md` (this file) — recent landings + guardrail
   refresh log + active task pointer.
2. `CLAUDE.md` § Project spirit (top section, governs all other
   rules) + § Autonomous Workflow (Step 0 → 7 + the **3-condition
   closed stop list**, condition 3 = smell-cluster trip).
3. `.dev/project_facts.md` — **user-declared invariants the loop
   must treat as fact** even when ROADMAP / ADR text admits other
   readings. **8 entries** at 2026-05-24:
   F-001 (zwasm v2 unavoidable; carries own JIT + GC) /
   F-002 (finished-form wins; smallest-diff is tie-breaker not
   veto) / F-003 (decision-deferral on structural plans) /
   F-004 (NaN-box 64-slot day-1 incl. range / map_entry /
   tagged_literal / string_seq / array_seq / funcref / externref) /
   F-005 (numeric tower JVM-surface compatible, Zig-stdlib-affine
   internal) / F-006 (mark-sweep + 3-layer alloc; zwasm dual-heap
   with allocator injection) / F-007 (chapter cadence stays
   dormant — user trigger only, AI must not re-propose) /
   **F-008** (zwasm v2 ADR-0109 spec review + cw v1 stances on
   6 open questions; 2026-05-24).
4. `.dev/principle.md` — Bad Smell catalogue (8 entries) +
   Structural imagination phase + Devil's-advocate subagent
   mandate at depth ≥ 2.
5. `.dev/structure_plan.md` — anticipated directory tree
   Phase 5-20. Each Phase entry owner amends in place; this is
   the structural-imagination output map.
6. `.dev/ROADMAP.md` — find IN-PROGRESS phase in §9, take the
   first `[ ]` row in §9.<N>. At a Phase entry, read the
   placeholder's **Entry ADRs** + **Entry debts** + **Entry
   facts** lines and load every referenced ADR (incl. all
   Revision history amendments), `D-NNN` row, and `F-NNN`
   project fact.

## Current state

- **Phase**: Phase 4 IN-PROGRESS. §9.6 critical-path closed
  (4.0 / 4.0a / 4.1 / 4.2 / 4.3 / 4.4 / 4.5 / 4.6 / 4.7 / 4.8 /
  4.9 / 4.10 / 4.11 / 4.12 done). Cleanup wave: 4.13–4.24 done
  (status table refreshed 2026-05-23). Remaining §9.6 rows
  (4.25 / 4.26.a-f) — method_table skeleton + error-system
  migration.
- **Branch**: `cw-from-scratch` (long-lived; push free after gate
  green; never push to `main`).
- **Gate**: Mac 12/12 + OrbStack Ubuntu x86_64 11/11 green at
  HEAD. 🔒 fresh OrbStack run due at Phase 4 close.
- **Chapter cadence**: dormant per ADR-0025; existing chapters
  under `docs/ja/archive/`. `private/notes/<task>.md` continues.
- **Unpaired source SHAs**: irrelevant during dormancy. Resumption
  ADR re-engages chapter cadence.

## Guardrail refresh (post-2026-05-23 session)

User-directed correction across two waves:

**Wave 1 — guardrails**:

- **Project spirit** — added to CLAUDE.md top: finished-form
  cleanliness wins, shipping fast / avoiding rework are
  second-tier. Surgical big edits welcome.
- **Bad Smell catalogue** — `principle.md` gained 3 entries:
  **Smallest-diff bias**, **Reservation-as-bias**,
  **Progress-pressure**. P5 reframed as tie-breaker not veto.
- **Structural imagination phase** — `principle.md` new section
  governing reservation tables AND directory / file structure
  AND responsibility separation AND dependency graph. The loop
  imagines Phase 5-20 horizon, records gaps as debt, defers
  decisions to the owning Phase.
- **D-021 retired** — ADR number reservation = smell.
- **ADR-0029 → ADR-0025 renamed** — time-ordered numbering.

**Wave 2 — structural foresight debts (Phase 5-20 imagination
output)**:

- **D-027** — NaN-box layout 第二世代 (Phase 5 entry).
- **D-028** — cleanup-wave row audit, **per owning Phase**.
- **D-029** — `value.zig` split (Phase 5 entry, with D-027).
- **D-030** — `analyzer.zig` split (already above 1000 lines).
- **D-031** — `main.zig` → `src/app/` (Phase 8 entry).
- **D-032** — host `_placeholder.zig` removal procedure (Phase
  5 entry, first host class landing).
- **D-033** — `lang/primitive/` subdir restructure.
- **D-034** — `modules/` top-level (Phase 9 entry).
- **D-035** — 3rd-backend dispatch extraction (Phase 17 entry).
- **D-036** — **zwasm v2 inline-vs-Pod decision (Phase 16
  entry)**. wasm FFI confirmed unavoidable per user direction.
  zwasm v2 carries its own JIT + GC; territorial overlap with
  cw v2 Phase 5 GC + Phase 17 JIT needs Phase-16-entry design.

**Source normalisation executed in this session** (not deferred):

- `build.zig` `-Dwasm=false` option reverted (ADR-0006
  amendment 2).
- `src/runtime/binding_stack.zig` deleted (env.zig is the
  authoritative location for the dynamic-binding stack).

**Wave 3 — root-cause hardening (post-research)**:

User asked "why did all this happen on top of an already-laid
ROADMAP + guardrails?". A `general-purpose` subagent investigated
LLM long-context behaviour (2026-05-23, 24 tool uses, output at
`private/notes/llm_long_context_research.md` 523 lines) and
concluded the symptoms are not attention decay (CLAUDE.md is
re-injected every turn) but **CLAUDE.md's own "進め bias" +
autonomous loop's instruction centrifugation** (~80% combined).
Fix landed:

- **`.dev/project_facts.md`** (new) — user-declared invariants
  (F-001 zwasm / F-002 finished-form wins / F-003 deferral)
  read at every Phase entry (CLAUDE.md Step 1a).
- **CLAUDE.md stop list extended to 3 conditions** — condition 3
  is "smell depth ≥ 3 fires 2× in one cycle → ADR-phase mode
  switch" (not a stop, a mode change).
- **CLAUDE.md Step 6 + principle.md depth ≥ 2** — Devil's-advocate
  subagent with fresh context is mandatory before ADR accept;
  output embedded verbatim in "Alternatives considered".
- **`scripts/check_smell_audit.sh`** (new PreToolUse hook) —
  `git push` is physically blocked unless every unpushed
  source-bearing commit body contains `Smell-audited: <depth>:
  <one-line>`. This is the deterministic enforcement layer
  behind the probabilistic CLAUDE.md rule
  ("CLAUDE.md is a suggestion, hooks make it law").

**Wave 4 — direction confirmations (2026-05-24, post-research)**:

After deeper investigation
(`private/notes/struct_imagination_research.md`, 525 lines —
cw v0 GC + 45-tag enumeration / zwasm v1+v2 GC / Clojure JVM
140-class survey), the user confirmed directions on 4 structural
fronts. Captured as project_facts.md F-004 / F-005 / F-006 /
F-007 and threaded into the relevant debt rows (D-011 / D-014a /
D-027 / D-036) + ADR-0025 + ROADMAP §9.7 + §9.18 placeholders:

- F-004: NaN-box 第二世代 = 4×16=64 slot, 44-bit pointer.
  Day-1 type set absorbs F-004 enumerated additions (range /
  map_entry / tagged_literal / string_seq / array_seq /
  sorted_map / sorted_set / persistent_queue / wasm funcref /
  externref).
- F-005: Numeric tower = JVM-surface-compatible, Zig-stdlib-affine
  internal (BigInt via `std.math.big.int.Managed`, Ratio =
  (BigInt × BigInt), BigDecimal = (unscaled BigInt, i32 scale)).
- F-006: GC = mark-sweep + free-pool + 3-layer alloc (cw v0
  path). zwasm v2 heap remains separate; cw GC allocator
  injects into zwasm internal bookkeeping (avoids cw v0 D110
  dual-GC leak).
- F-007: Chapter cadence stays dormant. Resumption is
  user-triggered only; AI must not re-propose.

`.dev/structure_plan.md` (new) — anticipated directory tree
Phase 5-20 imagined per F-003 Structural imagination. Each Phase
entry's owner amends in place when actual decisions land.

**Wave 5 — zwasm v2 spec review (2026-05-24)**:

User shared `~/Documents/MyProducts/zwasm_from_scratch/docs/zig_api_design.md`
(zwasm v2 ADR-0109 Proposed). cw v1 reviewed it as consumer.
Findings:

- Pixel-perfect integration: §1 Allocator strict-pass = F-006;
  §3.4 heap separation = F-006 同文; §4.1 funcref encoding =
  F-004 ビット幅一致; §4.3 NaN-boxing-friendly bit ownership =
  zwasm v2 が cw v1 用に明示設計 (削られたら cw v1 設計が破綻、
  spec の continuance を要請).
- C2 alignment 懸念 (`>> 3`) は **F-004 第二世代と競合しない** —
  両 layout とも alignment shift = 3、 zwasm v2 `FuncEntity` が
  align(8) なら現状でも F-004 後でも乗る。
- §6 で zwasm v2 が cw v1 に振った 6 open questions に対する
  推奨回答を F-008 に pin。

Persisted:
- F-008 (project_facts.md) — zwasm v2 spec load-bearing 要素 +
  cw v1 推奨回答 6 個 + 構造的合意。
- D-037 (rewrite timing sync) / D-038 (5 confirmation requests
  awaiting zwasm v2 reply) / D-039 (io_interface vs WASI 責務
  分離) を debt.md に追加。
- D-036 description を F-008 反映に更新。
- ROADMAP §9.18 (Phase 16) placeholder の Entry debts / Entry
  facts に新 D-NNN / F-008 を thread。
- `structure_plan.md` の `src/runtime/wasm/` subtree を更新
  (engine / linker / marshal / trap_map / host_func / wasi
  各 zig file を foresight 追加)。
- Full draft of cw v1 → zwasm v2 feedback message:
  `private/notes/zwasm_v2_feedback.md` (gitignored, ready for
  user to forward manually).

## Active task — §9.6 / 4.25

`src/runtime/dispatch/method_table.zig` — `MethodEntry` struct
(interned symbol + fn ptr) and `CallSite` struct (`last_type` +
`last_method` cache slots) declaration. **But first re-read D-028**
— 4.25 is itself a skeleton-row candidate; consider whether the
smallest-diff landing or "Phase 7 entry: struct + dispatch
together" is the cleaner shape before writing the file.

**Retrievable identifiers**:

- ROADMAP §9.6 task 4.25, ADR-0008 (protocol dispatch unify),
  debt D-028 (cleanup-wave audit).
- The new file lives in a `src/runtime/dispatch/` subdirectory
  which does not yet exist — create it.

## Open questions / blockers

None testable from inside the loop. Recall triggers + follow-up
candidates live in [`debt.md`](./debt.md) (rows `D-005` through
`D-028`). Step 0.5 debt sweep walks them at resume; pay attention
to **D-027 / D-028** which encode the design surgery this
session's guardrail refresh anticipates.
