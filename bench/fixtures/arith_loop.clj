;; Tight integer loop via loop*/recur. Measures the recur backedge
;; (no user-fn call frame), the binding update, and pairwise + on
;; longs. 1000 iterations is short enough that the dominant cost
;; stays in dispatch rather than arithmetic.
(loop* [i 0 acc 0]
  (if (< i 1000)
    (recur (+ i 1) (+ acc i))
    acc))
