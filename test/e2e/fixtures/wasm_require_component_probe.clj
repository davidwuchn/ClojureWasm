;; W1 require-a-component probe (D-404 / ADR-0135). A component's exports become
;; callable Vars in a namespace via cljw.wasm/require-component, indistinguishable
;; from normal Clojure fns. Run under `-Dwasm` (the wasm/ ns + the greet fixture).
(require 'cljw.wasm)

;; --- :as form — exports interned as Vars in the `greeter` ns ---
(cljw.wasm/require-component "test/e2e/fixtures/wasm/greet_component.wasm" :as greeter)
(let [r (greeter/greet "world")]
  (assert (= "Hello, world!" r) (pr-str r))
  (println "PASS require-component-greet"))

;; --- the interned Var is a real fn: callable again, reusing the cached handle ---
(let [r (greeter/greet "again")]
  (assert (= "Hello, again!" r) (pr-str r))
  (println "PASS require-component-reuse"))

;; --- resource component: ctor + methods become Vars with cleaned names
;;     ([constructor]counter -> counter, [method]counter.get -> get, …) ---
(cljw.wasm/require-component "test/e2e/fixtures/wasm/resource_counter.wasm" :as ctr)
(let [h (ctr/counter 5)
      _ (ctr/increment h)
      g (ctr/get h)]
  (assert (= 6 g) (str "counter ctor(5)->increment->get expected 6, got " (pr-str g)))
  (println "PASS require-component-resource"))

(println "DONE")
