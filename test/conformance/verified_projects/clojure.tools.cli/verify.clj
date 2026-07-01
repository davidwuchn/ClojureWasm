;; clojure.tools.cli — command-line option parsing (pure Clojure, .cljc).
;; Run by `cljw -M:verify`. Exercises parse-opts: long/short opts, :parse-fn,
;; :default, boolean flags, positional arguments, the generated :summary, and
;; the :errors path for an unknown option.
(ns verify
  (:require [clojure.tools.cli :refer [parse-opts]]))

(def spec
  [["-p" "--port PORT" "Port number" :default 80 :parse-fn #(Integer/parseInt %)]
   ["-v" "--verbose"]
   ["-h" "--help"]])

(defn -main [& _]
  (let [r (parse-opts ["-p" "8080" "-v" "x"] spec)]
    (assert (= {:port 8080 :verbose true} (:options r)))   ; :parse-fn + flag
    (assert (= ["x"] (:arguments r)))                      ; positional
    (assert (string? (:summary r))))                       ; generated help text
  ;; :default applied when the option is absent.
  (assert (= {:port 80} (:options (parse-opts [] spec))))
  ;; unknown option → :errors (not an exception).
  (assert (= ["Unknown option: \"--bad\""] (:errors (parse-opts ["--bad"] spec))))
  (println "OK clojure.tools.cli — parse-opts options/arguments/default/errors/summary"))
