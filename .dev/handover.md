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

- **HEAD**: see `git log` (row 7.11 close is HEAD).
- **First commit on resume MUST be**: §9.9 row 7.12 — Step 0
  survey for D-078 `clojure.string` RED set Pattern A landing
  (`replace` / `replace-first` / `escape`). The row 7.11 host-class
  hierarchy provides the `instance?` substrate; survey must
  re-verify the other 3 D-078 prerequisites (sub-leaf split, `$1`
  capture group sugar from D-051 Pike NFA cycle 3, `escape` cmap
  divergence). Reference: ROADMAP §9.9 row 7.12 + D-078 row.
- **Forbidden this session**: (a) `return error.NotImplemented` in
  VM compile arms without `// VM-DEFER:` marker. (b) direct
  `TypeDescriptor.lookupMethod` — route via `dispatch(...)` /
  `dispatchOrNull(...)`. (c) widening `BytecodeChunk.call_sites`
  beyond ADR-0040 without amendment. (d) manual
  `defer rt.gc.infra.destroy(...)` for ProtocolDescriptor /
  ProtocolFn / TypeDescriptorRef — row 7.7 cycle 1 `rt.trackHeap`
  owns destroy. (e) accessing dropped flat `FnNode.arity/
  .has_rest/.params/.body` — row 7.8 ADR-0041. (f) cw v0
  threadlocal `apply_rest_is_seq` — row 7.9 ADR-0042 diverges;
  the bit rides in call-frame shape, not shared mutable state.
  (g) widening `isRestSeqShaped` tag set beyond `{.list,.cons,
  .chunked_cons,.lazy_seq,.nil}` without ADR-0042 amendment.
  (h) widening `BytecodeChunk.libspecs` semantics beyond row 7.10
  cycle 3 (= 1:1 mirror of `tree_walk.evalRequire`).
  (i) cw v0 `pub var exception_matches_class` injection — row 7.11
  diverges (ROADMAP §13 `pub var vtables` forbidden); import
  `host_class.matches` directly Layer 1 → Layer 0. Widening
  `host_class.ENTRIES` beyond 17-entry Throwable hierarchy needs
  co-issued `compat_tiers.yaml` + diff_test in the same commit.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.9 → `.dev/debt.md`
Step 0.5 sweep (D-078 row 7.12 + D-090..D-092 follow-ups).

## Current state

Phase 7 IN-PROGRESS — §9.9 rows 7.0..7.11 all [x]. Row 7.12 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 51/51 + OrbStack
Ubuntu x86_64 50/50 (catch hierarchy e2e + 5 diff cases added).

## Active task — §9.9 row 7.12

D-078 — `clojure.string` RED set Pattern A landing
(`replace` / `replace-first` / `escape`). The row 7.11 host-class
hierarchy now provides the `instance?` substrate; the other 3
D-078 prerequisites need re-verification: (a) `-str-replace-string`
/ `-str-replace-pattern` / `-str-replace-char` sub-leaf split of
the current Zig `replace`; (b) `$1` capture group sugar from
D-051 Pike NFA cycle 3; (c) `escape` cmap fn-arm divergence
(JVM returns Character/MapEntry; cw v1 narrows to keyword/char).
Step 0 survey expected.

## Open questions / blockers

None testable from inside the loop. Outstanding debt by ID:
D-078 (this row), D-080 (clojure.zip Pattern A 28 vars,
opportunistic), D-081 (multimethod ergonomic surface; blocked-by
D-012 Phase 15), D-083 (multimethod diff_test parity,
opportunistic), D-085 (keyword-as-fn, opportunistic), D-086
(defrecord `__extmap`, dedicated cycle), D-087 (deftype Name
var binding, opportunistic), D-088 (protocol fqcn ns-prefix
collision, opportunistic), D-089 (row 7.7 Q6 retro-audit cluster
— other collection primitives needing hybrid slow-path, Phase 8+),
D-090 (fn-body recur runtime loop, opportunistic), D-091 (defn
docstring + meta-map, opportunistic), D-092 (map-as-map-key
equality, Phase 8+). D-048 host-class wire-up unblocks the
`host_instance` arm of `host_class.matches` (tracked via new
entry `runtime/error/catch_class_host_instance_arm`).

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`.
Landmarks: Phase 6→7 boundary triad (ADR-0036/0037/0035 D9);
row 7.2 (ADR-0008 amend 2); row 7.3 (ADR-0008 amend 3 + ADR-0038);
row 7.5 (ADR-0039); row 7.6 (ADR-0040); row 7.7 (ADR-0008 amend 4);
row 7.8 (ADR-0041); row 7.9 (ADR-0042 — gated bind-direct
rest-pack); row 7.10 (ADR-0036 first real-feature exercise —
`op_require_with_libspec` + side-table); row 7.11 (host-class
hierarchy + analyzer-time `catch_class_unknown` raise — silent-
default-shift discharged at the source; cw v0 pub-var injection
rejected).
