;; JSON parse hot path — the D-407(a) "fast Zig primitive" standing proof:
;; cljw's clojure.data.json/read-str is a Zig (std.json) primitive, JVM
;; Clojure's is pure-Clojure library code. Same file runs on cw / clj / bb.
(require '[clojure.data.json :as json])

(def doc
  (json/write-str
    {:users (vec (map (fn [i] {:id i
                               :name (str "user" i)
                               :tags ["alpha" "beta" "gamma"]
                               :scores [1.5 2.5 3.5 4.5]
                               :active (even? i)})
                      (range 200)))}))

(println
  (loop [i 0 acc 0]
    (if (= i 100)
      acc
      (recur (inc i) (+ acc (count (get (json/read-str doc) "users")))))))
