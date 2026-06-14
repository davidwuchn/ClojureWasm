;; flatland.ordered — insertion-order-preserving map & set (deftype over the
;; clojure.lang map/set host-interface stack). Run by `cljw -M:verify`.
;; Order preservation is the whole point, so the asserts compare realized
;; vectors of keys/elements (insertion order), not hash order.
(ns verify
  (:require [flatland.ordered.map :refer [ordered-map]]
            [flatland.ordered.set :refer [ordered-set]]))

(defn -main [& _]
  ;; ordered-map: keys/vals follow INSERTION order (not hash order); assoc of a
  ;; new key appends; dissoc removes while preserving the rest's order.
  (let [m (ordered-map :b 2 :a 1 :c 3)]
    (assert (= [:b :a :c] (vec (keys m))))
    (assert (= [2 1 3] (vec (vals m))))
    (assert (= 3 (count m)))
    (assert (= 1 (get m :a)))
    (assert (= [:b :a :c :d] (vec (keys (assoc m :d 4)))))
    (assert (= [:a :c] (vec (keys (dissoc m :b))))))
  ;; ordered-set: insertion order + dedup.
  (let [s (ordered-set 3 1 2 1 3)]
    (assert (= [3 1 2] (vec s)))
    (assert (= 3 (count s)))
    (assert (contains? s 2))
    (assert (not (contains? s 9))))
  (println "OK flatland.ordered — ordered-map keys/vals/assoc/dissoc + ordered-set dedup"))
