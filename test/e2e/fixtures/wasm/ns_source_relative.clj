;; ADR-0135 A2 — EXPLICIT-relative `./` resolves against THIS source file's dir
;; (deps.edn-free, CLI-handy), NOT cwd. greet_component.wasm sits next to this .clj.
(ns wasm.src-rel
  (:require ["./greet_component.wasm" :as g]))
(println "src-rel:" (g/greet "rel"))
