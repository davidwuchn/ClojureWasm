# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (the F-010 ordered-ladder + serialize-gate work below;
  Mac gate 306/0 green at each landing).
- **First on resume MUST be (autonomous, overnight, F-010 quality loop)**:
  **D-372** — the MAP side of the flatland.ordered ladder (the SET side fully
  landed via D-286/D-370/D-371). `flatland.ordered.map` blocks at map.clj:33
  bare `MapEquivalence`, then bare `IPersistentMap` (D-286b routing + identity
  entries) + the IPERSISTENT_MAP remap-table extension (valAt/iterator/entrySet/
  keySet/values). Definition-derived (F-013), mirrors the set-side work. Then the
  standing quality-loop floor drain (`quality_floor:` rows, correctness-first) per
  CLAUDE.md § The only stop.
- **Forbidden**: pushing to `main`. The fly demos (D-362) are DONE + live — not the
  autonomous focus.

## Just landed — flatland.ordered SET ladder complete + serialize gate

The F-010/F-013 convergence pattern (a real lib chains out gaps; close each
definition-derived, not per-lib):

- **D-365 residual** — bytecode-serializer CHUNK completeness gate: compile-time
  `std.meta.FieldEnum` exhaustiveness over the BytecodeChunk side-tables AND each
  entry struct (a new table/field is a compile error until classified) + a
  populated round-trip asserting every serialized field.
- **D-286 am1** (ADR-0102 am1) — the editable/transient collection interface family
  (IEditableCollection / ITransient* / IPersistentSet bare) + the **D-286b**
  dispatch fix (sectionNeedsRemap self-targeting recursion guard) so a deftype's
  clj-named methods dispatch.
- **ADR-0127 + D-370** — `print-method` is a real user-extensible multimethod the
  native pr path consults behind a dirty flag; A2 host_instance writer handle +
  B2(b-ii) per-element consult (nested overrides fire, clj parity).
- **D-371** — clojure.lang read/op methods (`.valAt`/`.cons`/`.count`/…) on NATIVE
  collections delegate to the clojure.core equivalent (clojure_lang_method.zig,
  both backends).
- **Result**: `(ordered-set 3 1 2 1)` → `#ordered/set (3 1 2)` — flatland.ordered.SET
  fully works (D-286→D-370→D-371 ladder complete). ordered.MAP is D-372.
- Follow-ups tracked: D-369 (transient dispatch consult — off the critical path),
  D-238 (bindable `*out*`).

## Process discipline (SSOT)

- Gate cadence: per-commit `--smoke <step>` (don't block); batch full
  `bash test/run_all.sh` at boundaries. The Ubuntu remote gate (ubuntunote,
  load-immune) is the fallback — `timeout 1800 bash scripts/run_remote_ubuntu.sh`
  against the pushed HEAD (run before the next Phase boundary / v0.1.0 tag).

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-372** = NEXT ordered.map; D-369/D-238 follow-ups;
`quality_floor:` rows = the floor drain) → `private/notes/D371-member-on-native.md`
(+ D286/D370 notes) → CLAUDE.md § Autonomous Workflow + F-010 quality loop.
