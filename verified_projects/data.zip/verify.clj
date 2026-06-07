;; clojure.data.zip — XML-zipper navigation helpers over clojure.zip. Exercises
;; `descendants`, which attaches metadata to a zipper typed_instance (the D-312
;; with-meta-on-record path). Run by `cljw -M:verify` (-> verify/-main).
(ns verify
  (:require [clojure.zip :as zip]
            [clojure.data.zip :as dz]))
(defn -main [& _]
  (let [loc (zip/vector-zip [1 [2 3] 4])
        nodes (map zip/node (dz/descendants loc))]
    ;; descendants = the loc itself + every node below it, depth-first.
    (assert (= 6 (count nodes)))
    (assert (= '([1 [2 3] 4] 1 [2 3] 2 3 4) nodes)))
  (println "OK data.zip — descendants depth-first over a vector-zip"))
