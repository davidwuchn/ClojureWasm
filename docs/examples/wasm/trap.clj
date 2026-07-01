;; Sandbox demo (ADR-0099 / CFP P9): calling a faulty/adversarial WebAssembly
;; module is safe. `trap.wasm`'s `boom` divides by zero, which traps inside the
;; wasm sandbox; ClojureWasm catches the trap and raises an ordinary Clojure
;; exception (try/catch works) — the host never crashes.
;;
;; Run:  zig build -Dwasm && ./zig-out/bin/cljw docs/examples/wasm/trap.clj
;; Expected output: a line starting "caught trap: ..."

(def m (wasm/load "docs/examples/wasm/trap.wasm"))

(try
  (wasm/call m "boom")
  (catch Throwable e
    (println "caught trap:" (.getMessage e))))
