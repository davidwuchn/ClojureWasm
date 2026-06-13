;; clojure.math.numeric-tower — the integer/ratio numeric-tower fns (round,
;; floor, ceil, sqrt, expt, gcd, lcm, abs, exact-integer-sqrt). Run by
;; `cljw -M:verify` (-> verify/-main). D-420 unblocked this lib: `round`
;; needs `(resolve 'clojure.lang.BigInt)` to gate its BigInt `extend-type`
;; (D-421); `floor`/`ceil`/`sqrt`-on-ratio need BigDecimal `.setScale` +
;; Ratio `.numerator`/`.denominator` interop. Assertions are VALUE-based:
;; floor/ceil on a ratio return a Long in cljw vs BigInt in clj (AD-031,
;; F-005 narrow-when-fits) — `(= 2 2N)` holds, so `=` is clj-faithful.
(ns verify
  (:require [clojure.math.numeric-tower :as nt]))

(defn -main [& _]
  (assert (= 3 (nt/round 5/2)))            ; round → BigInt (D-421 gate)
  (assert (= 4 (nt/round 7/2)))
  (assert (= 2 (nt/round 2.4)))
  (assert (= 2 (nt/floor 5/2)))            ; floor/ceil on ratio = clj value
  (assert (= 2.0 (nt/floor 2.7)))
  (assert (= 3 (nt/ceil 5/2)))
  (assert (= 3.0 (nt/ceil 2.1)))
  (assert (= 4 (nt/sqrt 16)))
  (assert (= 1/4 (nt/expt 2 -2)))
  (assert (= 1024 (nt/expt 2 10)))
  (assert (= 1/8 (nt/expt 1/2 3)))
  (assert (= 6 (nt/gcd 12 18)))
  (assert (= 12 (nt/lcm 4 6)))
  (assert (= 7 (nt/abs -7)))
  (assert (= 3/4 (nt/abs -3/4)))
  (assert (= [4 1] (nt/exact-integer-sqrt 17)))
  (println "OK math.numeric-tower — round/floor/ceil/sqrt/expt/gcd/lcm/abs/exact-integer-sqrt"))
