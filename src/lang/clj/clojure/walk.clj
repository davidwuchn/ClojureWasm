;; clojure.walk — Phase 6.11 cycle 1.
;;
;; Loaded by `src/lang/bootstrap.zig::loadCore` per ADR-0032's
;; multi-file FILES table. The spine vars (`walk` / `prewalk` /
;; `postwalk`) are registered from `src/lang/primitive/walk.zig`
;; directly into this namespace (DIVERGENCE D1 in the per-task
;; survey) — this `.clj` file currently exists to pin the (in-ns)
;; header for future cycle-2/3 defns (`keywordize-keys` etc.) and
;; to keep the bootstrap-loader pattern consistent across every
;; Tier-A namespace.

;; PROVISIONAL: bare (in-ns 'foo) special form pending (ns ...) macro [refs: D-063, D-071, feature_deps.yaml#runtime/eval/bare_in_ns_decl]
(in-ns 'clojure.walk)
