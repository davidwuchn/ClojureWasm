;; cljw.wasm — require a Wasm component as a namespace (W1, D-404 / ADR-0135).
;; A component's exports become callable Vars in a target ns, indistinguishable
;; from normal Clojure fns. A THIN Clojure layer over the wasm/ primitives
;; (load-component / component-exports / component-call live in
;; runtime/cljw/wasm/, F-009 — this never forks them). Require-on-demand AND
;; wasm-gated: only resolvable in a `-Dwasm` build (the wasm/ ns it rides does
;; not exist otherwise).
(ns cljw.wasm)

(defn- strip-export-name
  "Clean a raw WIT export name to a Clojure symbol-name string:
   `pkg:iface/greet` -> `greet`; `…#[constructor]counter` -> `counter`;
   `…#[method]counter.get` -> `get`; a bare `greet` -> `greet`."
  [raw]
  (let [after-bracket (if-let [i (clojure.string/last-index-of raw "]")]
                        (subs raw (inc i))
                        raw)
        after-slash (if-let [i (clojure.string/last-index-of after-bracket "/")]
                      (subs after-bracket (inc i))
                      after-bracket)
        after-dot (if-let [i (clojure.string/last-index-of after-slash ".")]
                    (subs after-slash (inc i))
                    after-slash)]
    after-dot))

(defn require-component*
  "Runtime worker for `require-component`: load `path` as a cached component
   handle, then intern one Var per export into the `ns-sym` namespace, each a fn
   that calls the export through the shared handle. Returns the target Namespace."
  [path ns-sym]
  (let [handle (wasm/load-component path)
        exports (wasm/component-exports path)
        target (create-ns ns-sym)]
    (doseq [e exports]
      (let [raw (:name e)
            clean (strip-export-name raw)]
        (intern target (symbol clean)
                (fn [& args] (apply wasm/component-call handle raw args)))))
    target))

(defmacro require-component
  "Require a Wasm component's exports as Vars in a namespace, e.g.
   `(require-component \"greet.wasm\" :as greeter)` then `(greeter/greet \"world\")`.
   The `:as` name is an unquoted symbol (like `require`'s `:as`)."
  [path & opts]
  (let [o (apply hash-map opts)]
    `(require-component* ~path '~(:as o))))
