;; Deeply nested quoted form with integer leaves. Exercises reader
;; recursion depth and the cons chain produced by `quote` on a
;; tree-shaped literal. Ten levels of nesting; each level allocates
;; one cons cell at quote time. (Symbol literals as Values are not
;; activated until Phase 8+, so the leaves are integers.)
(quote (1 (2 (3 (4 (5 (6 (7 (8 (9 (10)))))))))))
