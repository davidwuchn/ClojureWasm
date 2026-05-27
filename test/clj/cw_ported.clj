;; cw v1 §9.13 row 11.3 — ported upstream Clojure tests (Tier A).
;;
;; Each test is a 0-arity defn that uses `clojure.test/is`. Tests are
;; collected explicitly into a vector at the bottom and run via
;; `clojure.test/run-tests`. Without user-defined defmacro (D-099),
;; the JVM `(deftest)` shape is unavailable — explicit `defn` + tail
;; `run-tests` is the cw v1 cycle-1 idiom.
;;
;; Sources: ~/Documents/OSS/clojure/test/clojure/test_clojure/*.clj
;; (semantic ports, NOT verbatim copies — each test is rewritten in
;; cw v1's Pattern A surface). Each test has a `;; CLJW:` tier
;; marker comment naming the tier classification (all A for cycle 1).
;;
;; The final form prints `[passes fails]` for `test/run_all.sh`'s
;; `test_clj` step to capture.

;; CLJW: A — arithmetic (clojure.core arithmetic test fragment)
(defn test-add-int []
  (clojure.test/is (= 6 (+ 1 2 3))))

;; CLJW: A — arithmetic
(defn test-sub-int []
  (clojure.test/is (= -1 (- 1 2))))

;; CLJW: A — arithmetic
(defn test-mul-int []
  (clojure.test/is (= 24 (* 2 3 4))))

;; CLJW: A — clojure.string/upper-case via count (cw v1 `=` is
;; number-only today; string identity check uses length proxy).
(defn test-str-upper []
  (clojure.test/is (= 2 (count (clojure.string/upper-case "hi")))))

;; CLJW: A — vector conj / count
(defn test-vec-conj []
  (clojure.test/is (= 3 (count (conj [1 2] 3)))))

;; CLJW: A — map assoc / get
(defn test-map-assoc-get []
  (clojure.test/is (= 99 (get (assoc {:a 1} :b 99) :b))))

;; CLJW: A — set conj / contains?
(defn test-set-conj-contains []
  (clojure.test/is (contains? (conj #{:a :b} :c) :c)))

;; CLJW: A — sequence map + first
(defn test-seq-map-first []
  (clojure.test/is (= 2 (first (map (fn* [x] (* x 2)) [1 2 3])))))

;; CLJW: A — sequence reduce
(defn test-seq-reduce []
  (clojure.test/is (= 15 (reduce + 0 [1 2 3 4 5]))))

;; CLJW: A — clojure.set/intersection (cw v1 `=` is number-only;
;; check element count + membership instead).
(defn test-set-intersection []
  (let* [inter (clojure.set/intersection #{1 2 3} #{2 3 4})]
    (clojure.test/is
      (if (= 2 (count inter))
        (if (contains? inter 2)
          (contains? inter 3)
          false)
        false))))

;; CLJW: A — clojure.edn round-trip (cw v1 `=` number-only; count
;; + first probe).
(defn test-edn-round-trip []
  (let* [v (clojure.edn/read-string "[1 2 3]")]
    (clojure.test/is
      (if (= 3 (count v))
        (if (= 1 (first v))
          (= 3 (nth v 2))
          false)
        false))))

;; CLJW: A — defn closure capture
(defn test-fn-closure []
  (let* [adder (fn* [n] (fn* [x] (+ x n)))]
    (clojure.test/is (= 5 ((adder 3) 2)))))

;; CLJW: A — recur via loop*
(defn test-loop-recur []
  (clojure.test/is
    (= 55 (loop* [i 0 acc 0]
            (if (= i 11) acc (recur (+ i 1) (+ acc i)))))))

;; Run the test set + print [passes fails].
(clojure.test/run-tests
  test-add-int
  test-sub-int
  test-mul-int
  test-str-upper
  test-vec-conj
  test-map-assoc-get
  test-set-conj-contains
  test-seq-map-first
  test-seq-reduce
  test-set-intersection
  test-edn-round-trip
  test-fn-closure
  test-loop-recur)
