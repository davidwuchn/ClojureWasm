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

- **HEAD**: see `git log` (row 7.12 close is HEAD).
- **First commit on resume MUST be**: §9.9 row 7.13 — Step 0
  survey for D-080 `clojure.zip` Pattern A 28 vars. The
  defrecord / deftype substrate (rows 7.4 / 7.5) already lands,
  and `instance?` (row 7.12 cycle 1) is in place; verify whether
  any additional prerequisites remain (zipper representation
  choice — vector-of-pairs vs record? — is the central design
  question). Reference: ROADMAP §9.9 row 7.13 + D-080 row.
- **Forbidden this session**: (a) `return error.NotImplemented` in
  VM compile arms without `// VM-DEFER:` marker. (b) direct
  `TypeDescriptor.lookupMethod` — route via `dispatch(...)` /
  `dispatchOrNull(...)`. (c) widening `BytecodeChunk.call_sites`
  beyond ADR-0040. (d) manual `defer rt.gc.infra.destroy(...)` for
  ProtocolDescriptor / ProtocolFn / TypeDescriptorRef — row 7.7
  cycle 1 `rt.trackHeap` owns destroy. (e) accessing dropped flat
  `FnNode.arity/.has_rest/.params/.body`. (f) cw v0 threadlocal
  `apply_rest_is_seq` — row 7.9 ADR-0042 diverges. (g) widening
  `isRestSeqShaped` tag set without ADR-0042 amendment. (h)
  widening `BytecodeChunk.libspecs` semantics beyond row 7.10
  cycle 3. (i) cw v0 `pub var exception_matches_class` injection
  — row 7.11 + 7.12 diverge; `host_class.matches` /
  `class_name.isInstance` are imported directly via Layer 1 →
  Layer 0; widening `host_class.ENTRIES` or
  `class_name.NATIVE_ENTRIES` requires co-issued
  `compat_tiers.yaml` + diff_test in the same commit.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009) →
`.dev/principle.md` → `.dev/ROADMAP.md` §9.9 → `.dev/debt.md`
Step 0.5 sweep (D-080 row 7.13 + D-093/D-094 row 7.12 follow-ups).

## Current state

Phase 7 IN-PROGRESS — §9.9 rows 7.0..7.12 all [x]. Row 7.13 next.
Branch `cw-from-scratch`. Gate green at HEAD: Mac 53/53 + OrbStack
Ubuntu x86_64 52/52.

## Active task — §9.9 row 7.13

D-080 — `clojure.zip` Pattern A 28 vars (`zipper` / `vector-zip`
/ `seq-zip` / `xml-zip` / `node` / `branch?` / `children` /
`down` / `up` / `right` / `left` / `root` / `replace` / `edit` /
`insert-child` / etc.). Substrate (defrecord / deftype landed at
rows 7.4 / 7.5, `instance?` landed at row 7.12 cycle 1) is
sufficient. Central design question is the zipper representation
— vector-of-pairs (closer to Clojure's `[node loc-meta]` shape)
vs `defrecord ZipLoc [...]` (more cw v1-idiomatic + faster field
access). Step 0 survey expected to enumerate the choice + scope
the 28-var dependency graph (some defns compose on others —
`(up)` calls `(left)` etc.).

## Open questions / blockers

None testable from inside the loop. Outstanding debt by ID:
D-080 (this row), D-081 (multimethod ergonomic surface;
blocked-by D-012 Phase 15), D-083 (multimethod diff_test parity,
opportunistic), D-085 (keyword-as-fn, opportunistic), D-086
(defrecord `__extmap`, dedicated cycle), D-087 (deftype Name var
binding, opportunistic), D-088 (protocol fqcn ns-prefix collision,
opportunistic), D-089 (row 7.7 Q6 retro-audit cluster, Phase 8+),
D-090 (fn-body recur runtime loop, opportunistic), D-091 (defn
docstring + meta-map, opportunistic), D-092 (map-as-map-key
equality, Phase 8+), D-093 (`-str-replace-pattern` `$N` literal
pass-through PROVISIONAL — D-051 cycle 3 closure), D-094
(`clojure.string/escape` Pattern A migration — opportunistic when
char-literal + codepoint-walk primitives mature). D-048 host-class
wire-up unblocks the shared `host_instance` arm of
`host_class.matches` + `class_name.isThrowableTag`.

## Guardrail refresh history

See `git log -- .claude/rules .dev/decisions .dev/principle.md`.
Landmarks: Phase 6→7 boundary triad (ADR-0036/0037/0035 D9);
rows 7.2-7.6 (ADR-0008 amends + ADR-0039 + ADR-0040); row 7.7
(ADR-0008 amend 4); row 7.8 (ADR-0041); row 7.9 (ADR-0042 — gated
bind-direct rest-pack); row 7.10 (ADR-0036 first real-feature
exercise); row 7.11 (host-class hierarchy + analyzer-time
`catch_class_unknown`); row 7.12 (`instance?` macro + class_name
registry + 6 `-str-replace-*` leaves + Pattern A replace /
replace-first; cw v0 pub-var injection rejected).
