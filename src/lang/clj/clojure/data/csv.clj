;; SPDX-License-Identifier: EPL-2.0
;; Copyright (c) the ClojureWasm authors. Licensed under EPL-2.0.
;; Independently reimplements the clojure.data.csv API (originally Clojure contrib (data.csv); Clojure, EPL-1.0)
;; for ClojureWasm; no upstream source text is reproduced.

;; clojure.data.csv — CSV read/write (RFC 4180). cw v1 §9.11 row 9.4.
;;
;; The Layer-2 primitives `read-csv` + `write-csv` are interned by
;; `src/lang/primitive/csv.zig::register`. cw v1 deviates from JVM
;; on signatures: `read-csv` takes a string (not a Reader); `write-csv`
;; takes data + returns a string (not data + Writer + returns nil).
;; Reader/Writer stream APIs land alongside the streaming-IO abstractions.
(ns clojure.data.csv
  (:refer-clojure))
