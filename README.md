<p align="center">
  <img src="assets/clojurewasm_logo.png" alt="ClojureWasm" width="320" />
</p>

<h1 align="center">ClojureWasm</h1>

<p align="center">
  <em>A from-scratch Clojure runtime in Zig — no JVM, WebAssembly at the core.</em>
</p>

> [!NOTE]
> ClojureWasm is **not yet stable** and is built by a very small team with
> limited resources. To keep that focus, **Issues and Pull Requests are not
> being accepted** right now. You are very welcome to read along, try it, and
> say hello on the [Clojurians Slack](https://clojurians.slack.com).

## What it is

ClojureWasm is a ground-up implementation of Clojure written in Zig 0.16. It
runs as a small native binary with no JVM, embeds a WebAssembly engine so
Clojure can call modules compiled from other languages, and is designed to
compile to WebAssembly itself.

## Features

- **A real numeric tower** — `Long`→`BigInt` promotion, `Ratio`, `BigDecimal`.
- **Software transactional memory** — `ref` / `dosync` / `alter` / `commute` / `ensure`.
- **Concurrency** — `agent`, `future` / `promise` / `delay`, `atom`, reference watches.
- **Lazy and chunked sequences**, transducers.
- **Protocols, records, multimethods**, `deftype` / `reify`.
- **Namespaces** and a **CIDER-compatible nREPL**, plus a growing set of
  `clojure.*` standard-library namespaces.
- **WebAssembly as an FFI** — load a sandboxed module compiled from Rust / Zig /
  C and call it like a namespace.
- **A dual backend** — every end-to-end test runs on both a tree-walking
  interpreter and a bytecode VM in lockstep; a disagreement fails the build.

## Quickstart

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

## Try it live

- **Playground** — <!-- TODO(D-362): fly.io URL --> _(coming soon)_
- **Bookshelf demo** — <!-- TODO(D-362): fly.io URL --> _(coming soon)_ — a small
  multi-user bookshelf app served end-to-end by `cljw`'s own HTTP server as a
  single binary (SQLite-over-Wasm storage, server-rendered pages, no JVM).

## The ideal

Clojure already thrives on the JVM, in the browser through ClojureScript, on the
command line through Babashka, on LLVM through jank, and on Flutter through
ClojureDart. ClojureWasm reaches for one more place: the **WebAssembly / edge**
world — Clojure as a small, self-contained binary that starts instantly, runs
anywhere a tiny runtime can, and treats WebAssembly modules from any language as
first-class, sandboxed libraries. The goal is a Clojure you can drop into a
serverless function, an edge node, or a `.wasm` sandbox and have it feel like
Clojure — interactive, expressive, and honest about its semantics. It is a young
project finding its footing, not a replacement for the runtimes above; they are
excellent at what they do.

## Documentation

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — a 5-minute orientation (zones, dual
  backend, error system, compatibility tiers).
- [`docs/clojure_vs_clojurewasm.md`](./docs/clojure_vs_clojurewasm.md) —
  intentional divergences from JVM Clojure and the not-yet-implemented surface.
- [`compat_tiers.yaml`](./compat_tiers.yaml) — the tiered JVM-compatibility
  ledger.

## License

Eclipse Public License 2.0 — see [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
EPL-2.0 follows the Clojure ecosystem convention (Clojure, Babashka, and SCI use
EPL-1.0; newer projects such as Malli use EPL-2.0).
