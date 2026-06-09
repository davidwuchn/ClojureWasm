;; SPDX-License-Identifier: EPL-2.0
;;
;;   Copyright (c) Rich Hickey. All rights reserved.
;;   The use and distribution terms for this software are covered by the
;;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php).
;;   By using this software in any fashion, you are agreeing to be bound by the
;;   terms of this license. You must not remove this notice, or any other, from
;;   this software.
;;
;;   template.clj — by Stuart Sierra. Reproduced in ClojureWasm; redistributed
;;   under EPL-2.0 per EPL-1.0 §7. ClojureWasm changes (c) the ClojureWasm authors.

(ns ^{:doc "Macros that expand to repeated copies of a template expression."
      :author "Stuart Sierra"}
  clojure.template
  (:require [clojure.walk :as walk]))

(defn apply-template
  "For use in macros.  argv is an argument list, as in defn.  expr is
  a quoted expression using the symbols in argv.  values is a sequence
  of values to be used for the arguments.

  apply-template will recursively replace argument symbols in expr
  with their corresponding values, returning a modified expr.

  Example: (apply-template '[x] '(+ x x) '[2])
           ;=> (+ 2 2)"
  [argv expr values]
  (assert (vector? argv))
  (assert (every? symbol? argv))
  (walk/postwalk-replace (zipmap argv values) expr))

(defmacro do-template
  "Repeatedly copies expr (in a do block) for each group of arguments
  in values.  values are automatically partitioned by the number of
  arguments in argv, an argument vector as in defn.

  Example: (macroexpand '(do-template [x y] (+ y x) 2 4 3 5))
           ;=> (do (+ 4 2) (+ 5 3))"
  [argv expr & values]
  (let [c (count argv)]
    `(do ~@(map (fn [a] (apply-template argv expr a))
                (partition c values)))))
