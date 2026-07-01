(ns verify
  (:require [clojure.core.unify :as u]))
(defn -main [& _]
  ;; unify two terms with logic variables (symbols starting with ?)
  (let [s (u/unify '(?x 2 ?y) '(1 2 3))]
    (assert (= '{?x 1 ?y 3} s)))
  ;; no-match returns nil
  (assert (nil? (u/unify '(?x ?x) '(1 2))))
  ;; subst applies a binding map
  (assert (= '(1 2 3) (u/subst '(?a 2 ?b) '{?a 1 ?b 3})))
  (println "OK core.unify — unify/subst with logic variables"))
