# What works — a runnable demo walkthrough

A code-first tour of what ClojureWasm (`cljw`) does today. Everything here is
runnable on a current build (`zig build`, then `alias cljw=./zig-out/bin/cljw`).
The companion [`ladder.md`](./ladder.md) tracks real-world library loading; this
file is the "here is what works, run it yourself" ledger.

## 1. The language is really there

```clojure
cljw -e "(+ 1/3 1/6)"                       ;=> 1/2          ; real Ratio
cljw -e "(* 1234567890987654321 1000)"      ;=> 1234567890987654321000N   ; Long→BigInt
cljw -e "(take 5 (map #(* % %) (range)))"   ;=> (0 1 4 9 16)              ; lazy seq
cljw -e "(into [] (comp (filter odd?) (map inc)) (range 6))"  ;=> [2 4 6]  ; transducers
cljw -e "(let [{:keys [a b] :or {b 9}} {:a 1}] [a b])"        ;=> [1 9]    ; destructuring
```

Software transactional memory, protocols/records/multimethods, `deftype`/`reify`,
namespaces, and a CIDER-compatible nREPL (`cljw nrepl`) all work — see the README.

Correctness is mechanical: every e2e runs on **both** a tree-walking interpreter
and a bytecode VM and the build fails if they disagree, plus a differential corpus
against the real `clj`.

## 2. Polyglot — call another language's Wasm from Clojure

Build with the FFI: `zig build -Dwasm`. `add.wasm` exports `(add i32 i32) -> i32`:

```clojure
cljw -e '(wasm/call (wasm/load "examples/wasm/add.wasm") "add" 2 40)'   ;=> 42
```

A Wasm-side trap surfaces as a clean Clojure exception (catchable with `try`).
Today the calls are pure computation; host capabilities for I/O-bound modules are
being extended. (The line: cljw *calls* Wasm; compiling cljw itself *to* Wasm is
still ahead.)

## 3. An edge app — "Shelf" (the polyglot story inside a real app)

[`clojurewasm/edge-demo`](https://github.com/clojurewasm/edge-demo) — a multi-user
bookshelf served entirely by cljw's own HTTP server as a ~2.8 MB static binary on
Fly.io. Register, edit your shelf, browse others, copy a book, label, favorite —
sessions, CRUD, persistence, server-rendered HTML, no JVM.

```sh
cljw server.clj            # http://127.0.0.1:8080
bash smoke.sh              # 11-check end-to-end verification
```

On a `-Dwasm` build, each book cover's hue is computed by `cover.wasm` (compiled
from Zig) over the FFI — the polyglot story running inside a real app. Storage is
an EDN file that auto-detects a mounted `/data` volume, so the Fly.io "DB
migration" is just `fly volumes create`.

## 4. A Playground — eval Clojure on cljw in the browser

`playground.clj` (`:8081`): type Clojure, run it on cljw (not JVM Clojure), see the
printed output and result. Example snippets cover the numeric tower, ratios, lazy
seqs, STM, and the Wasm FFI. It is a local/speaker-controlled demo (in-process,
single-threaded eval — no per-eval timeout yet).

## The honest edges

- Verified on macOS arm64 + Ubuntu x86_64 only.
- Throughput/GC have headroom; the strengths are startup (~4–5 ms), size (<4 MB),
  and a small footprint.
- The static musl edge deploy currently ships without `-Dwasm` (zwasm's GC uses a
  glibc-only `pthread_getattr_np`); the polyglot covers run on a native build, with
  a pure-Clojure fallback otherwise.
- Deep Java interop (gen-class / deep proxy / deep reflection) is out of scope by
  design — this targets the Wasm/edge corner, not a JVM replacement.
