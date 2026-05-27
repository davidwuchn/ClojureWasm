;; clojure.pprint — minimum pretty-print surface. cw v1 §9.12 row 10.2.
;;
;; Pattern A defns over clojure.core/println + clojure.string/join.
;; `pprint` aliases to `println` for cycle 1 (cw v1's default `prn`
;; output already matches JVM short-form pretty-print for the
;; map / vector / set / list literals that the existing reader
;; produces); a real width-aware indenter is a future cycle when
;; user demand surfaces (tracked via opportunistic follow-up).
;; `print-table` formats a seq of maps with shared keys as a
;; pipe-separated table; takes the keys from the first row.
;; `cl-format` and the rest of JVM clojure.pprint surface are
;; deferred — they require a non-trivial formatting DSL impl that
;; lands when needed.
(ns clojure.pprint
  (:refer-clojure))

(def pprint
  (fn* [x] (println x)))

(def print-table
  (fn* [rows]
    (if (= 0 (count rows))
      nil
      (let* [ks (keys (first rows))
             header (clojure.string/join " | " (map str ks))
             sep (clojure.string/join "-+-" (map (fn* [k] (clojure.string/join "" (map (fn* [_] "-") (str k)))) ks))
             row-strs (map (fn* [row] (clojure.string/join " | " (map (fn* [k] (str (get row k))) ks))) rows)]
        (do
          (println header)
          (println sep)
          (reduce (fn* [_ s] (println s)) nil row-strs)
          nil)))))
