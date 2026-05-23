;; Reader-built heap list with 50 elements. Until cons/conj land
;; (Phase 5+), this measures reader -> analyzer -> quote-Value
;; construction for a flat persistent list. Phase 5 will swap to
;; (loop [i 0 acc nil] ... (recur ... (cons i acc))) once cons is
;; primitive.
(quote (0 1 2 3 4 5 6 7 8 9
        10 11 12 13 14 15 16 17 18 19
        20 21 22 23 24 25 26 27 28 29
        30 31 32 33 34 35 36 37 38 39
        40 41 42 43 44 45 46 47 48 49))
