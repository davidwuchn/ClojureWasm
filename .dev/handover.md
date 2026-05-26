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

- **HEAD**: see `git log` (row 7.10 close is HEAD).
- **First commit on resume MUST be**: §9.9 row 7.11 — Step 0
  survey for D-077 catch class name → type tag dispatch table
  (replaces the silent ExceptionInfo-only matching in
  `tree_walk.catchMatches` + `vm.matchExceptionClass`; both
  backends accept arbitrary class names today but silently fail
  match for any class other than ExceptionInfo). Reference:
  ROADMAP §9.9 row 7.11 + D-077 row in `.dev/debt.md`.
- **Forbidden this session**: (a) `return error.NotImplemented`
  in VM compile arms without `// VM-DEFER:` marker. (b) calling
  `TypeDescriptor.lookupMethod` directly — route via
  `dispatch(rt,env,cs,receiver,protocol,method,args,loc)` or
  `dispatchOrNull(...)`. (c) widening `BytecodeChunk.call_sites`
  beyond ADR-0040 without amendment. (d) manual `defer rt.gc.
  infra.destroy(...)` for ProtocolDescriptor / ProtocolFn /
  TypeDescriptorRef — row 7.7 cycle 1 `rt.trackHeap` owns destroy.
  (e) accessing dropped flat `FnNode.arity/.has_rest/.params/.body`
  — row 7.8 ADR-0041 lifted to `methods` slice + `variadic`.
  (f) re-introducing cw v0 threadlocal `apply_rest_is_seq` —
  row 7.9 ADR-0042 diverges (P4 + F-002); the one-bit-of-intent
  rides in call-frame shape, not in shared mutable state.
  (g) widening `isRestSeqShaped` tag set beyond `{.list,.cons,
  .chunked_cons,.lazy_seq,.nil}` without ADR-0042 amendment.
  (h) widening `BytecodeChunk.libspecs` semantics beyond row 7.10
  cycle 3 (= 1:1 mirror of `tree_walk.evalRequire`'s alias +
  refers loop) without amending the cycle 3 commit / ADR-0036.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.9 → `.dev/debt.md`
Step 0.5 sweep (D-077 row 7.11 + D-090..D-092 row 7.8 follow-ups).

## Current state

Phase 7 IN-PROGRESS — §9.9 rows 7.0..7.10 all [x]. Row 7.11 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 50/50 + OrbStack
Ubuntu x86_64 49/49.

## Active task — §9.9 row 7.11

D-077 — catch class name → type tag dispatch table. `(try ...
(catch ClassName e ...))` analyzer accepts any class symbol for
user-readability, but `tree_walk.catchMatches` +
`vm.matchExceptionClass` match only `ExceptionInfo` and silently
return false otherwise — `(catch ClassName ...)` for other class
names becomes dead code (Silent default-shift smell per
principle.md). Discharge: introduce a HostClass registry +
class-name-→-tag dispatch table, route both backends through it.
~190 LOC est. Sources: `tree_walk.zig::catchMatches` +
`vm.zig::matchExceptionClass`; debt row D-077 in `.dev/debt.md`.

## Open questions / blockers

None testable from inside the loop. Outstanding debt by ID: D-077
(this row), D-078 (`clojure.string` RED set Pattern A landing
gated on `instance?` ship), D-080 (`clojure.zip` Pattern A 28
vars, gated on Phase 7 deftype/defrecord — landed; opportunistic
now), D-081 (multimethod ergonomic surface; blocked-by D-012
Phase 15), D-083 (multimethod diff_test parity, opportunistic),
D-085 (keyword-as-fn, opportunistic), D-086 (defrecord
`__extmap`, dedicated cycle), D-087 (deftype Name var binding,
opportunistic), D-088 (protocol fqcn ns-prefix collision,
opportunistic), D-089 (row 7.7 Q6 retro-audit cluster — other
collection primitives needing hybrid slow-path, Phase 8+), D-090
(fn-body recur runtime loop, opportunistic), D-091 (defn
docstring + meta-map, opportunistic), D-092 (map-as-map-key
equality, Phase 8+).

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`.
Landmarks: Phase 6→7 boundary triad (ADR-0036/0037/0035 D9 2nd
amend); row 7.2 (ADR-0008 amend 2); row 7.3 (ADR-0008 amend 3 +
ADR-0038); row 7.5 (ADR-0039); row 7.6 (ADR-0040); row 7.7
(ADR-0008 amend 4 + latent-leak fixes); row 7.8 (ADR-0041 Option
B-extracted); row 7.9 (ADR-0042 Alt 3 — gated bind-direct
rest-pack); row 7.10 (ADR-0036 first real-feature exercise —
`op_require_with_libspec` + `BytecodeChunk.libspecs` side-table;
reify TypeDescriptor lifecycle hook).
