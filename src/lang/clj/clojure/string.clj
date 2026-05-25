;; clojure.string — ADR-0032 + ADR-0029 + Phase 6.9 cycle 1.
;;
;; Loaded by `src/lang/bootstrap.zig::loadCore` after `core.clj`.
;; The (in-ns) header is mandatory — the bootstrap loader carries no
;; namespace knowledge, so each multi-file source declares its own
;; namespace via the analyzer special form `in-ns` (ADR-0032).
;;
;; Cycle 1 ships nothing in this file beyond the (in-ns) header —
;; upper-case / lower-case / blank? are registered into clojure.string
;; from `src/lang/primitive/string.zig` because pure-Clojure
;; implementations would need primitives that haven't landed yet
;; (codepoint iteration callouts to runtime/charset.zig). Cycles 2-4
;; add Clojure-side defns for composite vars (capitalize uses upper +
;; lower + subs; split-lines uses a small regex; etc.) per the
;; per-task survey at private/notes/phase6-6.9-survey.md §6.

(in-ns 'clojure.string)
