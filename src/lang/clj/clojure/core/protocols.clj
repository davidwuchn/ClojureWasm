;; SPDX-License-Identifier: EPL-2.0
;;
;;   Copyright (c) Rich Hickey. All rights reserved.
;;   The use and distribution terms for this software are covered by the
;;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php).
;;   By using this software in any fashion, you are agreeing to be bound by the
;;   terms of this license. You must not remove this notice, or any other, from
;;   this software.
;;
;; clojure.core.protocols — the reduce / datafy protocol surface (D-282).
;;
;; Mirrors JVM clojure.core.protocols: CollReduce (the reduce internal protocol),
;; IKVReduce (reduce-kv), Datafiable / Navigable (datafy/nav). Real collection
;; libraries that implement reducers or are `reduce-kv`-able declare these as
;; deftype supertypes (e.g. clojure.data.priority-map's
;; `clojure.core.protocols/IKVReduce`), so the ns must exist for them to load.
;;
;; Load-level today: the protocols are declared (so a deftype/reify can implement
;; them and `(satisfies? …)` works); wiring cljw's `reduce-kv` to consult IKVReduce
;; and `reduce`/`transduce` to consult CollReduce is a tracked functional follow-up.
(ns clojure.core.protocols)

(defprotocol CollReduce
  "Protocol for collection types that can implement reduce faster than
  first/next recursion. Called by clojure.core/reduce."
  (coll-reduce [coll f] [coll f val]))

(defprotocol IKVReduce
  "Protocol for concrete associative types that can reduce themselves via a
  function of key and val faster than first/next recursion over map entries.
  Called by clojure.core/reduce-kv."
  (kv-reduce [amap f init]))

(defprotocol Datafiable
  (datafy [o] "Return a representation of o as data (default identity)."))

(defprotocol Navigable
  (nav [coll k v] "Return the value navigated to from coll via k and v."))

;; Docstrings reproduced from clojure.core.protocols; ClojureWasm changes (c) the ClojureWasm authors. EPL-2.0.
