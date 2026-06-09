;; SPDX-License-Identifier: EPL-2.0
;; Copyright (c) the ClojureWasm authors. Licensed under EPL-2.0.
;; Independently reimplements the clojure.data.json API (originally Clojure contrib (data.json); Clojure, EPL-1.0)
;; for ClojureWasm; no upstream source text is reproduced.

;; clojure.data.json — JSON read/write. cw v1 §9.11 row 9.3 landing.
;;
;; Surface mirrors JVM clojure.data.json 2.5.x: `read-str` parses a
;; JSON string into a cw value (vector / array_map / string / number
;; / nil / bool); `write-str` serialises a cw value into a JSON
;; string. The Layer-2 primitives are interned by
;; `src/lang/primitive/json.zig::register`; this file's only job is
;; to open the namespace so user `(require '[clojure.data.json :as
;; json])` finds it.
(ns clojure.data.json
  (:refer-clojure))
