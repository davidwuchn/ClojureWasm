;; Recursive Fibonacci. Exercises user-fn dispatch, recursive var
;; lookup, conditional, and integer arithmetic. Forward-declared via
;; `def fib nil` so the body's `fib` reference resolves to a Var at
;; analysis time; eval-time lookup picks up the second def. n=12
;; keeps per-run wall-time at sub-millisecond on TreeWalk so 50
;; iterations fit inside the quick.sh budget.
(def fib nil)
(def fib
  (fn* [n]
    (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2))))))

(fib 12)
