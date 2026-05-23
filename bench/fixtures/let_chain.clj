;; Long lexical-binding chain. Each binding shadows nothing and
;; references the previous, so the analyzer must thread the local
;; slot through eight scopes and tree-walk must walk that frame on
;; every lookup.
(let [a 1
      b (+ a 1)
      c (+ b 1)
      d (+ c 1)
      e (+ d 1)
      f (+ e 1)
      g (+ f 1)
      h (+ g 1)]
  h)
