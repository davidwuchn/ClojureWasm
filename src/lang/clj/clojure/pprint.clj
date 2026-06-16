;; SPDX-License-Identifier: EPL-2.0
;; Copyright (c) the ClojureWasm authors. Licensed under EPL-2.0.
;; Independently reimplements the clojure.pprint API (originally Tom Faulhaber; Clojure, EPL-1.0)
;; for ClojureWasm; no upstream source text is reproduced.

;; clojure.pprint — minimum pretty-print surface. cw v1 §9.12 row 10.2.
;;
;; Pattern A defns over clojure.core/println + clojure.string/join.
;; `pprint` currently aliases to `println` (cw v1's default `prn`
;; output already matches JVM short-form pretty-print for the
;; map / vector / set / list literals that the existing reader
;; produces); a real width-aware indenter is deferred until
;; user demand surfaces.
;; `print-table` formats a seq of maps with shared keys as a
;; pipe-separated table; takes the keys from the first row.
;; `cl-format` and the rest of JVM clojure.pprint surface are
;; deferred — they require a non-trivial formatting DSL impl that
;; lands when needed.
(ns clojure.pprint
  (:refer-clojure))

;; Dispatch surface (D-402). cljw has no width-aware indenter / code-specific
;; formatter, so both dispatches are the SAME pr-readable single-line printer (a
;; documented divergence from JVM pprint's multi-line layout + code indentation).
;; The indirection exists so `with-pprint-dispatch` / `code-dispatch` resolve and
;; bind — what macro-pretty-printing libs need (clojure.tools.logging's `spy`).
;; Using `pr` (not `println`) also fixes the string-quoting divergence: cljw
;; `(pprint "x")` now prints `"x"`, matching clj, not the bare `x` println gave.
(def simple-dispatch (fn* [x] (pr x)))
(def code-dispatch (fn* [x] (pr x)))

(def ^:dynamic *print-pprint-dispatch* simple-dispatch)

(defmacro with-pprint-dispatch
  "Evaluate `body` with *print-pprint-dispatch* bound to `dispatch`."
  [dispatch & body]
  `(binding [*print-pprint-dispatch* ~dispatch] ~@body))

(def pprint
  (fn* [x] (*print-pprint-dispatch* x) (newline)))

;; `print-table` — clj's exact format (F-011): a leading blank line, a padded
;; `| col | col |` header, a `|----+----|` rule, then one padded row per map.
;; Column width = max(key width, widest value). `ks` defaults to the first row's
;; keys. Ported from clojure.pprint/print-table (was a simpler non-matching form).
(defn print-table
  ([ks rows]
   (when (seq rows)
     (let [widths (map (fn [k] (apply max (count (str k)) (map (fn [r] (count (str (get r k)))) rows))) ks)
           spacers (map (fn [w] (apply str (repeat w "-"))) widths)
           fmts (map (fn [w] (str "%" w "s")) widths)
           fmt-row (fn [leader divider trailer row]
                     (str leader
                          (apply str (interpose divider
                                                (for [pair (map vector (map (fn [k] (get row k)) ks) fmts)]
                                                  (format (second pair) (str (first pair))))))
                          trailer))]
       (println)
       (println (fmt-row "| " " | " " |" (zipmap ks ks)))
       (println (fmt-row "|-" "-+-" "-|" (zipmap ks spacers)))
       (doseq [row rows] (println (fmt-row "| " " | " " |" row))))))
  ([rows] (print-table (keys (first rows)) rows)))

;; `(cl-format stream fmt & args)` — Common-Lisp-format subset (D-403 + D-455).
;; ~A aesthetic, ~S standard (pr-readable), ~D decimal, ~F fixed float, ~X/~O radix,
;; ~B binary, ~R numerals (~R cardinal / ~:R ordinal / ~@R Roman / ~NR radix),
;; ~{~^~} list iteration, ~(~) case-region (~( lower / ~:( cap-words / ~@( cap-first
;; / ~:@( upper), ~% newline, ~C char, ~& fresh-line (~N& adds N-1 more), ~~ literal
;; ~. Number directives parse the `~mincol,'padchar` parameter grammar (+ `:`
;; grouped) and delegate to `format`. A nil stream returns the string; any other
;; stream prints to *out* + returns nil. The remaining long-tail directives
;; (~P plural, ~T column, ~* arg-jump, ~E/~G sci-float, and the ~:C/~:P/~:*
;; arg-navigator/back-up variants) raise (no silent mishandle) — see D-455; these
;; need the upstream arg-navigator + column-writer architecture (cl_format.clj).
(defn cl-digit? [c] (let [i (int c)] (and (>= i (int \0)) (<= i (int \9)))))
(defn cl-int [c] (- (int c) (int \0)))

;; Parse a directive's `~[params][:][@]d` prefix from `fmt` starting at `i` (the
;; char just after `~`). Returns [params colon? at? directive-char next-i], where
;; params is a vector of (long | char | nil) — `~5,'0d` → [5 \0], `~,2f` → [nil 2].
(defn cl-dir [fmt i]
  (loop [j i params [] cur nil cur? false colon? false at? false]
    (let [c (nth fmt j)]
      (cond
        (cl-digit? c) (recur (inc j) params (+ (* (or cur 0) 10) (cl-int c)) true colon? at?)
        (= c \') (recur (+ j 2) (conj params (nth fmt (inc j))) nil false colon? at?)
        (= c \,) (recur (inc j) (conj params (if cur? cur nil)) nil false colon? at?)
        (= c \:) (recur (inc j) params cur cur? true at?)
        (= c \@) (recur (inc j) params cur cur? colon? true)
        :else [(if cur? (conj params cur) params) colon? at? c (inc j)]))))

;; Left-pad `s` to `width` with `padchar` (CL-format right-justification default).
(defn cl-pad [s width padchar]
  (let [len (count s) w (or width 0)]
    (if (< len w) (str (apply str (repeat (- w len) padchar)) s) s)))

;; Find the sub-format between an opener (at index `i`) and its matching `~<close>`
;; (`~}` for iteration, `~)` for case). Returns [subfmt next-i]. (Non-nested.)
(defn cl-close [fmt i close]
  (loop [j i]
    (if (and (= (nth fmt j) \~) (= (nth fmt (inc j)) close)) [(subs fmt i j) (+ j 2)] (recur (inc j)))))

;; Capitalize the first letter of each space-separated word, lowercasing the rest
;; (the `~:(` transform). Manual char walk — a regex literal cannot live in a
;; bundled `.clj` (cycle-1 reader limitation).
(defn cl-cap-words [s]
  (loop [cs (seq s) prev-space? true acc ""]
    (if (nil? cs)
      acc
      (let [c (first cs) sp? (= c \space)]
        (recur (next cs) sp?
               (str acc (if (and prev-space? (not sp?))
                          (clojure.string/upper-case (str c))
                          (clojure.string/lower-case (str c)))))))))

;; `~(`-region case transform per the `:`/`@` flags: ~( lower / ~:( cap-each-word
;; / ~@( cap-first / ~:@( upper.
(defn cl-case [s colon? at?]
  (cond
    (and colon? at?) (clojure.string/upper-case s)
    colon? (cl-cap-words s)
    at? (clojure.string/capitalize s)
    :else (clojure.string/lower-case s)))

;; ~R numeral directives. cl-cardinal n → English words ("forty-two");
;; groups of 3 digits are joined with ", " (clj-faithful). cl-ordinal → "forty-
;; second" (the last cardinal word gets the ordinal suffix). cl-roman → subtractive
;; Roman ("XLII"). Radix (~NR) is `(Long/toString n base)` inline in cl-run.
(def cl-ones ["zero" "one" "two" "three" "four" "five" "six" "seven" "eight" "nine"
              "ten" "eleven" "twelve" "thirteen" "fourteen" "fifteen" "sixteen"
              "seventeen" "eighteen" "nineteen"])
(def cl-tens ["" "" "twenty" "thirty" "forty" "fifty" "sixty" "seventy" "eighty" "ninety"])
(def cl-scales ["" " thousand" " million" " billion" " trillion" " quadrillion"])
(defn cl-under-100 [n]
  (cond (< n 20) (cl-ones n)
        (zero? (rem n 10)) (cl-tens (quot n 10))
        :else (str (cl-tens (quot n 10)) "-" (cl-ones (rem n 10)))))
(defn cl-under-1000 [n]
  (if (< n 100)
    (cl-under-100 n)
    (let [h (quot n 100) r (rem n 100)]
      (str (cl-ones h) " hundred" (when (pos? r) (str " " (cl-under-100 r)))))))
(defn cl-cardinal [n]
  (cond (zero? n) "zero"
        (neg? n) (str "minus " (cl-cardinal (- n)))
        :else (loop [n n i 0 parts ()]
                (if (zero? n)
                  (clojure.string/join ", " parts)
                  (let [grp (rem n 1000)]
                    (recur (quot n 1000) (inc i)
                           (if (pos? grp) (cons (str (cl-under-1000 grp) (cl-scales i)) parts) parts)))))))
(def cl-ord-ones {"one" "first" "two" "second" "three" "third" "five" "fifth"
                  "eight" "eighth" "nine" "ninth" "twelve" "twelfth"})
(defn cl-ordinalize-word [w]
  (cond (contains? cl-ord-ones w) (cl-ord-ones w)
        (clojure.string/ends-with? w "y") (str (subs w 0 (dec (count w))) "ieth")
        :else (str w "th")))
(defn cl-ordinal [n]
  (let [c (cl-cardinal n) idx (max (.lastIndexOf c " ") (.lastIndexOf c "-"))]
    (str (subs c 0 (inc idx)) (cl-ordinalize-word (subs c (inc idx))))))
(def cl-roman-pairs [[1000 "M"] [900 "CM"] [500 "D"] [400 "CD"] [100 "C"] [90 "XC"]
                     [50 "L"] [40 "XL"] [10 "X"] [9 "IX"] [5 "V"] [4 "IV"] [1 "I"]])
(defn cl-roman [n]
  (loop [n n acc "" pairs cl-roman-pairs]
    (if (or (zero? n) (empty? pairs))
      acc
      (let [pr (first pairs) v (first pr) s (second pr)]
        (if (>= n v) (recur (- n v) (str acc s) pairs) (recur n acc (rest pairs)))))))

(declare cl-iter)

;; Current output column = chars since the last newline in `s` (~T uses it).
(defn cl-col [s]
  (loop [i (dec (count s)) c 0]
    (if (or (< i 0) (= (nth s i) \newline)) c (recur (dec i) (inc c)))))

;; ~T tabulate: spaces to reach column `colnum`; if already at/past it, advance
;; to the next `colinc` multiple beyond `colnum` (CL semantics; colinc<=0 = no-op).
(defn cl-tab [acc colnum colinc]
  (let [col (cl-col acc)
        need (if (< col colnum)
               (- colnum col)
               (if (<= colinc 0) 0 (- colinc (mod (- col colnum) colinc))))]
    (apply str (repeat (max 0 need) \space))))

;; ~$ monetary: ~d,n,w,padchar$ — d decimals after point (default 2), n minimum
;; integer digits (default 1, zero-padded), w minimum total width, padchar (default
;; space). `@` forces a leading "+" on non-negatives. `:` places the sign before the
;; width padding (`@:` → "+    12.0"); the default folds the sign into the padded body.
(defn cl-money [x dec n w padc at? colon?]
  (let [neg? (neg? x)
        mag (format (str "%." dec "f") (if neg? (- (double x)) (double x)))
        di (clojure.string/index-of mag ".")
        intp (if di (subs mag 0 di) mag)
        frac (if di (subs mag di) "")
        intp (if (< (count intp) n) (str (apply str (repeat (- n (count intp)) \0)) intp) intp)
        sign (cond neg? "-" at? "+" :else "")
        body (str intp frac)]
    (if (and colon? (not= sign ""))
      (str sign (cl-pad body (when w (- w (count sign))) padc))
      (cl-pad (str sign body) w padc))))

;; Run `fmt` over the operand vector `argv` from index `pos0`, returning
;; [acc next-pos]. The index navigator lets ~* jump and ~:P / ~:* back up. `~^`
;; (escape) returns early, which `~{~}` iteration uses to stop before the
;; trailing separator once the operands are exhausted.
(defn cl-run [fmt argv pos0]
  (let [n (count fmt) na (count argv)]
    (loop [i 0 pos pos0 acc ""]
      (if (>= i n)
        [acc pos]
        (let [c (nth fmt i)]
          (if (and (= c \~) (< (inc i) n))
            (let [pd (cl-dir fmt (inc i))
                  params (nth pd 0) colon? (nth pd 1) at? (nth pd 2) d (nth pd 3) ni (nth pd 4)
                  p0 (first params) p1 (second params)
                  x (when (< pos na) (nth argv pos))]
              (cond
                (or (= d \a) (= d \A)) (recur ni (inc pos) (str acc (if (string? x) x (pr-str x))))
                (or (= d \s) (= d \S)) (recur ni (inc pos) (str acc (pr-str x)))
                (or (= d \d) (= d \D))
                (recur ni (inc pos) (str acc (cl-pad (if colon? (format "%,d" x) (str x)) p0 (or p1 \space))))
                (or (= d \f) (= d \F))
                (recur ni (inc pos) (str acc (format (str "%" (if p0 p0 "") "." (or p1 0) "f") (double x))))
                (or (= d \x) (= d \X)) (recur ni (inc pos) (str acc (cl-pad (format "%x" x) p0 (or p1 \space))))
                (or (= d \o) (= d \O)) (recur ni (inc pos) (str acc (cl-pad (format "%o" x) p0 (or p1 \space))))
                (or (= d \b) (= d \B)) (recur ni (inc pos) (str acc (cl-pad (Long/toBinaryString x) p0 (or p1 \space))))
                (or (= d \r) (= d \R))
                (recur ni (inc pos) (str acc (cond p0 (Long/toString x p0)
                                                   at? (cl-roman x)
                                                   colon? (cl-ordinal x)
                                                   :else (cl-cardinal x))))
                ;; ~{...~} — iterate over a list arg (~@{ over the remaining args).
                (= d \{)
                (let [cl (cl-close fmt ni \})]
                  (if at?
                    (recur (nth cl 1) na (str acc (cl-iter (nth cl 0) (subvec argv (min pos na)))))
                    (recur (nth cl 1) (inc pos) (str acc (cl-iter (nth cl 0) x)))))
                (= d \()
                (let [cl (cl-close fmt ni \)) r (cl-run (nth cl 0) argv pos)]
                  (recur (nth cl 1) (nth r 1) (str acc (cl-case (nth r 0) colon? at?))))
                (= d \^) (if (>= pos na) [acc pos] (recur ni pos acc))
                (= d \%) (recur ni pos (str acc \newline))
                ;; ~T — tabulate: pad with spaces to reach column p0 (default 1),
                ;; then at least colinc=p1 (default 1) more if already at/past it.
                (or (= d \t) (= d \T)) (recur ni pos (str acc (cl-tab acc (or p0 1) (or p1 1))))
                ;; ~P plural — "s" unless arg is 1; ~@P → y/ies; ~:P backs up to
                ;; re-read the previous arg (the common "~D dog~:P" idiom).
                (or (= d \p) (= d \P))
                (let [pv (if colon? (nth argv (dec pos)) x)
                      np (if colon? pos (inc pos))]
                  (recur ni np (str acc (if at? (if (= pv 1) "y" "ies") (if (= pv 1) "" "s")))))
                ;; ~* arg-jump — ~N* forward N (default 1), ~N:* back N, ~N@* absolute.
                (= d \*)
                (let [np (cond at? (or p0 0)
                               colon? (- pos (or p0 1))
                               :else (+ pos (or p0 1)))]
                  (recur ni np acc))
                ;; ~C — print a character (plain; ~:C/~@C named/readable variants
                ;; are not modelled).
                (and (or (= d \c) (= d \C)) (not colon?) (not at?)) (recur ni (inc pos) (str acc x))
                ;; ~& — fresh-line: a newline only if not already at line start;
                ;; ~N& adds N-1 further newlines.
                (= d \&)
                (let [fresh (if (or (= acc "") (= (last acc) \newline)) acc (str acc \newline))]
                  (recur ni pos (apply str fresh (repeat (if p0 (dec p0) 0) \newline))))
                ;; ~$ — monetary fixed-format (params ~d,n,w,padchar$).
                (= d \$)
                (recur ni (inc pos)
                       (str acc (cl-money x (or p0 2) (or p1 1) (nth params 2 nil) (nth params 3 \space) at? colon?)))
                (= d \~) (recur ni pos (str acc \~))
                :else (throw (ex-info (str "cl-format: directive ~" d " is not supported in ClojureWasm") {}))))
            (recur (inc i) pos (str acc c))))))))

;; Apply `subfmt` repeatedly over `lst`, consuming elements each pass; `~^` in
;; `subfmt` exits when the list is exhausted (so the trailing separator is dropped
;; on the last element). `(cl-run subfmt items)` returning `items` unchanged means
;; `~^` fired with nothing consumed → stop.
(defn cl-iter [subfmt lst]
  (let [v (vec lst) nv (count v)]
    (loop [pos 0 acc ""]
      (if (>= pos nv)
        acc
        (let [r (cl-run subfmt v pos)]
          (if (= (nth r 1) pos) acc (recur (nth r 1) (str acc (nth r 0)))))))))

(defn cl-format [stream fmt & args]
  (let [result (nth (cl-run fmt (vec args) 0) 0)]
    (if (nil? stream) result (do (print result) nil))))
