# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`.
- **First commit on resume MUST be**: §9.9 row 7.3 cycle 4 first
  red — migrate `ProtocolDescriptor` from plain struct to extern
  struct with `HeapHeader` as field 0 (matching `MultiFn` /
  `ProtocolFn` from cycles 1-3). Decompose `fqcn: []const u8` →
  `fqcn_ptr + fqcn_len` and `methods: []const MethodEntry` →
  `methods_ptr + methods_len` (extern struct forbids fat
  pointers). Add `makeProtocol(rt, fqcn, methods)` factory +
  `asProtocol(val)` decoder. Update the cycle 3 ProtocolFn test
  to construct ProtocolDescriptor via the factory. Cycle 5 then
  lands the Layer-2 primitives (`__make-protocol!` /
  `__make-protocol-fn!` / `__extend-type!` / `satisfies?` /
  `extends?` / `extenders`) once ProtocolDescriptor is a
  Value-encodable shape.
- **Forbidden this session**: (a) re-deriving Phase 7 entry triad
  (T1 ADR-0036 + T2 ADR-0037 + T3 ADR-0035 D9 second amendment).
  (b) commits adding VM compile arm bodies of the form
  `return error.NotImplemented` without an adjacent `// VM-DEFER:`
  marker. (c) re-introducing evalInNs / op_in_ns auto-refer
  block. (d) calling `TypeDescriptor.lookupMethod` directly from
  new code — route through the 7.1 `dispatch(rt, env, cs,
  receiver, protocol, method, args, loc)` ABI. (e) Re-deriving
  row 7.2 multimethod shape (ADR-0008 amendment 2 Alt 1 binding).
  (f) Re-deriving row 7.3 cycles 1-3 — protocol_generation
  counter + extendTypeWithImpls + CallSite.cached_generation guard
  + ProtocolFn extern struct are all landed.

## Cold-start reading order

handover (this file) → CLAUDE.md (§ Project spirit + § Autonomous
Workflow + § The only stop) → `.dev/project_facts.md` (F-001..F-009)
→ `.dev/principle.md` (Bad Smell catalogue incl. "Dual-backend
drift") → `.dev/ROADMAP.md` §9.9 → ADR-0008 (entry ADR; amendment
2 = row 7.2 contract; amendment 1 Alt 1 = generation deferred to
7.3) → `private/notes/phase7-7.3-survey.md` (647-line survey;
§5 has the binding shape) → `feature_deps.yaml` → `.dev/debt.md`
(Step 0.5 sweep). Phase 7 entry triad: `ADRs 0035 / 0036 / 0037`.
Row 7.2 cycle notes: `private/notes/phase7-7.2-cycle{1..5}.md`.

## Current state

- **Phase**: Phase 7 IN-PROGRESS — §9.9 rows 7.0 [x] / 7.1 [x] /
  **7.2 [x]** (4d78871; multimethod ladder green, derive
  ergonomic + typed_instance walk + diff_test parity deferred via
  D-081 / D-082 / D-083). Row 7.3 cycles 1-3 landed in-session:
  cycle 1 (4f57ee6) Runtime.protocol_generation + extendTypeWithImpls;
  cycle 2 (b80d853) CallSite.cached_generation guard; cycle 3
  (25a9195) ProtocolFn extern struct + makeProtocolFn factory.
  Active = row 7.3 cycle 4 (ProtocolDescriptor extern migration).
- **Branch**: `cw-from-scratch`. v5 plan =
  `private/notes/clj_vs_zig_split_proposal_v5.md`.
- **Gate**: Mac 42/42 + OrbStack Ubuntu x86_64 42/42 green at
  HEAD `25a9195`.
- **VM-DEFER markers**: 4 active sites (3 deftype-family in
  `vm/compiler.zig` + 1 `require_libspec` in `compileRequire`).
  PROVISIONAL markers: D-070 join, D-074 map-invert, D-075 project
  + rename, D-076 rename-keys, D-077 catch_class_table.
- **Chapter cadence**: dormant per ADR-0025 + F-007.

## Active task — §9.9 row 7.3 cycle 4

Cycle 4 = ProtocolDescriptor heap-Value migration. The struct
currently lives as a plain `pub const ProtocolDescriptor = struct`
in `src/runtime/protocol.zig`. Cycle 5's `__make-protocol!`
primitive must return a `.protocol`-tagged Value (Group B slot
18, already declared in heap_tag.zig); that requires extern
struct + HeapHeader at offset 0 + fat-pointer decomposition.

After cycle 4 lands, cycle 5 ships the 6 Layer-2 primitives per
survey §5.6 (mirrors row 7.2 cycle 5b's primitive shape). Cycle 6
adds the macros (defprotocol / extend-type / extend-protocol)
per survey §5.1-§5.2 (mirrors row 7.2 cycle 5c). Cycle 7 e2e +
diff_test cases. Then row 7.3 [x] flip.

## Open questions / blockers

None testable from inside the loop. D-081 (derive ergonomic
surface) blocked-by D-012 (Atom + swap!, Phase 15 target);
neither blocks row 7.3.

## Guardrail refresh history (condensed)

Waves 1-16 (2026-05-23..26): F-NNN + Bad Smell + ADR-0029..0035 +
provisional-marker mechanisation + handover_framing hook. Phase
6→7 boundary triad (T1 ADR-0036 / T2 ADR-0037 / T3 ADR-0035 D9
second amendment) + audit-2026-05-26 clean. Row 7.2 close
(2026-05-26, 5 cycles + ADR-0008 amendment 2 Alt 1 macros over
primitives). Row 7.3 cycles 1-3 (2026-05-26, single session
continuation): protocol_generation foundation + cache guard +
ProtocolFn extern. D-081 / D-082 / D-083 carve out row 7.2's
deferred surface.
