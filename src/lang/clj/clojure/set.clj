;; clojure.set — Phase 6.10 cycle 1.
;;
;; Loaded by `src/lang/bootstrap.zig::loadCore` per ADR-0032's
;; multi-file FILES table. The Group A vars (`union` /
;; `intersection` / `difference` / `subset?` / `superset?`) are
;; registered from `src/lang/primitive/set.zig` directly into this
;; namespace (DIVERGENCE D1 in the per-task survey) — this `.clj`
;; file currently exists to pin the (in-ns) header for future
;; defns (e.g. `select` / `project` once map literals lift per
;; D-061), and to keep the bootstrap-loader pattern consistent
;; across every Tier-A namespace.

(in-ns 'clojure.set)
