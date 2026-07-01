# WebAssembly as an FFI — polyglot demo

ClojureWasm can embed a WebAssembly engine ([zwasm](https://github.com/clojurewasm)
v2) and call modules compiled from **other languages** as if they were Clojure
namespaces. This is the "WebAssembly as an FFI" idea: a Clojure REPL loads a
sandboxed `.wasm` and invokes its exports.

```clojure
(def m (wasm/load "docs/examples/wasm/add.wasm"))
(wasm/call m "add" 2 40)   ;=> 42
```

`wasm/load` reads + instantiates a module; `wasm/call` invokes an export by
name, marshalling arguments and results from the export's signature
(`i32`/`i64`/`f32`/`f64` today).

## Run it

The wasm FFI is behind a build flag (`-Dwasm`), so the **default** `cljw` binary
does not embed zwasm — the polyglot build is opt-in:

```sh
zig build -Dwasm
./zig-out/bin/cljw docs/examples/wasm/add.clj
# 42
```

## The module

`add.wasm` is a 41-byte module exporting `(add i32 i32) -> i32`. It is committed
prebuilt so the demo needs no wasm toolchain. The human-readable source is
[`add.wat`](./add.wat); rebuild with any wabt/wasm toolchain:

```sh
wat2wasm add.wat -o add.wasm
```

Any language that compiles to WebAssembly works the same way — a Rust crate, a
Zig module, a C function — once built to a `.wasm`, its exports are callable
from Clojure through `wasm/load` + `wasm/call`.

## Sandboxing

The module runs inside the wasm engine's sandbox: it has no ambient access to
the filesystem or network, and its linear memory is isolated from the
ClojureWasm heap. This demo module is pure compute (`add`); host capabilities
(for modules that need I/O) are an explicit, opt-in import — the subject of the
fuller Phase-16 FFI surface.

A faulty or adversarial module's **trap** is contained and surfaces as an
ordinary Clojure exception — the host never crashes. [`trap.wat`](./trap.wat)
divides by zero:

```clojure
(try
  (wasm/call (wasm/load "docs/examples/wasm/trap.wasm") "boom")
  (catch Throwable e (println "caught trap:" (.getMessage e))))
;; caught trap: WebAssembly module trapped (e.g. divide-by-zero, out-of-bounds, …)
```

Run it: `zig build -Dwasm && ./zig-out/bin/cljw docs/examples/wasm/trap.clj`.
