;; ClojureWasm polyglot FFI demo (ADR-0099 / CFP P1): a Clojure program loads a
;; WebAssembly module compiled from another language and calls it like a
;; namespace. `add.wasm` exports `(add i32 i32) -> i32`.
;;
;;   (wasm/load "path")          → an instance handle
;;   (wasm/call handle "add" …)  → invokes the export, marshalling args/results
;;
;; Run (needs the wasm-enabled build — the default cljw does not embed zwasm):
;;   zig build -Dwasm
;;   ./zig-out/bin/cljw examples/wasm/add.clj
;; Expected output: 42

(wasm/call (wasm/load "examples/wasm/add.wasm") "add" 2 40)
