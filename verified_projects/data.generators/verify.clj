;; clojure.data.generators — random data generation over a *rnd* (java.util.Random)
;; basis. Run by `cljw -M:verify`. cljw's java.util.Random implements java's exact
;; LCG (`(.nextLong (Random. 42))` == java), so a SEEDED *rnd* yields sequences
;; identical to clj — these asserts pin those exact clj-confirmed values.
(ns verify
  (:require [clojure.data.generators :as gen])
  (:import (java.util Random)))

(defn -main [& _]
  ;; Seeded → deterministic, clj-identical. Calls share one *rnd*, so the order
  ;; (uniform, vec, one-of, geometric) is part of what is pinned.
  (binding [gen/*rnd* (Random. 42)]
    (assert (= 727 (gen/uniform 0 1000)))
    (assert (= [68 30 27 66 90] (gen/vec #(gen/uniform 0 100) 5)))
    (assert (= :b (gen/one-of :a :b :c :d)))
    (assert (= 2 (gen/geometric 0.5))))
  ;; structural: reps yields exactly n items, each uniform in range.
  (binding [gen/*rnd* (Random. 7)]
    (let [xs (gen/reps 5 #(gen/uniform 0 10))]
      (assert (= 5 (count xs)))
      (assert (every? #(and (>= % 0) (< % 10)) xs))))
  ;; reproducibility: two runs under the same seed are identical.
  (let [run #(binding [gen/*rnd* (Random. 99)] [(gen/uniform 0 100) (gen/double)])]
    (assert (= (run) (run))))
  (println "OK data.generators — seeded uniform/vec/one-of/geometric == clj; reps + reproducible"))
