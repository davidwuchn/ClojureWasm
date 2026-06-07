;; medley — pure-Clojure utility belt. Verified loadable on cljw via deps.edn
;; git coordinates (medley's own deps.edn declares org.clojure/clojure :mvn,
;; skipped per ADR-0101 amendment 1). Run by scripts/verify_projects.sh.
(require '[medley.core :as m])
(assert (= 5 (m/find-first odd? [2 4 5 6])))
(assert (= {1 {:id 1} 2 {:id 2}} (m/index-by :id [{:id 1} {:id 2}])))
(assert (= {:a {:c 2}} (m/dissoc-in {:a {:b 1 :c 2}} [:a :b])))
(assert (= {:a 1 :b 2} (m/map-vals inc {:a 0 :b 1})))
(println "OK medley — find-first/index-by/dissoc-in/map-vals")
