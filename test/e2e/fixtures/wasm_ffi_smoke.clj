;; Polyglot Wasm FFI smoke (ADR-0099 / D-259 (b) leak guard fixture).
;; Loads a Zig->Wasm module and calls its `add` export; the e2e asserts the
;; result is 42 AND that the process exits with no DebugAllocator leak (the
;; .wasm_module GC finaliser must tear down the zwasm triple).
(def m (wasm/load "docs/examples/wasm/add.wasm"))
(println "add(2,40) =" (wasm/call m "add" 2 40))
