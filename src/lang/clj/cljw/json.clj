;; cljw.json — handy JSON, require-able under the cljw.* namespace (ADR-0126
;; Cycle 7, user-requested). A THIN wrapper over clojure.data.json (the neutral
;; parse/emit impl lives in lang/primitive/json.zig per F-009 — this never
;; forks it) plus map<->JSON convenience. Eager-loaded after clojure.data.json +
;; clojure.walk.
(ns cljw.json)

;; Re-exports (so `(require '[cljw.json :as json])` gives the data.json surface).
(def write-str clojure.data.json/write-str)
(def read-str clojure.data.json/read-str)

(defn encode
  "A cljw value -> a JSON string. (Alias of write-str, the natural map->JSON
   direction.)"
  [x]
  (clojure.data.json/write-str x))

(defn decode
  "A JSON string -> a cljw value with map keys keywordized recursively (the
   common `cheshire/parse-string s true` shape). Use decode-strict for string
   keys."
  [s]
  (clojure.walk/keywordize-keys (clojure.data.json/read-str s)))

(defn decode-strict
  "A JSON string -> a cljw value with string map keys (data.json default)."
  [s]
  (clojure.data.json/read-str s))
