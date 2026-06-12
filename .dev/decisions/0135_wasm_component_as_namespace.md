# ADR-0135 — Wasm Component Model as a first-class Clojure namespace (`require` a component, call its exports with Clojure data)

- **Status**: Proposed → Accepted (2026-06-13, user-directed)
- **Driven by**: the project's north-star differentiator (ROADMAP §1.2 axis 2;
  ADR-0099 / the Clojure-conj CFP "WebAssembly as an FFI — calling a `.wasm`
  *like a namespace*, the one thing no other Clojure runtime demonstrates").
  This ADR fixes the **finished form** that ADR-0099's minimal
  `(wasm/load)`+`(wasm/call handle "export")` core-module spike points toward.
- **Relates to**: ADR-0099 (minimal core-module FFI spike — the v0.1 layer
  below this), F-001 (zwasm v2 unavoidable, lazy + `-Dwasm`-flag-guarded),
  F-009 (impl/surface split), ROADMAP §8 (Wasm/edge strategy), §6 (tier
  system). External dependency: **zwasm's Component Model + WASI-P2 campaign
  (zwasm ADR-0170, `-Dcomponent`)** — functional, embedding API **not yet
  frozen**; this ADR is designed to land **paced by that API freeze**.

## Context

The four Clojure dialects each bind one host: clj↔Java (`:import`),
cljs↔JavaScript, cljd↔Dart. Each is **host-specific**. ClojureWasm's
analogue — clojure↔**WebAssembly Component** — is structurally *better*
because the Wasm Component Model contract is **language-neutral,
spec-defined, and self-describing**:

- A WIT (`WebAssembly Interface Types`) interface describes a component's
  exports with a rich, typed value language (records, variants, lists,
  options, results, resources) that maps **almost 1:1 onto Clojure data**.
- A **component binary embeds its own interface types** (Component-Model
  binary format) — so the export list + their WIT types are recoverable by
  *decoding the `.wasm` alone*. **No `.wit` sidecar file is required.** (The
  contract is the public spec: `CanonicalABI.md` / `WIT.md` / `Binary.md`.)
- cljw is Zig-native, so the lift/lower marshalling is a **hand-written fast
  path**, not a reflection layer — and the optimisation ceiling is the metal
  (see ROADMAP §1.2 the Zig-level thesis).

Current state (2026-06-13): cw v1 ships only the minimal core-module FFI
(`wasm/load` + `wasm/call handle "export"` — string-keyed, i32/i64/f-only,
manual marshalling; ADR-0099). cw v0 had the *seed* of the higher form
(`:cljw/wasm-deps` named modules in `deps.edn` + a WIT signature parser).
zwasm is building the Component-Model runtime (WIT type system + Canonical
ABI lift/lower + component instantiate/invoke) to wasmtime-equivalent
conformance, behind `-Dcomponent`.

## Decision

**A WebAssembly *component* is loadable as a first-class Clojure namespace.**
`require`-ing it introspects the component's embedded WIT exports and interns
one Clojure Var per exported function; arguments and results are negotiated
by the Canonical ABI so the caller passes/receives **Clojure data**, never
raw `i32`s.

### Surface (two shapes; deps+require is the finished form, load is the REPL hatch)

```clojure
;; deps.edn — a component declared like any dependency (cw v0 :cljw/wasm-deps,
;; evolved from :path module to :component).
{:cljw/wasm-deps {markdown {:component "libs/markdown.wasm"}}}

;; finished form — same hand-feel as importing Java
(ns my.app (:require [markdown :as md]))
(md/render "# hi")        ;; md/render generated from the component's WIT export;
                          ;; args/return are Clojure data, docstring/arglists from WIT

;; REPL / dynamic escape hatch
(def md (cljw.wasm/load-component "markdown.wasm"))   ;; introspect → ns-like handle
;; or a def-ing macro:
(cljw.wasm/import-component "markdown.wasm" :as md)
```

The component's WIT exports are the **SSOT** for the generated surface — no
hand-written wrapper, no `.wit` sidecar.

### The contract — WIT ↔ Clojure value mapping (Canonical ABI; spec-derived, stable)

This table is the finished-form artifact. It is derivable from the public
Canonical ABI spec and changes only when the spec does.

| WIT type            | Clojure value                              | Notes                                                     |
|---------------------|--------------------------------------------|-----------------------------------------------------------|
| `bool`              | boolean                                    |                                                           |
| `s8…s64`/`u8…u64` | long                                       | `u64`/`s64` may promote to BigInt at the f64 edge (F-005) |
| `f32`/`f64`         | double                                     |                                                           |
| `char`              | char                                       | Unicode scalar                                            |
| `string`            | string                                     | UTF-8 ↔ cljw string                                      |
| `list<T>`           | vector                                     | element-wise lift/lower                                   |
| `tuple<A,B,…>`     | vector `[a b …]`                          | fixed arity                                               |
| `record{a,b,…}`    | map `{:a … :b …}`                        | field names → keyword keys (kebab preserved)             |
| `option<T>`         | `nil` \| T                                 | `none`→nil, `some(x)`→x                                 |
| `result<T,E>`       | T \| **throw** `(ex-info … {:wit/err e})` | `ok`→value, `err`→catchable cljw exception              |
| `variant`           | tagged map `{:wit/case :kw :value v}`      | (or a smaller shape if a cleaner one is chosen)           |
| `enum`              | keyword                                    |                                                           |
| `flags`             | set of keywords                            |                                                           |
| `resource`          | opaque handle, GC-finalised                | borrow/own tracked; finaliser calls `resource.drop`       |

Exports that are interfaces/worlds nest as sub-namespaces or qualified
names (TBD with zwasm's introspection shape). Imports the component *needs*
(e.g. WASI) are satisfied by cljw-provided host functions (the inverse
direction — exposing cljw fns as WIT exports — is ROADMAP §1.2 axis 2's
second half, a later ADR).

### Dependency & sequencing (paced by zwasm)

1. **Now (v0.1)**: keep ADR-0099's `wasm/load`+`wasm/call` core-module FFI.
   This ADR does *not* deprecate it — core modules without a component
   wrapper still need it.
2. **When zwasm's CM embedding API freezes** (zwasm ADR-0170): it must expose
   (a) decode a component → list exports + their WIT types; (b) invoke an
   export with Canonical-ABI lift/lower of host values. cljw then builds the
   `require`/`import-component` introspection + the mapping table above.
3. **`deps.edn` `:cljw/wasm-deps`** is the resolution layer (cw v0's seed).
4. cljw-as-component-output (exporting cljw itself / Clojure fns as WIT) and
   WasmGC are later (ROADMAP §8.3).

## Alternatives considered

- **Core-module-only, string-keyed call (status quo, ADR-0099)** — keeps
  marshalling manual (no records/strings/lists ergonomically). Correct as the
  low layer; insufficient as the finished form. *Kept as the layer below.*
- **Require a hand-written `.wit` sidecar** — rejected: the component binary
  is self-describing, so a sidecar is redundant and drifts from the binary.
  (`.wit` may still be *accepted* as an override/doc, but is not required.)
- **Static codegen (wit-bindgen-style) at build time** — heavier; loses the
  dynamic `(require …)`/REPL story that is the differentiator's heart. The
  introspect-at-require approach is more Clojure-native. (A build-time AOT
  path can be added later for size/speed without changing this contract.)
- **A `variant` as a bare 2-vector `[case value]`** — considered vs the
  tagged-map shape; deferred to the implementing cycle (pick the shape that
  round-trips cleanly through `case`/`match` ergonomics).

## Consequences

- **Differentiator becomes concrete + provable**: "ClojureWasm `require`s a
  Wasm component and calls it with Clojure data, types negotiated by the
  Canonical ABI — no other Clojure runtime does this, and the marshalling is
  Zig-native." This is the CFP heart in finished form.
- **The mapping table is a stable, spec-anchored contract** — a future AI / the
  user can implement against it without re-deriving the design.
- **Two-repo coordination is clean**: zwasm owns the CM runtime + embedding
  API; cljw owns the ns surface + the value mapping. The freeze of zwasm's CM
  embedding API is the one gating event.
- **No core-VM risk**: like ADR-0099, all of this is `-Dwasm`/`-Dcomponent`
  flag-guarded; the default gate never resolves zwasm (F-001).

## Affected files (when implemented)

- `runtime/cljw/wasm/` (surface + a new `component.zig` introspection/marshal
  layer over zwasm's CM API), `lang/require_resolver.zig` (the `:cljw/wasm-deps`
  + component-require path), `deps/parse.zig` (`:cljw/wasm-deps` schema).
- Tracked by debt rows D-404 (impl, blocked-by zwasm CM API freeze) and the
  conformance/proof rows.
