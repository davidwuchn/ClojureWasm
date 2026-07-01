;; Source for trap.wasm — a module whose exported `boom` traps at runtime
;; (integer divide-by-zero: 1 / 0). Used to show that an adversarial/faulty
;; WebAssembly module's trap is contained by the sandbox and surfaces as a
;; clean ClojureWasm exception, never a host crash.
;; Build: wat2wasm trap.wat -o trap.wasm
(module
  (func (export "boom") (result i32)
    i32.const 1
    i32.const 0
    i32.div_s))
