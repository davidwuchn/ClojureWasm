;; cljw.error — cw-original error-handling surface (ADR-0055, row 14.13).
;;
;; Loaded by `src/lang/bootstrap.zig::loadCore` after `core.clj`. The
;; dynamic var `cljw.error/*error-context*` is NOT defined here — it is
;; interned from Zig (`runtime/error/context.zig::register`, called by
;; setupCore after loadCore) with `flags.dynamic = true` so the error
;; subsystem holds that Var's pointer directly and can snapshot the live
;; context at raise time, merging it into the EDN error event.
;;
;; `with-context` is a thin macro over the `binding` special form
;; (ADR-0055 D1). It hand-builds the expansion with explicit
;; cons/list/vector and emits the qualified symbol
;; `cljw.error/*error-context*` via `quote`, so the expansion resolves
;; the var regardless of the use-site namespace.

(ns cljw.error (:refer-clojure))

;; (with-context {:request-id id :trace-id t} body...) =>
;;   (binding [cljw.error/*error-context*
;;             (merge cljw.error/*error-context* {:request-id id ...})]
;;     body...)
;; Nested with-context accumulate via merge.
(defmacro with-context [ctx-map & body]
  (cons 'binding
        (cons [(quote cljw.error/*error-context*)
               (list 'merge (quote cljw.error/*error-context*) ctx-map)]
              body)))
