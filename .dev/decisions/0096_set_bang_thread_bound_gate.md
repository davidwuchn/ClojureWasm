# ADR-0096 — `set!` is a runtime thread-bound gate + a clojure.main-style baseline binding frame

- **Status**: Proposed → Accepted (2026-06-05)
- **Amends**: the `set!` special-form analysis (ADR-0036 dual-backend
  contract applies — the runtime gate lands in both backends). Partially
  discharges **D-241** (no clojure.main baseline binding frame) for the
  dynamic vars that already exist in cljw.
- **Driven by**: D-254 (`set!`-on-dynamic-var diverges from JVM in 3 ways),
  surfaced resuming the add-watch IRef campaign.

## Context

Oracle-confirmed JVM `Var.set(val)` rule: `(set! v val)` succeeds **iff `v`
is thread-bound on the current thread**; otherwise it throws
`"Can't change/establish root binding of: <sym> with set"`. There is **no
compile-time dynamic check** — a non-dynamic var simply can never be
thread-bound, so it hits the same throw. `set!` NEVER mutates a var's root.
`clojure.main` establishes ~21 baseline thread bindings around eval (incl.
`*warn-on-reflection*`, `*unchecked-math*`, the print vars), so
`(set! *warn-on-reflection* true)` works at top level while
`(set! user-dynamic-var v)` at top level throws. `(count (get-thread-bindings))`
is 21 at the JVM top level vs **0 in cljw**.

cljw diverged three ways (D-254):

1. **analyze-time fragility (genuinely broken).** `analyzeSetBang`
   (`special_forms.zig`) checked `flags.dynamic` at *analyze* time, but the
   flag is only set at *eval* time (`tree_walk.zig` / `vm.zig` def arms). A
   same-compilation-unit def+set! therefore falsely errored:
   `(do (def ^:dynamic z 0) (binding [z 1] (set! z 9)))` → cljw "Can't set!
   non-dynamic var: z" but JVM = 9.
2. **silent root-write.** `evalSet` / `op_set_var` did
   `if (!setBinding) setRoot(val)` — a top-level set! on an *unbound* dynamic
   var silently mutated the root (JVM throws). This same root-write is also
   the *only* reason `(set! *warn-on-reflection* true)` "worked" at top level
   despite cljw having no baseline frame.
3. **message text** (cljw-native phrasing; lower concern, retained).

## Decision

Adopt the JVM model in two coupled parts (Alt B of the Devil's-advocate
fork):

**Part 1 — `set!` is a runtime thread-bound gate.** Remove the analyze-time
dynamic check entirely (the analyzer only resolves the target Var). Both
backends (`evalSet`, `op_set_var`) become:

```
if (!setBinding(var, val)) return raise(.var_set_not_bound, …);  // never setRoot
```

`setBinding` walks the whole frame chain, so a bound var (at any depth) is
updated; an unbound var — dynamic-and-unbound OR non-dynamic — uniformly
raises, mirroring JVM's single predicate. The now-unused
`set_target_not_dynamic` catalog Code is removed; the pre-existing
`var_set_not_bound` ("Can't set! var that is not thread-bound: X") is the
single message, consistent with `var-set`.

**Part 2 — a clojure.main-style baseline binding frame.** At bootstrap
completion (`setupCore` / `setupCoreAot`, after the `.clj` load), push one
process-lifetime `BindingFrame` (`user_pushed = false`, so
`pop-thread-bindings` cannot pop it and a stray pop correctly raises
unmatched) binding the cljw-existing members of clojure.main's baseline set,
each to its current root: `*warn-on-reflection*`, `*unchecked-math*`,
`*print-meta*`, `*print-length*`, `*print-level*`, `*print-namespace-maps*`,
`*data-readers*`, `*default-data-reader-fn*`. The binding is transparent
(deref returns the same root value) but makes `(set! *warn-on-reflection*
true)` at top level succeed for the *correct* reason (the var is genuinely
thread-bound), exactly as in JVM. The frame lives in the bootstrap arena
(freed wholesale at teardown — no per-entry free, no leak).

`*ns*` (its own materialized-view machinery, ADR-0085) and `*out*`/`*in*`/
`*err*` (D-238, not yet first-class) are deliberately excluded. Standard
vars that do not yet exist in cljw (`*assert*`, `*math-context*`,
`*command-line-args*`, …) are **not fabricated** — creating a var whose
behaviour is unimplemented would write a parity cheque the runtime cannot
cash (the DA-flagged risk). They land with their features; D-241 stays open
for them.

## Alternatives considered

(Devil's-advocate subagent, fresh context, F-002/F-009/F-011 envelope —
reflected verbatim in spirit.)

- **Alt A — smallest-diff: drop the analyze check, runtime throws on
  unbound.** One runtime arm covers {non-dynamic} ∪ {dynamic-unbound} by
  reusing the existing thread-bound catalog entry. *Better*: least new
  machinery, message already matches JVM. *Breaks*: without a baseline
  frame it regresses `(set! *warn-on-reflection* true)` from success→throw
  — itself an F-011 violation in the other direction. So Alt A is only
  F-011-clean once it bundles at least a minimal frame, at which point it
  has converged on Alt B.
- **Alt B — finished-form-clean: full runtime gate + baseline frame.** The
  chosen shape. *Better*: the only option with zero residual divergence and
  zero AD on the set! axis; `set!` becomes derivable from the same
  thread-bound predicate JVM uses, and `get-thread-bindings`/`with-bindings`
  become correct downstream. DA recommended it, citing F-002 (pull D-241
  forward rather than ship the smaller-diff Alt A/C — the set!-parity work is
  exactly what makes the baseline frame load-bearing; "LOW value now" on
  D-241 was a diff-budget judgement, not an F-NNN block). *Cost*: larger
  diff; the DA flagged that fabricating the ~15 missing standard vars would
  introduce behavioural divergences for vars whose semantics aren't wired —
  mitigated here by binding only the existing subset and NOT fabricating.
- **Alt C — wildcard: keep a dynamic check but move it to eval-time + AD the
  root-write.** *Better*: smallest correct fix for divergence #1 alone;
  keeps the friendlier "non-dynamic" message. *Breaks*: the AD it needs
  ("top-level set! succeeds where JVM throws") cannot be written honestly —
  there is no F-NNN invariant that justifies set!-succeeds-where-JVM-throws,
  and the accepted_divergences discipline forbids convenience-only ADs. It
  also keeps two code paths where JVM has one (dual-backend drift hazard,
  F-009). Collapses into Alt B once the bad AD is refused.

DA recommendation: Alt B (non-binding). Main loop concurs — per F-002 the
finished form wins and the cycle-budget instinct toward Alt A/C is the
Cycle-budget-defer smell.

## Affected files

- `src/eval/analyzer/special_forms.zig` — drop the analyze-time dynamic check.
- `src/eval/backend/tree_walk.zig` (`evalSet`) — raise on unbound.
- `src/eval/backend/vm.zig` (`op_set_var`) — raise on unbound.
- `src/runtime/error/catalog.zig` — remove the unused `set_target_not_dynamic`
  Code + entry.
- `src/lang/bootstrap.zig` — `installBaselineBindings` at `setupCore` /
  `setupCoreAot` completion.
- `src/eval/node.zig` — `SetNode` docstring (no longer "sets root when
  unbound").
- `test/e2e/phase15_set_bang.sh` — `root-set`/`not-dyn` cases move to the
  JVM-parity behaviour; the same-unit def+set! regression case added.
- `src/lang/diff_test.zig` — a dual-backend case for `binding`+`set!`.

## Consequences

- `(set! v val)` on an unbound var (dynamic or not) raises uniformly —
  trust-positive (a user bug is no longer silently absorbed by a root
  mutation).
- The same-compilation-unit def+set! false error is gone (the analyze-time
  race is removed).
- `(set! *warn-on-reflection* true)` and the other 7 baseline vars work at
  top level for the correct reason; `(get-thread-bindings)` at top level now
  returns the 8-var baseline (vs the empty map before) — a step toward D-241
  parity (full 21-var parity waits on the missing vars landing).
- Residual: a top-level `(set! *some-missing-standard-var* v)` still differs
  from JVM only because the var does not exist yet — a var-coverage gap
  (D-241), not a set! semantics gap.
