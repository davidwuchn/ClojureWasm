# ADR-0115 — regex lookahead + honeysql host-interop

- **Status**: Proposed → Accepted
- **Date**: 2026-06-07
- **Discharges**: **seancorfield/honeysql** (Stage 1.3 verified_projects, 11th
  proof); **D-315** (the honeysql drip-feed park row).
- **Cross-refs**: ADR-0114 (NATIVE_EXTEND_TARGETS — extended with
  IPersistentMap), ADR-0087 (Singleton static fields), ADR-0050 am1
  (locale-independent casing), ADR-0059 (no-JVM class), F-002 / F-011 / F-013;
  `no_op_stub_forbidden` (the silent-semantic-drop ban that shaped Decision B).
  Debt D-320 (lookahead matcher fuse + perf). NO new AD (Decision B reaches full
  parity — see below).

## Context

honeysql (honey.sql) formats a Clojure map into parameterized SQL. The survey
predicted 2 blockers (Locale, regex lookahead); the probe loop surfaced **5**
(the F-013 "a lib is an N-blocker chain" pattern, see
`.dev/library_incorporation_playbook.md`). They land together (D-315 was parked
precisely to avoid the drip-feed of landing them one-per-cycle).

## Decision A — regex zero-width lookahead `(?=e)` / `(?!e)`

cljw's regex engine is a Pike NFA (Thompson thread-list VM, `runtime/regex/
match.zig`), NOT a backtracker. A lookahead is a **zero-width predicate** — the
same shape as the existing `.anchor` inst (which `addThread` already uses to drop
a thread on a failed zero-width test). Implementation:

- `Node.look {child, negate}` — parsed from `(?=` / `(?!` in `parseAtom`.
- `Inst.look {sub, negate}` — `sub` is `child` compiled to its own sub-Program
  (terminated by `.match`); `Program.deinit` recurses to free it.
- In `addThread` (the epsilon-closure), a `look` runs a nested
  `tryMatchAt(sub, input, pos)` anchored at the current position; the thread
  continues (consuming nothing) iff a match exists XOR negate.

~70 LOC across `compile.zig` + `match.zig`. clj-oracle bit-for-bit on the
honeysql `dehyphen` pattern + positive/negative/no-consume/re-seq/alternation
cases.

## Decision B — captures thread through a positive lookahead (FULL parity)

The first draft discarded captures inside a lookahead (a "capture-free" cut with
a proposed AD). The Devil's-advocate review (below) correctly flagged that a
**silently-dropped capture is the forbidden silent-semantic-drop**
(`no_op_stub_forbidden`: the user sees a successful match with a wrong group
vector), and that it does NOT qualify as an accepted divergence (the
justification was convenience, not a project invariant). So Decision B is the
**finished form**: a POSITIVE lookahead threads its inner capture groups into the
continuing thread (group indices share the global numbering, so the sub-match's
populated slots merge into the parent thread's `caps`); a NEGATIVE lookahead
exports no captures (JVM parity — it succeeds only when the sub fails). The
per-thread slot array already exists and is already copied, so the merge adds no
allocation. Result: `(re-find #"(?=(\w+))\w+" "abc")` → `["abc" "abc"]`,
bit-for-bit with clj. **No AD-024** — the divergence does not exist.

## Routine (not load-bearing — compat_tiers rows / table additions)

- **java.util.Locale/US + /ROOT** — OBJECT-valued static fields via the ADR-0087
  Singleton mechanism (`Singleton` enum + `locale_us`/`locale_root` + analyzer
  arm). gc.infra process-lifetime `.host_instance` singletons cached on `rt`
  slots (leaf — no rooting subtlety, the lesson of the 2026-06-07 revert). Neutral
  impl `runtime/locale.zig` (so `Runtime.deinit` + the analyzer reach the
  singletons without importing the `runtime/java/` surface tree — zone rule);
  surface `runtime/java/util/Locale.zig` owns the descriptor + static-field table.
- **String.toUpperCase/toLowerCase 2-arg Locale overload** — accept + ignore the
  Locale (cljw casing is locale-independent, ADR-0050 am1 → US/ROOT = the existing
  impl, F-011-faithful).
- **clojure.lang.IPersistentMap extend-TARGET** → `[array_map hash_map sorted_map]`
  in `NATIVE_EXTEND_TARGETS` (ADR-0114). Keyword/Symbol/IPersistentVector already
  resolve to a single native tag via `class_name`, so they need no row.
- **(.sym keyword)** → the underlying Symbol (`symbol (namespace k) (name k)`);
  `runtime/keyword_methods.zig` installs it on the `.keyword` native descriptor
  (the `namespace_methods.zig` pattern).

## Alternatives considered

Verbatim Devil's-advocate output (mandatory depth-≥2 review, fresh context):

> ### DECISION A — zero-width lookahead via nested `tryMatchAt`
> **Alt A1 — smallest-diff (as drafted):** the `look` inst runs a fresh
> `tryMatchAt` from inside `addThread`. The nested call uses a FRESH ThreadList,
> so the outer `seen` bitmap is untouched — no recursion-into-shared-state
> hazard. Greedy-longest is IRRELEVANT (the `look` only checks `!= null`), so
> `(?=a*)` correctly succeeds zero-width. The framing is sound on every
> existence-only question. Breaks: latent O(n·m) per look-eval blowup (two fresh
> ThreadList allocs + a full sub-scan per position per outer thread) — invisible
> for honeysql's `(?=\w)`, a real super-linear cliff for a finished-form engine;
> acceptable NOW under the optimization-deferral policy, but a perf debt.
>
> **Alt A2 — finished-form-clean:** keep the zero-width-predicate framing but
> replace the ad-hoc `tryMatchAt` re-entry with a named `lookaheadHolds(sub,
> input, pos)` helper carrying an explicit reentrancy/`seen`-disjointness contract
> + a stack-`seen` fast path for small sub-programs (the dominant case), removing
> A1's hot-path churn with no semantic change. The fully-fused single-pass variant
> (inline the sub-program's threads with a "in a zero-width assertion" flag) would
> kill the O(n²·m) entirely — the textbook Pike-VM lookahead — but is substantially
> more complex with a semantic trap (a lookahead is anchored/position-local while
> the parent thread-list advances globally; fusing risks correctness-fragility).
> Net: A2-as-named-helper is strictly cleaner with no semantic risk; A2-as-full-
> fuse is a later O-NNN perf optimization, not this cycle.
>
> **Alt A3 — wildcard (DISQUALIFIED, F-013 violation):** don't implement
> lookahead; rewrite honeysql's `(?=\w)` at its call site to dodge it. This is
> exactly the lib-specific patch F-013 forbids (`(?=e)` is a general regex
> feature; the root-cause fix is "implement lookahead"). Out of bounds.
>
> **Recommendation A: switch to A2 (named-helper form, NOT full-fuse).** Keep the
> `look` inst + zero-width framing (correct); make the excursion a named helper
> with explicit contract + stack-`seen` fast path. The full fuse is a future O-NNN.
>
> ### DECISION B — capture-free lookahead
> **Alt B1 — smallest-diff (as drafted, FORBIDDEN):** silently discard inner
> captures + record AD-024. Breaks: `(?=(\w+))\w+` compiles, runs, returns a
> match, and silently returns the WRONG group vector — the canonical
> `no_op_stub_forbidden` "user builds on a lie" failure. Recording an AD does not
> launder a silent-semantic-drop: per `accepted_divergences.md`'s own bar, the
> justification ("captures are hard to thread") is CONVENIENCE, not a project
> invariant, so it does NOT qualify as an accepted divergence. Disqualified.
>
> **Alt B2 — finished-form-clean:** thread captures through the positive
> lookahead. The slot array is ALREADY copied per-thread; the `look` inst merges
> the sub-match's set slots into the continuing parent thread's `caps`. FULL
> F-011 parity, NO AD-024 (eliminating the loss beats recording it). Cost is
> small: no new allocation, no new data structure (B1 has to deliberately zero
> capture_count; B2 just doesn't). Group-numbering already works (the parser
> assigns indices globally across the whole pattern incl. inside `(?=...)`).
> Negative lookahead exports no captures (JVM parity — nothing to capture).
>
> **Alt B3 — wildcard (the same-cycle backstop):** raise a LOUD
> `CompileError.NotImplemented` on a capturing group inside a lookahead. Better
> than B1 (no silent drop — the transient-stub row of the boundary table). Still
> a coverage gap under F-011; its legitimate role is the compile-time guard for
> any capture construct B2 doesn't yet cover (backreferences — already
> unsupported globally — nested-lookahead capture interplay), so no silent drop
> can ever occur.
>
> **Recommendation B: switch to B2** (thread captures through positive lookahead;
> delete AD-024), with B3's loud error as the backstop for any residual
> unsupported capture construct. B1 is FORBIDDEN, not merely suboptimal.
>
> ### One-line recommendations
> - A — switch to A2 (named helper; full fuse is a future O-NNN).
> - B — switch to B2 (full capture parity, delete AD-024); B3 loud-error backstop.

### Main-loop disposition (within the F-NNN envelope)

- **Decision A** — KEEP A1 (nested `tryMatchAt`); the DA confirms it is CORRECT
  (fresh ThreadList → `seen` disjoint, greedy irrelevant, recursion-safe). A2's
  only wins are perf (the O(n²·m) cliff) + a clarity refactor — both governed by
  the optimization-deferral invariant (memory `optimization-deferred-until-15-libs`)
  and recorded as **D-320** (named-helper + stack-`seen` + the eventual single-pass
  fuse), scheduled at optimization-resumption. Not a Cycle-budget-defer: the
  deferral is the optimization invariant, and the current shape is correct.
- **Decision B** — ADOPT B2 (full capture parity). This was NOT a deferrable
  preference: B1 (silent discard) is forbidden by `no_op_stub_forbidden`, so the
  compliant options were B2 (parity) or B3 (loud error). B2 is both cleaner AND
  small (captures already flow through `tryMatchAt`; the merge adds no
  allocation), so it ships now — **AD-024 is deleted**, the divergence does not
  exist. B3's loud guard is implicitly satisfied: backreferences are already a
  global `NotImplemented`, and nested-lookahead captures merge recursively, so no
  capture construct silently drops.

## Consequences

- The regex engine gains lookahead → honeysql + any lib using `(?=…)`/`(?!…)`
  loads, with full capture parity (no divergence).
- Object-valued static fields are a reusable pattern (the Singleton enum extends
  cleanly per feature).
- Perf: a quantified lookahead re-runs a nested sub-match per thread-per-pos
  (latent O(n²·m)); honeysql's single-step `(?=\w)` is negligible. D-320, deferred.
- D-315 (honeysql park) discharged; the library-incorporation campaign reaches 11
  proofs and goes to STAY (user directive 2026-06-07).
