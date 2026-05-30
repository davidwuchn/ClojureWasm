# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (class/type ADR-0059 + record-equality + keyword-on-record landed 2026-05-31).
- **Direction (user, 2026-05-30)**: raise **functional completeness FIRST**
  (no premature JIT/superinstruction). Operating mode is **STRUCTURAL-DEFECT
  HUNTING, not ad-hoc gap-filling**: a large-input/edge `cljw -e` probe sweep that
  surfaces a wiring fault / unconnected scaffold / representation divergence /
  hidden O(n²) / non-TCO recursion → fix the **finished form (F-002)**, do the
  rework. METHOD + catalog in
  [`.dev/lessons/structural_defect_hunting.md`](lessons/structural_defect_hunting.md).
  Fully autonomous; flexible replanning.
- **First commit on resume MUST be**: continue the **structural-defect probe
  sweep** on unswept surface (dynamic vars / IO / seq edges / deftype field
  access). Concrete clean units queued: **var_ref print arm** — `(def x 1)`
  returns a runtime `.var_ref` Value that prints `#<var_ref>`; print.zig (env
  already imported) needs a `.var_ref => #'<ns>/<name>` arm via
  `var_ptr.ns.name`/`var_ptr.name`; then **`resolve`** — returns that same
  var_ref Value via `env.current_ns.resolve(name) ?*Var` (qualified → findNs).
  Always probe first (3x). Do NOT ask (Direction-ask smell). **Build-race
  caution**: chain `zig build && <probe>` — a stale binary gives STALE results.
- **Forbidden this session**: re-opening anything landed (sorted collections,
  transducers 1-5, D-159/160/161/162, crash fixes, dedupe/distinct O(n²),
  ad-hoc hierarchies, re-seq, read-string, eval, **satisfies?/extends? wrappers,
  class/type ADR-0059, defrecord value-equality, keyword-on-record**) or earlier
  (AOT, ratio-arith, HAMT, atoms). JIT/superinstruction (completeness first).
  Flipping `phase_at_least_14` / v0.1.0 (HELD).

## Current state

Mac gate green (169; gate cadence mechanically enforced). AOT-bootstrap LIVE
(ADR-0056). This session (git log is the SSOT): `satisfies?`/`extends?` wrappers
(+ `rt/__extends?`), **class/type → interned `.type_descriptor`** (ADR-0059:
`makeTypeDescriptorRef` interns one boxed Value/descriptor → bit-identity =
value-identity, zero equal.zig arms), and two structural-defect fixes from the
probe sweep: **defrecord value-equality** (`.typed_instance` arms in
valueEqual/keyEqValue/valueHash, defrecord structural / deftype identity) +
**keyword-on-record** (`(:k rec)` ≡ `(get rec :k)` via shared
`lookup.recordGet`). Prior: ADR-0057 sorted, transducers, eval (ADR-0058), D-161.

## Next milestone (F-010 M = Phase 15 完遂 + cw-v0-level JIT)

Coverage floor heavily advanced. Toward M: finish corpus-style coverage/
robustness sweep → **Phase 15** concurrency (ADRs 0009/0010) → superinstruction/
fusion → narrow ARM64 JIT (D-133) → **M** → quality loop. cw-v0 gaps in
`.dev/cw_v0_parity_and_gap_plan.md`.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-160** sequence/eduction (push→pull transducer bridge). **D-158** corpus-
  driven validation. **D-139** AOT param-name. **D-134** letfn + mapcat-multi-
  coll. **D-155/156** HAMT collision/dissoc-collapse. **D-150** VM ctor parity.
  **D-153** `(cons x lazy)` count. **D-152** diff oracle `.clj` closures.
  **D-131** built-app non-core. **D-117/118** nREPL (Phase-15). **D-133** JIT.
- **Verified-real gaps (clean 3x probe)**: `resolve`/`find-ns`/`ns-name`/
  `ns-publics`/`create-ns`/`intern`/`all-ns` → name_error (need Var/Namespace
  value reps; var_ref Value EXISTS, `.namespace` tag does NOT). `re-find` w/
  #"regex" literal → not_implemented. **`Long`/`String` etc not bound as Vars**
  → `(defmethod f Long …)` fails (class-dispatch multimethod half-works; native
  class-name binding decision pending). `supers`/`bases`/deftype `->Name`/
  `map->Name` missing.
- **Sweep gaps (low)**: `mapv`/`interleave` N-coll variadic; `reductions` O(n²);
  `uuid?` repr; `(class (class 5))`→`type_descriptor`, `(class fn)`→`fn_val`
  (`@tagName` fallback, acceptable); lazy-as-map-value `#<lazy_seq>`.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + Autonomous Workflow + The only stop) →
`.dev/project_facts.md` (F-010) → `.dev/principle.md` (Bad Smell + depths) →
`.dev/lessons/structural_defect_hunting.md` (resume MODE) →
`.dev/core_coverage_gaps.md` (sweep queue) → `private/notes/phaseA26-*.md`
(this session's probe-sweep finds + the var_ref/resolve next units).

Channel/load discipline (if tool output looks empty/duplicated/contradictory):
memory `tool-channel-corrupts-under-load` — suspect host load (`uptime`), write
to SENTINEL-marked /tmp files, run critical probes 3x. `Smell-audited: <DIGIT>:`
(hook rejects `depth`).
