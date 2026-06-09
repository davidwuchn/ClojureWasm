;; SPDX-License-Identifier: EPL-2.0
;; Copyright (c) the ClojureWasm authors. Licensed under EPL-2.0.
;; Independently reimplements the clojure.tools.cli API (originally Clojure contrib (tools.cli); Clojure, EPL-1.0)
;; for ClojureWasm; no upstream source text is reproduced.

;; clojure.tools.cli — argument parser. cw v1 §9.11 row 9.5.
;;
;; `parse-opts` is interned by `src/lang/primitive/cli.zig::register`.
;; Future cycles add `:parse-fn` / `:validate-fn` / `:default` /
;; `:missing` / `:assoc-fn` per JVM tools.cli 1.1+.
(ns clojure.tools.cli
  (:refer-clojure))
