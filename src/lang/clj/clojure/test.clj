;; clojure.test — assertion + test-runner surface (D-227, ADR-0083-unblocked).
;;
;; Loaded by `bootstrap.zig::loadCore` after core.clj (so defmacro / syntax-quote
;; / defmulti / atom / *ns* / ns-name / clojure.walk are all available). The
;; (in-ns) header is mandatory — the loader carries no namespace knowledge.
;;
;; Design (per the D-227 Devil's-advocate fork): a PER-NAMESPACE test registry
;; keyed by the test ns symbol (so `(run-tests 'foo.test)` — the call external
;; runners make — works), `is` as a macro routing through an `assert-expr`
;; multimethod (`=` / `thrown?` / default), a `report` multimethod keyed on
;; `:type`, and `*report-counters*` as a dynamic var holding an atom.
;;
;; cljw adaptations (no JVM): `report` prints directly to stdout (no `*test-out*`
;; redirect — that needs `*out*`, deferred); no stacktrace-file-and-line in
;; do-report. Deferred: use-fixtures, thrown-with-msg?, with-test.

(ns clojure.test (:refer-clojure))

;; ---------------------------------------------------------------------------
;; State: report counters (dynamic, an atom) + the per-ns registry.
;; ---------------------------------------------------------------------------
(def ^:dynamic *report-counters* nil)
(def *initial-report-counters* {:test 0 :pass 0 :fail 0 :error 0})
(def ^:dynamic *testing-contexts* (list))

;; ns-name-symbol -> vector of test Vars (deftest appends; run-tests reads).
(def *test-registry* (atom {}))

;; ---------------------------------------------------------------------------
;; report multimethod (keyed on :type) + do-report.
;; ---------------------------------------------------------------------------
(defmulti report :type)

(defn inc-report [k]
  (when *report-counters*
    (swap! *report-counters* update k (fn [n] (inc (or n 0))))))

(defn print-contexts []
  (when (seq *testing-contexts*)
    (println "  context:" (vec (reverse *testing-contexts*)))))

(defmethod report :pass [m] (inc-report :pass))

(defmethod report :fail [m]
  (inc-report :fail)
  (println)
  (println "FAIL in" (pr-str (:expected m)))
  (print-contexts)
  (when (:message m) (println (:message m)))
  (println "expected:" (pr-str (:expected m)))
  (println "  actual:" (pr-str (:actual m))))

(defmethod report :error [m]
  (inc-report :error)
  (println)
  (println "ERROR in" (pr-str (:expected m)))
  (print-contexts)
  (when (:message m) (println (:message m)))
  (println "expected:" (pr-str (:expected m)))
  (println "  actual:" (pr-str (:actual m))))

(defmethod report :summary [m]
  (println)
  (println "Ran" (:test m) "tests containing"
           (+ (:pass m) (:fail m) (:error m)) "assertions.")
  (println (:fail m) "failures," (:error m) "errors."))

(defmethod report :default [m] nil)

(defn do-report [m] (report m))

;; ---------------------------------------------------------------------------
;; assert-expr multimethod — keyed on (first form), called at macroexpand time
;; by `is`. Returns the code that evaluates the assertion + reports.
;; ---------------------------------------------------------------------------
(defmulti assert-expr (fn [msg form] (if (seq? form) (first form) :default)))

;; Generic: evaluate the whole form; truthy => pass, else fail with the value.
(defmethod assert-expr :default [msg form]
  `(let [value# ~form]
     (if value#
       (do-report {:type :pass :message ~msg :expected (quote ~form) :actual value#})
       (do-report {:type :fail :message ~msg :expected (quote ~form) :actual value#}))
     value#))

;; (is (= expected actual …)) — on fail, actual shows the evaluated args so the
;; mismatch is visible.
(defmethod assert-expr (quote =) [msg form]
  `(let [args# (list ~@(rest form))
         result# (apply = args#)]
     (if result#
       (do-report {:type :pass :message ~msg :expected (quote ~form) :actual (cons (quote =) args#)})
       (do-report {:type :fail :message ~msg :expected (quote ~form) :actual (cons (quote not=) args#)}))
     result#))

;; (is (thrown? Class body…)) — passes iff body throws an instance of Class;
;; returns the caught exception.
(defmethod assert-expr (quote thrown?) [msg form]
  (let [klass (second form)
        body (nthnext form 2)]
    `(try ~@body
          (do-report {:type :fail :message ~msg :expected (quote ~form) :actual nil})
          (catch ~klass e#
            (do-report {:type :pass :message ~msg :expected (quote ~form) :actual e#})
            e#))))

;; ---------------------------------------------------------------------------
;; is / are / testing.
;; ---------------------------------------------------------------------------
(defmacro try-expr [msg form]
  `(try ~(assert-expr msg form)
        (catch Throwable t#
          (do-report {:type :error :message ~msg :expected (quote ~form) :actual t#})
          nil)))

(defmacro is [form & more]
  `(try-expr ~(first more) ~form))

;; (are [a b] (= a b) 1 1, 2 2) — expands to one (is …) per argv-sized group,
;; substituting the argv symbols with each group's values (no clojure.template
;; dependency; direct postwalk substitution).
(defmacro are [argv expr & args]
  (cons (quote do)
        (map (fn [vals]
               (clojure.walk/postwalk-replace (zipmap argv vals)
                                               (list (quote clojure.test/is) expr)))
             (partition (count argv) args))))

(defmacro testing [s & body]
  `(binding [*testing-contexts* (cons ~s *testing-contexts*)]
     ~@body))

;; ---------------------------------------------------------------------------
;; deftest + the registry + run-tests.
;; ---------------------------------------------------------------------------
(defmacro deftest [name & body]
  `(do
     (def ~name (fn [] ~@body))
     (swap! *test-registry* update (ns-name *ns*)
            (fn [v#] (conj (or v# []) (var ~name))))
     (var ~name)))

(defn test-var [v]
  (when v ((deref v))))

(defn run-tests [& ns-syms]
  (let [targets (if (seq ns-syms) ns-syms (list (ns-name *ns*)))]
    (binding [*report-counters* (atom *initial-report-counters*)]
      (doseq [ns-sym targets]
        (doseq [v (get (deref *test-registry*) ns-sym)]
          (swap! *report-counters* update :test inc)
          (test-var v)))
      (let [summary (assoc (deref *report-counters*) :type :summary)]
        (do-report summary)
        summary))))

(defn run-all-tests []
  (apply run-tests (keys (deref *test-registry*))))
