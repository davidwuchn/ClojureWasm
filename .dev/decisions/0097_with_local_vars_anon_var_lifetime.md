# ADR-0097 — `with-local-vars`: anonymous local Vars are gpa-owned, never freed (escape-safe), reclamation deferred

- **Status**: Proposed → Accepted (2026-06-06)
- **Driven by**: D-237 (`with-local-vars` needs anonymous-Var creation + a heap
  binding-frame primitive). var-get/var-set + push/pop-thread-bindings already
  landed; the missing pieces are the anonymous Var + the macro.
- **Relates to**: F-006 (Vars gpa-owned, GC-membrane-filtered), F-011
  (behavioural equivalence), AD-015 (escaped-local-var print/deref divergence).

## Context

JVM `with-local-vars` (core.clj) lowers to: create N anonymous dynamic Vars
(`Var.create()` — no ns/name, root = Unbound), `pushThreadBindings` a map binding
them to inits, run the body in `try`, `finally` `popThreadBindings`. `var-get`/
`var-set`/`@` operate on them inside the body.

cljw facts that shape the design (verified):
- A cljw `Var` is `gpa.create`'d and a `.var_ref` Value is **filtered out of the
  GC membrane** — the GC never reclaims a Var; it is freed only by explicit
  `gpa.destroy`.
- The value a local var is bound to is **already GC-rooted** by the existing
  `thread_roots` walker (it drains `frame.bindings.valueIterator()` down the
  parent chain). So there is **no GC-reachability problem** — the only open
  question is the **heap lifetime of the gpa-owned Var struct**.
- `Var.ns` is a non-optional `*Namespace` (print/error read `v.ns.name`), so an
  anonymous var needs a sentinel `__local` Namespace kept OUT of
  `env.namespaces`.
- cljw has **no Unbound sentinel** (var-get on an unbound dynamic var returns its
  root). JVM's `(var-get <escaped-local-var>)` returns an **unreproducible
  opaque** `#object[clojure.lang.Var$Unbound 0x…]` — so cljw cannot be F-011-clean
  on the escaped-var path no matter what it returns.

The lifetime question (where/when the anon Var is freed, and what the escaped-var
case does) was taken to a Devil's-advocate fork.

## Decision

**Alt C — anonymous local Vars are gpa-owned and NOT freed (tombstone); the
common path leaks the small Var struct; struct reclamation is deferred (D-255).**

- New primitive **`-create-local-var`** (0-arity): `gpa.create(Var)` with `.ns` =
  a process-global sentinel `__local` Namespace (lazily created, NOT registered in
  `env.namespaces`), `flags.dynamic = true`, root nil, name `--unnamed--`. Returns
  a `.var_ref`. **The struct is intentionally never `gpa.destroy`'d** — see below.
- **`with-local-vars`** is a `core.clj` `defmacro` (mirrors the with-redefs /
  with-bindings / with-open family) lowering to:
  `(let [x (-create-local-var) …] (push-thread-bindings (hash-map x init-x …))
   (try body… (finally (pop-thread-bindings))))`.
- `var-get`/`var-set`/`@` inside the body hit the active thread binding (works).
  After the extent (`pop-thread-bindings`), the binding is gone; an **escaped**
  var_ref deref returns the var's root (nil) — **safe, no UAF** (AD-015).

**Why not free at pop (Alt B).** Freeing the Var at `pop-thread-bindings` gives a
leak-free common path, but an escaped var_ref then dereferences freed memory =
**use-after-free** (a crash-class memory-safety bug). For a runtime, shipping a
latent UAF — even on a rare anti-pattern path — is unacceptable; and since JVM's
escaped-var result is an unreproducible opaque, Alt B's "F-011-clean escape" is
illusory (cljw diverges on escape either way). Alt C trades a small, bounded
common-path leak for guaranteed memory safety.

**Reclamation (D-255).** The common-path struct leak is the cost of escape-safety
without reference tracking. The finished-form reclamation is a generation-handle
slotmap (free the struct, detect stale escaped refs → Unbound) — deferred as a
proportionate optimization for a rarely-used feature, tracked in D-255 with a
`// D-255` marker at the `-create-local-var` site. Not shipped now (a slotmap for
a marginal feature is over-engineering until a workload makes the leak material).

## Alternatives considered

(Devil's-advocate subagent, fresh context, F-002/F-006/F-011 envelope.)

- **Alt A — macro `finally` frees via a `-free-local-var` primitive.** Tiny;
  common case leak-free. BUT an escaped var_ref → UAF, and that UAF "derives from
  no invariant" (freeing eagerly for simplicity) so it cannot be a clean AD — it
  ships a latent memory-safety bug. **Rejected** (DA: "not recommendable").
- **Alt B — `pop-thread-bindings` frees the `__local`-sentinel vars it pops.**
  Finished-form ownership (the frame owns its locals), leak-free common path. Still
  escaped-var UAF → needs an F-006-derived AD. DA: "acceptable fallback." Rejected
  here in favour of memory safety (the escaped-var UAF is the same crash class as
  Alt A; the leak-free win does not justify a shippable UAF when escape can't be
  cheaply made safe).
- **Alt C — gpa-owned, never freed (tombstone); reclamation = slotmap later.**
  The chosen shape. Memory-safe (escaped deref → nil root, no UAF), F-011 as clean
  as possible given JVM's unreproducible Unbound opaque. Cost: a small bounded
  common-path leak, tracked as D-255 (slotmap upgrade) + a code marker. DA
  **recommended C** (with B+AD as the fallback). Main loop concurs: memory safety
  outranks the leak, and the leak is a tracked optimization-class debt, not a
  correctness or safety defect.

DA recommendation: Alt C (non-binding). Main loop: Alt C — per F-002 the
memory-safe finished form wins; the leak is deferred as D-255, not shipped as a
lie. (Choosing C over B is NOT a cycle-budget downgrade — it is a
memory-safety-over-leak judgement; the slotmap that would make B-without-UAF /
leak-free-C is the heavier C'' deferred to D-255.)

## Affected files

- `src/runtime/runtime.zig` — cache the sentinel `__local` Namespace pointer.
- `src/lang/primitive/core.zig` — `-create-local-var` primitive (lazy sentinel ns;
  Var never freed + `// D-255` marker).
- `src/lang/clj/clojure/core.clj` — `with-local-vars` defmacro.
- `test/e2e/phase15_with_local_vars.sh` — JVM-parity cases.
- `.dev/accepted_divergences.yaml` — AD-015 (escaped-local-var deref/print).
- `.dev/debt.yaml` — D-237 discharged; D-255 (anon-var struct reclamation slotmap).

## Consequences

- `(with-local-vars [x 1 y 2] (var-set x 10) (+ (var-get x) (var-get y)))` => 12,
  matching clj.
- Escaping a local var past its extent is memory-safe (deref → nil) but diverges
  from JVM's unreproducible `Var$Unbound` opaque — AD-015.
- A small bounded leak of the anon Var struct per `with-local-vars` invocation;
  immaterial for the feature's real usage, reclaimed by the D-255 slotmap upgrade
  if a workload ever makes it matter.
