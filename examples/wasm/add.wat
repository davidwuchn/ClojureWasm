;; Source for add.wasm — a minimal WebAssembly module exporting `add`.
;; Build: wat2wasm add.wat -o add.wasm   (or any wabt/wasm toolchain)
;;
;; add.wasm is committed prebuilt so the demo runs without a wasm toolchain;
;; this .wat is the human-readable source for reproducibility.
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
