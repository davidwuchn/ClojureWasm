# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (≈ `4d32b716`). Recent coverage-floor landings (all
  pushed): interop cluster (`.instance_member` am1 / `Math` static + `java.lang`
  auto-import / `.static_method` VM am2); overnight self-perpetuation hooks
  (`scripts/{post_commit_remind,gate_continue_remind}.sh`); **D-076 destructuring
  COMPLETE** (cycles 1-4: `let` seq+assoc, `fn`/`defn` params, `loop` macro+
  destructure — `macro_transforms.zig`); **D-151 cycle 1** (array_map keys
  String by value — `equal.keyEqValue`, 4d32b716). Mac gate 113/113.
- **First commit on resume MUST be**: **D-045 — HAMT (`.hash_map`) +
  `valueHash`** (= D-151 cycle 2). Today maps >8 entries hit a HARD WALL:
  `map.zig` `.hash_map` arms raise `HashMapPromotionNotImplemented` (assoc past
  the 8-entry array_map threshold) / `HashMapNotImplemented` (get on a hash_map)
  — so any map literal or `assoc`/`into` growing beyond 8 keys ERRORS. Implement
  the CHAMP-style HAMT body per `private/notes/phase5-5.5-survey.md` (the day-1
  struct shapes exist in `map.zig`) + a `valueHash(v) u32` (sibling to
  `equal.keyEqValue`, byte-hash strings) honouring the equal/hash contract
  (a=b ⇒ hash(a)=hash(b)). **Step 0 survey FIRST** (run AFTER any gate, never
  concurrent — perf-gate contention). Smallest red: `(get (into {} (map (fn [i]
  [(str i) i]) (range 20))) "5")` → 5 (today raises). This also lifts the
  D-151 string-key fix to >8-key maps + the `:strs` destructure at scale.
- **Forbidden this session**: re-opening interop / D-076 (all DONE). Putting
  destructure anywhere but `macro_transforms.zig` (single Layer-1 home).
  Threading `rt`/`env` through `map.get`/`contains`/`assoc` for key equality
  (the no-`rt` `keyEqValue` is the contract — ~68 call sites). Flipping
  `phase_at_least_14` / tagging v0.1.0 (release HELD). Opening Phase 15
  (concurrency/STM) — it deserves a fresh-context entry; the coverage floor
  (D-045 HAMT, the >8-key wall) is the JIT prerequisite (D-133) and the right
  interim work. Dispatching a CPU-heavy survey subagent CONCURRENTLY with a
  gate (contends with cold_start → false fail; gate_continue_remind.sh warns).

## Current state

Phase 14 v0.1.0 substantive work DONE; release HELD. Mac gate 113/113.
Interop coverage cluster CLOSED (both backends). Destructuring (D-076)
COMPLETE — `let`/`fn`/`defn`/`loop`, sequential+associative+nested+`&`+
`:as`/`:or`/`:keys`/`:syms`/`:strs`. Map string keys work by value (D-151
cycle 1, array_map). Advancing the coverage floor (D-133, JIT prereq);
the live wall is maps >8 entries (D-045 HAMT, next). F-010-ordered gaps
(JIT / nREPL / line-editor / Wasm-Component / deps) deferred. Overnight
loop self-perpetuates via the commit + gate reminder hooks.

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

Coverage floor (D-133 prereq for the JIT): D-045 HAMT (next — the >8-key
map wall) + core-cluster residuals → **Phase 15** (concurrency;
STM/agents/locking, ADRs 0009/0010; unblocks D-117/D-118 nREPL — a
fresh-context entry) → superinstruction/fusion → narrow ARM64 JIT
(D-133) → **M** → quality-elevation loop (`docs/works/`). cw-v0 gap plan
in `.dev/cw_v0_parity_and_gap_plan.md` (§A26).

## Open debts (named; full rows in `.dev/debt.md`)

- **D-045** HAMT `.hash_map` body + `valueHash` (the >8-key map wall;
  D-151 cycle 2). **D-150** VM `op_ctor_call` cljw-prefix parity gap.
  **D-148** `Math/PI`/`Math/E` static-field read. **D-149** whole-float
  `.0` print. **D-147** `fn*` self-name slot. **D-134** clojure.core
  (`partition` 4-arg pad + comp/juxt multi-arity). **D-143** apply
  multi-arity spread. **D-142** Env-scope `*error-context*`. **D-141**
  bench multi-lock. **D-105/D-106** time/net+crypto. **D-116** line-editor.
  **D-117/D-118** nREPL (Phase-15-gated). **D-075** metadata. **D-133** JIT
  floor. (D-076 / D-130 / D-136 / D-137 discharged.)

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ `private/notes/phaseA26-d151-map-string-key-survey.md` (the map-key
survey; the D-045 HAMT cycle 2 is §"Cycle 2") + `private/notes/phase5-5.5-survey.md`
(the original HAMT layout) → `src/runtime/collection/map.zig` (the
`.hash_map` arms that raise) + `src/runtime/equal.zig` (`keyEqValue`, the
`valueHash` sibling-to-add) → ROADMAP §A26 + `.dev/cw_v0_parity_and_gap_plan.md`.
