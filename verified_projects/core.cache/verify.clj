;; clojure.core.cache — the canonical caching protocol library (CacheProtocol
;; over deftype, depends on data.priority-map). Verified loadable + functional
;; on cljw: the symbol-meta → collection-base-iface → :pre/:post chain unblocks
;; it (see docs/works/ladder.md). Exercises basic + LRU cache semantics.
(require '[clojure.core.cache :as cache])

;; basic-cache: a straight map-backed store.
(let [c (cache/basic-cache-factory {:a 1})]
  (assert (cache/has? c :a))
  (assert (= 1 (cache/lookup c :a)))
  (assert (not (cache/has? c :b)))
  (let [c2 (cache/miss c :b 2)]
    (assert (= 2 (cache/lookup c2 :b)))
    (let [c3 (cache/evict c2 :a)]
      (assert (not (cache/has? c3 :a))))))

;; LRU cache: oldest entry is evicted past the threshold.
(let [c (-> (cache/lru-cache-factory {} :threshold 2)
            (cache/miss :a 1)
            (cache/miss :b 2)
            (cache/miss :c 3))]
  (assert (cache/has? c :c))
  (assert (cache/has? c :b))
  (assert (not (cache/has? c :a))))  ; :a evicted as least-recently-used

(println "OK core.cache — basic + LRU has?/lookup/miss/evict")
