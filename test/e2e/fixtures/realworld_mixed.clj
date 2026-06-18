;; A realistic multi-feature program exercised by phase14_realworld_program.sh.
;; Every line of output is byte-identical to JVM Clojure (verified 2026-06-18) —
;; a whole-program integration regression guard for the clj-parity campaign.
(defn fib-seq []
  ((fn rfib [a b] (lazy-seq (cons a (rfib b (+ a b))))) 0 1))
(println "fib:" (take 10 (fib-seq)))
(defn fact [n] (loop [n n acc 1] (if (zero? n) acc (recur (dec n) (* acc n)))))
(println "fact:" (fact 20))
(defn safe-div [a b] (try (/ a b) (catch ArithmeticException _ :div0)))
(println "div:" (safe-div 10 2) (safe-div 1 0))
(defn classify [n] (case (mod n 3) 0 :zero 1 :one 2 :two))
(println "case:" (map classify (range 6)))
(println "when-let:" (when-let [x (first (filter even? [1 3 5 8]))] (* x 10)))
(def sm (into (sorted-map) (map (fn [i] [i (* i i)]) (range 5))))
(println "sorted:" sm "=hash:" (= sm (into {} sm)) "first:" (first sm))
(def v (persistent! (reduce conj! (transient []) (range 5))))
(println "transient:" v)
(println "threading:" (-> 5 (* 2) (+ 1) (->> (repeat 3) (reduce +))))
(let [m {:a {:b {:c 42}}}] (println "get-in:" (get-in m [:a :b :c]) (assoc-in m [:a :b :c] 99)))
(println "for:" (for [x (range 3) y (range 3) :when (< x y)] [x y]))
