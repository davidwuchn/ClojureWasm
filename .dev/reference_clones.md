# Read-only reference clones

These paths appear in `.claude/settings.json` `additionalDirectories`.
Never edit or commit from them. Code reading only.

## Primary references (cw lineage)

- `~/Documents/MyProducts/ClojureWasm/` — **cw v0** (89K LOC, tag v0.5.0)
  - Use: feature contrast, interop boundary inspection, audit reference for known pain points
  - NOT to copy verbatim (per `.claude/rules/no_copy_from_v1.md`)
- `~/Documents/MyProducts/ClojureWasmFromScratch_v1_ref/` — **Phase 1+2 reference**
  - Use: previous re-design attempt; diff against current cw v1

## Upstream sources (semantics ground truth)

- `~/Documents/OSS/clojure/` — **JVM Clojure source**
  - Use: canonical semantics for each var; ground truth for Tier A behavior
  - Focus paths: `src/jvm/clojure/lang/*.java` (Compiler, RT, Var, IFn, Numbers, PersistentVector, PersistentHashMap, LazySeq, MultiFn, Atom, LockingTransaction, Ref, Reflector), `src/clj/clojure/core.clj`
- `~/Documents/OSS/babashka/` — **Babashka (SCI-based subset Clojure)**
  - Use: precedent for JVM-independent Clojure execution; understand what was deliberately omitted
- `~/Documents/OSS/spec.alpha/` — **clojure.spec.alpha**
  - Use: Phase 6 spec implementation reference
- `~/Documents/OSS/openjdk24/` — **OpenJDK 24 source**
  - Use: JVM internals reference for memory model, GC, lock, concurrent primitives. Read when designing cw equivalents.

## Reference WASM stacks

- `~/Documents/OSS/wasmtime/` — **wasmtime (Rust)**
  - Use: WebAssembly runtime reference (Phase 16+ Pod boundary design)

## Pattern libraries (optional learning)

- `~/Documents/OSS/zig/` — **Zig stdlib source**
  - Use: Zig 0.16 idiom confirmation, std.Io abstraction design, std.atomic / std.Thread API verification
- `~/Documents/OSS/malli/` — **Malli (Clojure schema library)**
  - Use: schema validation pattern reference (Phase 11+ comparison)
- `~/Documents/OSS/mattpocock_skills/` — TypeScript / typing learning material
  - Use: type system design reference (secondary)

## Reading discipline

At each Phase Step 0 (textbook_survey):
1. Read JVM Clojure source for canonical behavior
2. Read cw v0 for "how v0 handled this"
3. Read Babashka for "what subset works without JVM"
4. Cite explicit references in per-task notes and ADRs

NEVER copy code verbatim from these references (per `no_copy_from_v1.md`).
Re-derive semantics from understanding.
