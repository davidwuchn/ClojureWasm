;; SPDX-License-Identifier: EPL-2.0
;; Copyright (c) the ClojureWasm authors. Licensed under EPL-2.0.
;; Independently reimplements the clojure.uuid API (originally Rich Hickey; Clojure, EPL-1.0)
;; for ClojureWasm; no upstream source text is reproduced.
;;
;; In ClojureWasm the `#uuid "…"` reader literal and the `#uuid "…"` print form
;; are BUILT IN (the reader's default data-readers + the UUID print path), so this
;; namespace is a thin require-compatibility shim: a library that `(require
;; 'clojure.uuid)` for its side-effects (upstream registers a UUID print-method)
;; must load, and cljw already prints UUIDs in the `#uuid` form. `default-uuid-reader`
;; is exposed PUBLIC here (upstream `defn-` private) so the shim carries callable,
;; testable content rather than a dead private var — a harmless superset that changes
;; no existing behaviour.

(ns clojure.uuid)

(defn default-uuid-reader
  "Reads a `#uuid` form: parses the string into a UUID (the data-reader fn for the
  `#uuid` tag; the tag itself is wired into the reader by default in ClojureWasm)."
  [form]
  (if (string? form)
    (java.util.UUID/fromString form)
    (throw (ex-info "#uuid data reader expected a string" {:form form}))))
