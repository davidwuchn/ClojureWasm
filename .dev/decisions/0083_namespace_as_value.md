# ADR-0083 — Namespace-as-value, `*ns*`, and the ns-reflection cluster

- **Status**: Proposed → Accepted (2026-06-03)
- **Debt**: D-230 (this), unblocks D-227 (clojure.test), D-158 (real-lib load)
- **Depends on**: ADR-0027 (day-1 HeapTag reservation activation), ADR-0059
  (no-JVM), AD-002 (opaque-ref print)
- **Supersedes**: none

## Context

`clojure.test` (D-227) is the densest real-bug-finder and the enabler for
running real libraries' own test suites on cljw (D-158). Its clean finished
form (per the D-227 design probe / DA fork `a7b21f9`) is a **per-namespace
test registry keyed by the current ns symbol**, so `(run-tests 'foo.test)` —
the call every external runner makes — works. The smallest-diff alternative
(a global registry that ignores the ns argument) is the DA-flagged trap: it
passes a toy `(deftest)(is)` demo but fails the real-runner call that is the
whole point of D-158.

That per-ns form needs **current-namespace identity at the Clojure level**.
cljw lacks it entirely: the current namespace lives only as an internal
`*Namespace` struct (`env.current_ns`), never wrapped as a `Value`; and
`*ns*`, `ns-name`, `the-ns`, `find-ns`, `all-ns`, `ns-interns`,
`ns-publics`, `ns-map`, `ns-resolve` are all unresolved. This ADR adds the
**ns-reflection cluster**: a first-class Namespace value, `*ns*`, and the
read-only reflection functions.

**Out of scope (stays deferred):** the `*out*` / print-control half of the
system-var-registry. clojure.test's `report` writes through the existing
print path (Runtime.io → stdout); `*out*` is forced in only by
output-redirection (`(binding [*out* w] (run-tests))`), a nicety the per-ns
registry does not need. The cut is clean (DA-confirmed). `remove-ns` is also
deferred — it is a mutation+lifetime-distinct sub-area (a dangling `.ns`
Value pointing at a freed Env-lifetime `*Namespace` is a use-after-free that
needs a tombstone design), not drip-feed.

## Decision

Adopt **Alt 2** (DA-recommended):

1. **Representation (A).** A Namespace becomes a `Value` via
   `Value.encodeHeapPtr(.ns, ns_ptr)` wrapping the existing **Env-lifetime**
   `*Namespace` directly. The HeapTag slot `ns = 21` is **already reserved**
   (`heap_tag.zig:78` / `value.zig:67`, type-declared, unwired); this
   activates the reservation per ADR-0027 — **no new F-004 slot, no user
   amendment**. Identity is free: `findOrCreateNs` is idempotent, so same
   name → same `*Namespace` → same Value bits → `=` (pointer identity).
2. **GC membrane.** `.ns` decodes to an Env-lifetime `*Namespace` and is
   **GC-skipped**, exactly like its sibling `.var_ref` (slot 20). The GC must
   NOT trace into `mappings`/`refers` (those are Env-owned
   `StringHashMapUnmanaged`, not GC-heap — tracing them would invert
   ownership; this is why a HeapHeader'd Namespace struct, option B, is
   wrong).
3. **`*ns*` mechanism (a).** Introduce `env.setCurrentNs(ns)` that updates
   **both** `current_ns` AND the root of a Runtime-cached `*ns*` dynamic Var
   (`rt.ns_var`) to `encodeHeapPtr(.ns, ns)` (via the existing `Var.setRoot`).
   All `current_ns =` assignment sites route through it. `Var.deref` is
   **unchanged** (no signature ripple). `*ns*` is interned at bootstrap as a
   `^:dynamic` Var (the `*data-readers*` precedent) and referred into `user`,
   so `binding`/`alter-var-root` on `*ns*` work for free — mirroring clj,
   whose `*ns*` is a real dynamic Var that `in-ns`/`load` set via `.set()`.
4. **Reflection surface** in a new F-009 peer `src/lang/primitive/namespace.zig`
   (keyword `namespace`): `ns-name` (→symbol), `the-ns` (→ns-value or throw),
   `find-ns` (→ns-value or nil), `all-ns` (→seq of ns-values), `create-ns`
   (`findOrCreateNs` wrap), `ns-interns` / `ns-publics` / `ns-map`
   (→`{sym → Var-value}`, Var already a `.var_ref` Value), `ns-resolve`
   (→Var-value or nil). `in-ns` (today an analyzer form node) is also exposed
   as a runtime callable routing through `setCurrentNs`. The whole read-only
   cluster lands in one push (anti-Micro-coverage-grind). `remove-ns`
   deferred.
5. **Print + equality.** `=` is pointer-identity (heap-ptr default).
   `(str *ns*)` → `"user"`, `(name (ns-name *ns*))` → `"user"`.
   `(pr-str *ns*)` → `#object[Namespace "user"]` (no `0xADDR` — cljw cannot
   mirror a JVM identity hash). This print divergence is recorded as
   **AD-010** (`derives_from`: ADR-0059 no-JVM + AD-002 opaque-ref).

## Consequences

- clojure.test (D-227) is unblocked: its registry keys on `(ns-name *ns*)`
  at `deftest`-expansion time.
- Broadly reusable beyond clojure.test: `clojure.repl/dir`, REPL
  introspection, tooling.
- The one real surface is the `current_ns =` reroute (6 sites: tree_walk ×2,
  vm ×3, bootstrap ×1). A missed site → `*ns*` silently stale; mitigated by
  routing every assignment through `setCurrentNs` (make direct field-assign
  the exception, not the rule).
- AD-010 added to `.dev/accepted_divergences.yaml` with a pin test.
- `remove-ns` + `*out*`/`with-out-str` remain tracked debt (separate rows).

## Affected files

- `src/runtime/value/value.zig` / `heap_tag.zig` — `.ns` print/type-name/eq
  activation (encode/decode/tag already generic).
- `src/runtime/print.zig` — `.ns` → `#object[Namespace "<name>"]` (AD-010).
- GC membrane (wherever `.var_ref` is skipped) — add `.ns` sibling skip.
- `src/runtime/env.zig` — `setCurrentNs`; `Namespace`→Value helper.
- `src/runtime/runtime.zig` — `ns_var: ?*Var` cache.
- `src/lang/bootstrap.zig` — intern `*ns*` dynamic Var, refer into `user`,
  cache on `rt`; initial `setCurrentNs`.
- the 6 `current_ns =` sites (tree_walk / vm / env init).
- `src/lang/primitive/namespace.zig` (NEW) + registration in `primitive.zig`.
- `compat_tiers.yaml` — keyword `namespace` entry.
- `.dev/accepted_divergences.yaml` — AD-010 + pin.
- corpus `test/diff/clj_corpus/namespace.txt`, e2e `phase15_namespace.sh`.

## Alternatives considered

(Verbatim from the mandatory Devil's-advocate fork, fresh context, agent
`aa513cf4030cd67cf`. Recommendation Alt 2; the main loop concurs.)

> All claims verified. Critical findings: `setRoot` already exists on `Var`
> (line 108) — the `*ns*`-as-Var mutation primitive is already there.
> `findOrCreateNs` / `findNs` exist. The `*data-readers*` precedent confirms
> the dynamic-Var-cached-on-Runtime pattern works with `binding` for free.
> `current_ns =` is at 6 sites. None of the reflection fns exist; `in-ns` is
> only an analyzer form node, not a runtime callable. No F-NNN-violating
> findings — all three alternatives stay inside the reserved slot.
>
> ### Alt 1 — SMALLEST-DIFF ("symbol-handle `*ns*`, analyzer-resolved")
> (a) Representation (C): `*ns*` resolves to the symbol of the current ns
> name; reflection fns take/return symbols. Reserved `.ns` slot stays
> dormant. (b) analyzer special-cases `*ns*` → current-ns-name node. (c)
> `ns-name` identity-on-symbol; fns read `findNs(sym).mappings`. (d) `*ns*`
> prints as symbol `user`; `(= *ns* (the-ns 'user))` may not hold (symbol vs
> ns-value). Better: zero reroute risk, smallest LOC. Breaks: `(ns-name
> *ns*)` looks right but type is wrong (`instance?`/round-trip diverge);
> `(binding [*ns* …])` impossible (no Var). This is the v1 mistake the brief
> calls out — leaving a clean reservation unused to save diff = Smallest-diff
> bias smell in pure form.
>
> ### Alt 2 — FINISHED-FORM-CLEAN ("`.ns` wraps Env `*Namespace`; `*ns*` real
> dynamic Var via centralized `setCurrentNs`") ⭐
> (a) Representation (A): `encodeHeapPtr(.ns, env_namespace_ptr)` wraps the
> existing Env-lifetime `*Namespace`. Identity free (findOrCreateNs
> idempotent). GC-skip like `.var_ref`; GC does NOT trace mappings/refers
> (Env-owned). (B) is wrong — a GC-traced Namespace struct forces GC to
> own/trace the VarMaps, a lifetime inversion. (b) `env.setCurrentNs(ns)`
> updates both `current_ns` and `rt.ns_var` root; route all 6 sites through
> it; `Var.deref` unchanged. `Var.setRoot` already exists, so setCurrentNs is
> `current_ns = ns; rt.ns_var.setRoot(encodeHeapPtr(.ns, ns));`.
> `binding`/`alter-var-root` work for free — mirrors clj most faithfully. (c)
> full cluster in `namespace.zig` (keyword `namespace`); `in-ns` promoted
> from analyzer-only to runtime callable routing through setCurrentNs
> (implementer note: reroute the 6 existing sites, don't write fresh). (d)
> AD for `#object[Namespace "user"]` (no 0xADDR; derives_from ADR-0059 +
> AD-002); `(str *ns*)`→"user"; `=` pointer-identity (correct, same-name→same
> pointer). Better: every clj idiom works (`(binding [*ns* …])`, `(= *ns*
> (the-ns 'user))`, `(resolve '*ns*)`, alter-var-root); uses reserved slot as
> designed; no GC tangle; no deref ripple. Breaks/risk: the 6-site reroute is
> the only surface; a missed site = `*ns*` silently stale (mitigate:
> debug-assert `rt.ns_var.root` decodes to `current_ns` at eval-loop top).
> Per F-002 the reroute is NOT a reason to downgrade to Alt 1 (that is the
> Cycle-budget-defer smell).
>
> ### Alt 3 — WILDCARD ("`*ns*` self-rooting Var; no central mutator")
> (a) representation (A) again, but invert (b): `rt.ns_var.root` becomes the
> SSOT; `env.currentNs()` = `decodePtr(*Namespace, rt.ns_var.deref())`. No
> separate `current_ns` field. (b) `*ns*` Var is SSOT; `(binding [*ns* x] …)`
> actually changes what `current_ns` resolves to during the binding — clj's
> eval model. Better: eliminates dual-write staleness; `(binding [*ns*])` is
> load-bearing not just tolerated. Breaks/risk: large blast radius — every
> reader of `current_ns` (resolve/intern/refer/analyzer/bootstrap) becomes
> `currentNs()` paying a `Var.deref` + threadlocal walk on EVERY name
> resolution (hot path) → perf regression needing a PERF-cached fast-path
> (reintroducing dual-state); plus bootstrap-binding-leak risk. High risk for
> a feature whose driver (clojure.test) does NOT need live rebinding (it keys
> the registry at registration time).
>
> ### Scope-boundary critique
> Excluding `*out*`/print-control is the right cut — clojure.test's `report`
> writes via the existing print path; `*out*` is forced only by
> output-redirection, independently deferrable. (Caveat: a test using
> `with-out-str` needs `*out*` — separate debt row, don't expand this ADR.)
> Do the WHOLE read-only reflection cluster in one push (small, bounded,
> anti-Micro-coverage-grind): include `ns-publics`/`ns-map`/`ns-resolve` now.
> Defer `remove-ns` (mutation+lifetime: dangling `.ns`→freed Env `*Namespace`
> = use-after-free, needs tombstone) — genuinely different sub-area, not
> drip-feed.
>
> ### One-line recommendation
> Alt 2 — representation (A) + mechanism (a) (centralized setCurrentNs,
> 6-site reroute, Var.deref untouched). Most clj-faithful, activates the
> reserved slot per ADR-0027, no new F-004 slot, no GC tangle, no deref
> ripple; the 6-site reroute is finished-form cost, not a reason to fall back
> to Alt 1. Land the print-divergence AD, full read-only cluster, defer
> remove-ns.
