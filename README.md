# ClojureWasm

A from-scratch Clojure runtime written in Zig 0.16 — no JVM. It runs as a small
native binary, embeds a WebAssembly engine so Clojure can call modules compiled
from other languages, and is designed to compile to WebAssembly itself.

> Clojure already runs in a lot of places — on the JVM, in the browser through
> ClojureScript, on the command line through Babashka, on LLVM through jank, on
> Flutter through ClojureDart. ClojureWasm explores one more corner: the
> WebAssembly / edge one. It is a young project finding its footing, not a
> replacement for any of the above — those runtimes are excellent at what they do.

> **Status**: this branch (`cw-from-scratch`) is a ground-up redesign,
> feature-complete on the test gate with the v0.1.0 tag pending. The previous
> release lives on `main` (v0.5.0).

## What works today

Rebuilding the language from the bottom up means the parts you might expect a
runtime this small to skip are actually present:

- **A full numeric tower** — `Long`→`BigInt` promotion, `Ratio`, `BigDecimal`.
- **MVCC software transactional memory** — `ref` / `dosync` / `alter` / `commute` / `ensure`.
- **Concurrency** — `agent`, `future` / `promise` / `delay`, `atom`, reference watches.
- **Lazy and chunked sequences**, transducers.
- **Protocols, records, multimethods**, `deftype` / `reify`.
- **Namespaces** and a **CIDER-compatible nREPL**, plus ~10 `clojure.*` stdlib namespaces.
- **WebAssembly as an FFI** — load a sandboxed module compiled from Rust / Zig / C
  and call it like a namespace (see [Demos](#demos)).
- **A dual backend** — every end-to-end test runs on both a tree-walking
  interpreter and a bytecode VM in lockstep; a disagreement fails the build.

Compatibility is tracked against a tiered JVM-compatibility ledger
([`compat_tiers.yaml`](./compat_tiers.yaml)). Intentional divergences and the
not-yet-implemented surface are catalogued in
[`docs/clojure_vs_clojurewasm.md`](./docs/clojure_vs_clojurewasm.md).

## 30-second quickstart

Build it (needs Zig 0.16 — `direnv allow` loads it via Nix, or `nix develop`):

```sh
zig build
alias cljw=./zig-out/bin/cljw
```

Then:

```sh
# Exact rational arithmetic — a real Ratio, not a float
cljw -e '(/ 1 3)'                                  ;=> 1/3

# Arbitrary-precision integers
cljw -e '(* (bigint 1000000000000) 1000000000000)' ;=> 1000000000000000000000000N

# Software transactional memory
cljw -e '(let [a (ref 0)] (dosync (alter a + 41) (alter a inc)) @a)'  ;=> 42

# A REPL (and an nREPL via `cljw nrepl` for CIDER)
cljw
```

## Demos

- **[Polyglot WebAssembly FFI](./examples/wasm/)** — a Clojure program loads a
  WebAssembly module compiled from another language and calls it:
  `(wasm/call (wasm/load "add.wasm") "add" 2 40)` → `42`.

## Architecture

[`ARCHITECTURE.md`](./ARCHITECTURE.md) is a 5-minute orientation (zones, dual
backend, error system, tiers). [`.dev/ROADMAP.md`](./.dev/ROADMAP.md) is the
authoritative mission and phase plan.

## Building & developing

```sh
direnv allow         # one-time: load Zig 0.16.0 via Nix (or: nix develop)
zig build            # build the `cljw` binary
zig build test       # unit tests
bash test/run_all.sh # full suite (tests + zone check + e2e + bench)
zig fmt src/         # format
```

The polyglot WebAssembly FFI is behind an opt-in flag (it embeds an external
engine): `zig build -Dwasm`.

### Shared git hooks

Pre-commit gates live in [`.githooks/`](./.githooks/). Activate them once per
clone:

```sh
git config core.hooksPath .githooks
```

The Markdown table formatter (`md-table-align`) used by the gate comes from
[bbin](https://github.com/babashka/bbin):

```sh
bbin install io.github.chaploud/babashka-utilities
```

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). Questions and feedback are welcome on
the [Clojurians Slack](https://clojurians.slack.com).

## License

Eclipse Public License 2.0 — see [LICENSE](./LICENSE).

EPL-2.0 follows the Clojure ecosystem convention (Clojure / Babashka / SCI use
EPL-1.0; newer projects such as Malli use EPL-2.0, the Eclipse Foundation's
current recommendation).
