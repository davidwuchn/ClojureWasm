;; clojure.data.priority-map — a priority map (deftype over the full
;; clojure.lang host-interface stack). Verified loadable + functional on cljw.
(require '[clojure.data.priority-map :refer [priority-map]])
(let [pm (priority-map :a 3 :b 1 :c 2)]
  (assert (= [:b 1] (peek pm)))          ; lowest priority
  (assert (= 3 (count pm)))
  (assert (= '(:b :c :a) (keys pm)))     ; priority order
  (assert (= '(1 2 3) (vals pm))))
(println "OK data.priority-map — peek/count/keys/vals")
