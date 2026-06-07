;; clojure.math.combinatorics — permutations/combinations over pure Clojure.
(require '[clojure.math.combinatorics :as c])
(assert (= 6 (count (c/permutations [1 2 3]))))
(assert (= '((1 2) (1 3) (2 3)) (c/combinations [1 2 3] 2)))
(assert (= 4 (count (c/subsets [1 2]))))  ; (), (1), (2), (1 2)
(println "OK math.combinatorics — permutations/combinations/subsets")
