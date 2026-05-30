;; ClojureWasm Stage-1 prologue.
;;
;; Loaded by `src/lang/bootstrap.zig::loadCore` after
;; `primitive.registerAll` and `macro_transforms.registerInto`. The
;; head form is `(ns clojure.core (:refer-clojure))` per ADR-0035 D1
;; — the analyzer special form switches into clojure.core (creating
;; the ns at boot via `Env.init`, idempotent here) and honours
;; `:refer-clojure` (a no-op when we ARE clojure.core; kept for
;; surface-uniformity with the other bootstrap files).

(ns clojure.core (:refer-clojure))

(def not (fn* [x] (if x false true)))

;; `(list & items)` — construct a list of the args. cw v1's variadic
;; rest-binding already yields a `.list`, so the thin `[& xs] xs` body is
;; the finished form (no Zig leaf needed).
(def list (fn* [& xs] xs))

;; ----------------------------------------------------------------
;; Phase 6.16.a-3.2 — eager higher-order surface (ADR-0033 D6 + v5 §5.2).
;;
;; Each surface fn delegates to its Zig leaf (`-foo-eager`) via the
;; `-name` Pattern B2 contract from ADR-0033 D4. Transducer 1-arg
;; arity (`(map f)` returning an xform) is **deferred** until cw v1
;; `fn*`/`defn` gains multi-arity support (tracked at D-NEW-2). For
;; this cycle these are eager-only forms — JVM `clojure.core/map` is
;; lazy, cw v1 `map` here builds the full list eagerly. The full
;; lazy + transducer semantics land at Phase 7+ once lazy-seq Layer
;; 2 wiring and multi-arity `fn*` both land.
;; ----------------------------------------------------------------

;; map / filter / keep / remove / drop are LAZY (ADR-0054 cycle 2/3):
;; each wraps its step in `lazy-seq` so it composes with infinite
;; producers (`(first (map inc (iterate inc 0)))` → 1, no hang;
;; `(first (drop 100 (range)))` → 100). `take` stays bounded-eager (it
;; realizes only N, so it already terminates on an infinite source).
;; The `-*-eager` map/filter/keep/remove/drop leaves are deleted.
;; `map` — 1/2/3-coll. Multi-coll walks colls in parallel, stops at the
;; shortest (D-134). N-coll variadic (`& colls`) deferred: it needs
;; every?/identity which are later core.clj defns (def-order; fn-body
;; symbols resolve at def time), so it would need a primitive-only seq-all.
(def map
  (fn* ([f]
        ;; transducer arity: (map f) returns a transducer
        (fn* [rf]
          (fn* ([] (rf))
               ([result] (rf result))
               ([result input] (rf result (f input))))))
       ([f coll]
        (lazy-seq
          (let [s (seq coll)]
            (if s (cons (f (first s)) (map f (rest s))) nil))))
       ([f c1 c2]
        (lazy-seq
          (let [s1 (seq c1) s2 (seq c2)]
            (if (and s1 s2)
              (cons (f (first s1) (first s2)) (map f (rest s1) (rest s2)))
              nil))))
       ([f c1 c2 c3]
        (lazy-seq
          (let [s1 (seq c1) s2 (seq c2) s3 (seq c3)]
            (if (and s1 s2 s3)
              (cons (f (first s1) (first s2) (first s3))
                    (map f (rest s1) (rest s2) (rest s3)))
              nil))))))
(def filter
  (fn* ([pred]
        ;; transducer arity
        (fn* [rf]
          (fn* ([] (rf))
               ([result] (rf result))
               ([result input] (if (pred input) (rf result input) result)))))
       ([pred coll]
        (lazy-seq
          (let [s (seq coll)]
            (if s
              (if (pred (first s))
                (cons (first s) (filter pred (rest s)))
                (filter pred (rest s)))
              nil))))))
(def take
  (fn* ([n]
        ;; transducer arity: stateful (counts down n), ensure-reduced to stop
        (fn* [rf]
          (let [nv (volatile! n)]
            (fn* ([] (rf))
                 ([result] (rf result))
                 ([result input]
                  (let [m @nv
                        nm (vswap! nv dec)
                        result (if (> m 0) (rf result input) result)]
                    (if (not (> nm 0)) (ensure-reduced result) result)))))))
       ([n coll] (-take-eager n coll))))
(def drop
  (fn* ([n]
        ;; transducer arity: stateful (skips the first n inputs)
        (fn* [rf]
          (let [nv (volatile! n)]
            (fn* ([] (rf))
                 ([result] (rf result))
                 ([result input]
                  (let [m @nv]
                    (vswap! nv dec)
                    (if (> m 0) result (rf result input))))))))
       ([n coll]
        (lazy-seq
          (let [s (seq coll)]
            (if (and (> n 0) s)
              (drop (dec n) (rest s))
              s))))))
;; nthnext/nthrest: [coll n] arg order (JVM clojure.core). The sequential
;; destructure `& rest` lowering (D-076) emits (nthnext g idx). nthnext
;; seqs (nil when empty); nthrest returns the rest coll as-is.
(def nthnext (fn* [coll n] (seq (drop n coll))))
(def nthrest (fn* [coll n] (drop n coll)))
(def keep
  (fn* ([f]
        ;; transducer arity: keeps the non-nil (f input)
        (fn* [rf]
          (fn* ([] (rf))
               ([result] (rf result))
               ([result input] (let [v (f input)] (if (nil? v) result (rf result v)))))))
       ([f coll]
        (lazy-seq
          (let [s (seq coll)]
            (if s
              (let [r (f (first s))]
                (if (nil? r) (keep f (rest s)) (cons r (keep f (rest s)))))
              nil))))))
(def remove
  (fn* ([pred]
        ;; transducer arity: drops inputs where pred is truthy
        (fn* [rf]
          (fn* ([] (rf))
               ([result] (rf result))
               ([result input] (if (pred input) result (rf result input))))))
       ([pred coll] (filter (fn* [x] (not (pred x))) coll))))

;; ----------------------------------------------------------------
;; Transducer drivers (the foundation — reduced?/unreduced/reduce —
;; already exists). `cat` + the stateful transducers (take/drop/
;; dedupe/distinct/partition-all) land in later cycles.
;; ----------------------------------------------------------------

;; `(completing f)` / `(completing f cf)` — adapt a 2-arg fn into a
;; reducing fn with 0-arg init `(f)`, 1-arg completion (`cf`, default
;; identity), and 2-arg step `(f x y)`.
(def completing
  (fn* ([f] (fn* ([] (f)) ([x] x) ([x y] (f x y))))
       ([f cf] (fn* ([] (f)) ([x] (cf x)) ([x y] (f x y))))))

;; `(transduce xform f coll)` / `(transduce xform f init coll)` — reduce
;; `coll` through the transformed reducing fn, then call its 1-arg
;; completion. `(f)` supplies the init when omitted.
(def transduce
  (fn* ([xform f coll] (transduce xform f (f) coll))
       ([xform f init coll]
        (let [rf (xform f)
              ret (reduce rf init coll)]
          (rf (unreduced ret))))))

;; `(into to from)` conj every item of `from` onto `to`; `(into to xform
;; from)` does so through the transducer `xform`. Defined here (Layer 2)
;; over reduce/transduce — supersedes the rt/into eager primitive (which
;; had no other Zig callers). `conj`'s 1-arg completion arity makes the
;; bare-`conj` reducing fn work for the transduce path.
(def into
  (fn* ([to from] (reduce conj to from))
       ([to xform from] (transduce xform conj to from))))

;; `(-preserving-reduced rf)` wraps rf so that a Reduced result from an
;; INNER reduce (cat uses one) is double-wrapped — the outer reduce then
;; sees the early-stop instead of cat swallowing it.
(def -preserving-reduced
  (fn* [rf]
    (fn* [a b]
      (let [ret (rf a b)]
        (if (reduced? ret) (reduced ret) ret)))))

;; `cat` — a transducer that concatenates the contents of each input
;; (each input is itself reduced into the downstream rf).
(def cat
  (fn* [rf]
    (let [rrf (-preserving-reduced rf)]
      (fn* ([] (rf))
           ([result] (rf result))
           ([result input] (reduce rrf result input))))))

;; `(halt-when pred)` / `(halt-when pred retf)` — a transducer that aborts
;; the whole transduction when an input matches `pred`, yielding that input
;; (or `(retf (rf result) input)` when `retf` is supplied). The halt value
;; rides through the 1-arg completion inside a qualified-keyword sentinel
;; map so a normal accumulated map result is not mistaken for a halt.
(def halt-when
  (fn* ([pred] (halt-when pred nil))
       ([pred retf]
        (fn* [rf]
          (fn* ([] (rf))
               ([result]
                (if (if (map? result) (contains? result :cljw.core/halt) false)
                  (get result :cljw.core/halt)
                  (rf result)))
               ([result input]
                (if (pred input)
                  (reduced {:cljw.core/halt (if retf (retf (rf result) input) input)})
                  (rf result input))))))))

;; ----------------------------------------------------------------
;; Pure Clojure HOF (no Zig leaf) — pattern A per ADR-0033 D3.
;; ----------------------------------------------------------------

;; `(constantly x)` returns a fn that ignores its args and yields x.
(def constantly
  (fn* [x] (fn* [& _] x)))

;; `(complement pred)` returns a fn that negates pred's truthiness.
;; Single-arg only at this cycle (transducer arities + multi-arg
;; pred deferred per D-NEW-2).
(def complement
  (fn* [pred] (fn* [& args] (not (apply pred args)))))

;; `(comparator pred)` builds a 3-way compare fn (-1 / 0 / 1) from a
;; 2-arg boolean `pred` (like `<`). Nested `if` (not `cond`) so it does
;; not depend on macro availability during bootstrap.
(def comparator
  (fn* [pred]
    (fn* [a b]
      (if (pred a b) -1 (if (pred b a) 1 0)))))

;; `(partial f & args)` partially applies f to the leading args.
;; The trailing arg list and the partial's captured args meet via
;; `(into (into [] args) more)` since cw v1 doesn't yet have
;; `concat`; the resulting vector goes through `apply`.
(def partial
  (fn* [f & args]
    (fn* [& more]
      (apply f (into (into [] args) more)))))

;; `(comp f g)` returns a fn that computes `(f (g x))`. Multi-fn
;; comp `(comp f g h)` deferred to D-NEW-2 multi-arity follow-up.
;; `comp` — variadic right-to-left function composition (D-134). `(comp)`
;; is identity; the N-ary case folds the 2-ary `comp` over the rest (comp
;; is associative). Composed fns take any arity via `& args` + `apply`.
(def comp
  (fn* ([] (fn* [x] x))
       ([f] f)
       ([f g] (fn* [& args] (f (apply g args))))
       ([f g & fs] (reduce comp (comp f g) fs))))

;; `juxt` — `((juxt f g …) & args)` yields `[(apply f args) (apply g args) …]`
;; (D-134: multi-fn + multi-arg; previously 2-fn / single-arg only).
(def juxt
  (fn* ([f] (fn* [& args] [(apply f args)]))
       ([f g] (fn* [& args] [(apply f args) (apply g args)]))
       ;; N-ary: build the result vector with reduce+conj (primitives —
       ;; `mapv` is a later core.clj defn, unresolvable at this def site).
       ([f g & fs]
        (fn* [& args]
          (reduce (fn* [acc h] (conj acc (apply h args)))
                  []
                  (cons f (cons g fs)))))))

;; `(some-fn p1 p2 …)` → a fn returning the first logical-true
;; `(pi & args)`, else nil. `(every-pred p1 p2 …)` → a fn returning
;; true iff every `(pi & args)` is logical-true, else false (D-134).
(def some-fn
  (fn* [& preds]
    (fn* [& args]
      (loop [ps preds]
        (when (seq ps)
          (let* [r (apply (first ps) args)]
            (if r r (recur (rest ps)))))))))

(def every-pred
  (fn* [& preds]
    (fn* [& args]
      (loop [ps preds]
        (if (seq ps)
          (if (apply (first ps) args) (recur (rest ps)) false)
          true)))))

;; `(trampoline f & args)` — call f; while the result is a fn, call it
;; (mutual-recursion without growing the stack). Self-recursive def.
(def trampoline
  (fn* ([f] (let* [ret (f)] (if (fn? ret) (trampoline ret) ret)))
       ([f & args] (trampoline (fn* [] (apply f args))))))

;; `(replace smap coll)` — replace elements of coll that are keys in
;; smap with their values. Vector in → vector out; seq in → lazy seq.
(def replace
  (fn* [smap coll]
    (if (vector? coll)
      (reduce (fn* [acc x] (conj acc (if (contains? smap x) (get smap x) x))) [] coll)
      (map (fn* [x] (if (contains? smap x) (get smap x) x)) coll))))

;; `(not= x …)` — logical complement of `=`. `(fnext x)` = `(first (next x))`,
;; `(nnext x)` = `(next (next x))` — the first/next combinators. `(run! f
;; coll)` applies f to each element for side effects, returns nil (D-134).
(def not= (fn* [& args] (not (apply = args))))
(def fnext (fn* [x] (first (next x))))
(def nnext (fn* [x] (next (next x))))
(def run! (fn* [f coll] (reduce (fn* [_ x] (f x)) nil coll) nil))

;; Bit-position ops over the bitwise primitives (n = bit index, 0 = LSB).
;; JVM Numbers.java inlines these; cw v1 composes them in .clj per the
;; clj/zig split (bit-and/or/xor/not/shift-left are the Zig primitives).
(def bit-set   (fn* [x n] (bit-or x (bit-shift-left 1 n))))
(def bit-clear (fn* [x n] (bit-and x (bit-not (bit-shift-left 1 n)))))
(def bit-flip  (fn* [x n] (bit-xor x (bit-shift-left 1 n))))
(def bit-test  (fn* [x n] (not (zero? (bit-and x (bit-shift-left 1 n))))))
(def bit-and-not (fn* [x y] (bit-and x (bit-not y))))

;; `(peek coll)` / `(pop coll)` — stack ops. Vector: peek = last element,
;; pop = drop the last (returns a vector). List/seq: peek = first, pop =
;; rest. peek of empty is nil; pop of empty throws (JVM parity). D-134.
(def peek
  (fn* [coll]
    (if (vector? coll)
      (if (pos? (count coll)) (nth coll (dec (count coll))) nil)
      (first coll))))
(def pop
  (fn* [coll]
    (if (vector? coll)
      (if (pos? (count coll))
        (into [] (take (dec (count coll)) coll))
        (throw (ex-info "Can't pop empty vector" {})))
      (if (seq coll)
        (rest coll)
        (throw (ex-info "Can't pop empty list" {}))))))

;; `(find m k)` — the map entry `[k v]` for key k if present, else nil
;; (distinguishes "absent" from "present with nil value" via contains?).
;; cw v1 represents the entry as a 2-vector (no distinct MapEntry type).
(def find
  (fn* [m k] (if (contains? m k) [k (get m k)] nil)))

;; `(subvec v start [end])` — the elements of v in [start, end) (end
;; defaults to (count v)) as a vector. cw v1 builds a fresh vector (O(n))
;; via take/drop rather than JVM's O(1) shared-structure view (D-134).
(def subvec
  (fn* ([v start] (into [] (drop start v)))
       ([v start end] (into [] (take (- end start) (drop start v))))))

;; `(bounded-count n coll)` — counts up to n elements (so it terminates on
;; infinite / expensive seqs). cw v1 always walks (≤ n steps); JVM short-
;; circuits to `(count coll)` for already-counted colls — a perf nicety,
;; same result for finite colls of size ≤ n (D-134).
(def bounded-count
  (fn* [n coll]
    (loop [c 0 s (seq coll)]
      (if (if s (< c n) false) (recur (inc c) (next s)) c))))

;; `(rand-nth coll)` — a uniformly random element of coll (which must be
;; indexed / counted). Empty coll → an out-of-bounds error (JVM parity).
(def rand-nth
  (fn* [coll] (nth coll (rand-int (count coll)))))

;; ----------------------------------------------------------------
;; Phase 6.16.b-3 helpers — used by clojure.set Group C (project /
;; rename / index / join). Pattern A composition; no Zig leaves.
;; ----------------------------------------------------------------

;; `(select-keys m ks)` — return a map containing only the keys in
;; `ks` that are present in `m`. JVM uses `find` to distinguish
;; "absent" from "nil-valued"; cw v1 uses `contains?` (same
;; semantic when nil-values are absent — Phase 7+ value-meta layer
;; adds `find`).
(def select-keys
  (fn* [m ks]
    (reduce (fn* [acc k]
              (if (contains? m k)
                (assoc acc k (get m k))
                acc))
            {}
            ks)))

;; `(merge & maps)` — right-most key wins. nil args are skipped.
;; Variadic via `[& maps]`; 0-arity returns nil (matches JVM).
(def merge
  (fn* [& maps]
    (if (= 0 (count maps))
      nil
      (reduce (fn* [acc m]
                (if (nil? m)
                  acc
                  (reduce (fn* [a k] (assoc a k (get m k)))
                          acc
                          (keys m))))
              (first maps)
              (rest maps)))))
;; `(merge-with f & maps)` — like merge, but a key present in more than
;; one map combines values via `(f existing new)` (D-134). nil maps skip.
(def merge-with
  (fn* [f & maps]
    (reduce (fn* [acc m]
              (if (nil? m)
                acc
                (reduce (fn* [a k]
                          (if (contains? a k)
                            (assoc a k (f (get a k) (get m k)))
                            (assoc a k (get m k))))
                        acc
                        (keys m))))
            {}
            maps)))

;; `(set coll)` — coerce a collection to a set. Duplicates collapse.
(def set
  (fn* [coll] (reduce conj #{} coll)))

;; `(distinct? x …)` — true iff no two arguments are equal (by value).
;; A set dedups by `=`, so distinct ⇔ the set keeps every element.
;; Defined after `set` (it folds args through it).
(def distinct?
  (fn* [& args] (= (count args) (count (set args)))))

;; ----------------------------------------------------------------
;; Phase 14 §9.16 row 14.13 — D-126 clojure.core daily-driver cluster.
;; Pattern A composition over reduce / get / assoc / first / next /
;; conj / into / apply. get-in/assoc-in/update-in walk a key path;
;; concat/mapcat are LAZY (ADR-0054 cycle 3): `-concat2` is the 2-coll
;; lazy-cons primitive both fold over, so they compose with infinite
;; producers (`(take 5 (concat [1 2] (range)))`).
;; ----------------------------------------------------------------

;; `(get-in m ks)` — walk the key path `ks` through nested associatives.
;; Returns nil when any step is absent (get on nil is nil). The
;; 3-arity `[m ks not-found]` is deferred until multi-arity fn* lands.
(def get-in
  (fn* [m ks] (reduce get m ks)))

;; `(assoc-in m ks v)` — assoc `v` at the nested path `ks`, creating
;; intermediate maps as needed. `next` yields nil at the final key.
(def assoc-in
  (fn* [m ks v]
    (let [k (first ks) nks (next ks)]
      (if nks
        (assoc m k (assoc-in (get m k) nks v))
        (assoc m k v)))))

;; `(update-in m ks f & args)` — apply `f` (with trailing `args`) to
;; the value at the nested path `ks`. Recursive descent like assoc-in;
;; the leaf calls `(apply f old args)`.
(def update-in
  (fn* [m ks f & args]
    (let [k (first ks) nks (next ks)]
      (if nks
        (assoc m k (apply update-in (into [(get m k) nks f] args)))
        (assoc m k (apply f (into [(get m k)] args)))))))

;; `(-concat2 x y)` — lazy catenation of two seqables. Walks `x`
;; element-by-element under `lazy-seq`, then hands off to `(seq y)`.
;; The shared lazy-cons primitive for `concat` and `mapcat`.
(def -concat2
  (fn* [x y]
    (lazy-seq
      (let [s (seq x)]
        (if s
          (cons (first s) (-concat2 (rest s) y))
          (seq y))))))

;; `(concat & colls)` — lazy left-to-right catenation (JVM-idiom).
;; Folds the (finite) arg list with `-concat2`; element realization
;; stays lazy. `(concat)` → nil; `(concat a)` → `(seq a)`.
(def concat
  (fn* [& colls]
    (reduce -concat2 nil colls)))

;; `(mapcat f coll)` — lazy `concat` of `(map f coll)`. Single-coll
;; form (multi-coll deferred, like `map`). Recurses under `lazy-seq`
;; so it composes with an infinite `coll`.
(def mapcat
  (fn* [f coll]
    (lazy-seq
      (let [s (seq coll)]
        (if s
          (-concat2 (f (first s)) (mapcat f (rest s)))
          nil)))))

;; `(tree-seq branch? children root)` — a lazy depth-first (pre-order) seq
;; of all nodes. `branch?` says whether a node can have children; `children`
;; returns them. Recurses through `tree-seq` itself (a top-level recursive
;; def) so it avoids a named local fn (D-147); `mapcat` keeps it lazy (D-134).
(def tree-seq
  (fn* [branch? children root]
    (lazy-seq
      (cons root
        (when (branch? root)
          (mapcat (fn* [c] (tree-seq branch? children c)) (children root)))))))

;; ----------------------------------------------------------------
;; Phase 14 §9.16 row 14.13 — D-134 cluster 1. High-frequency eager
;; collection helpers (Pattern A over reduce/conj/assoc/get/into/apply).
;; ----------------------------------------------------------------

;; `(update m k f & args)` — apply `f` (with trailing `args`) to the
;; value at key `k`. The shallow sibling of `update-in`.
(def update
  (fn* [m k f & args]
    (assoc m k (apply f (into [(get m k)] args)))))

;; `(vec coll)` — eager coerce any collection to a vector.
(def vec
  (fn* [coll] (reduce conj [] coll)))
;; `(vector & args)` — construct a vector from its args (D-134). Unblocks
;; the common `(map vector ks vs)` / `(apply vector …)` idioms.
(def vector
  (fn* [& args] (vec args)))

;; `(mapv f coll)` — eager `map` returning a vector. Single-coll form.
(def mapv
  (fn* ([f coll] (reduce (fn* [acc x] (conj acc (f x))) [] coll))
       ([f c1 c2] (vec (map f c1 c2)))
       ([f c1 c2 c3] (vec (map f c1 c2 c3)))))

;; `(filterv pred coll)` — eager `filter` returning a vector.
(def filterv
  (fn* [pred coll]
    (reduce (fn* [acc x] (if (pred x) (conj acc x) acc)) [] coll)))

;; `(shuffle coll)` — a random permutation of coll as a vector. Fisher-Yates
;; over an immutable vector: for i from n-1 down to 1, swap index i with a
;; random index in [0, i] via two assocs. Placed after `vec` (D-134).
(def shuffle
  (fn* [coll]
    (let [v0 (vec coll)]
      (loop [v v0 i (dec (count v0))]
        (if (< i 1)
          v
          (let [j (rand-int (inc i))]
            (recur (assoc (assoc v i (nth v j)) j (nth v i)) (dec i))))))))

;; `(reverse coll)` — reverse order. conj onto an empty list prepends,
;; so reducing left-to-right yields the reversed sequence (a list).
;; `'()` (quoted) — a bare `()` is rejected as an empty-call expression.
(def reverse
  (fn* [coll] (reduce conj '() coll)))

;; `(last coll)` — the final element, or nil for an empty collection.
(def last
  (fn* [coll] (reduce (fn* [_ x] x) nil coll)))

;; ----------------------------------------------------------------
;; D-134 cluster 2 — eager map/seq helpers (Pattern A).
;; ----------------------------------------------------------------

;; `(reduce-kv f init m)` — reduce over a map's entries, calling
;; `(f acc k v)` for each key. Walks `(keys m)`.
(def reduce-kv
  (fn* [f init m]
    (reduce (fn* [acc k] (f acc k (get m k))) init (keys m))))

;; `(update-keys m f)` — new map with `(f k)` for each key, same vals.
(def update-keys
  (fn* [m f]
    (reduce (fn* [acc k] (assoc acc (f k) (get m k))) {} (keys m))))

;; `(update-vals m f)` — new map with `(f v)` for each val, same keys.
(def update-vals
  (fn* [m f]
    (reduce (fn* [acc k] (assoc acc k (f (get m k)))) {} (keys m))))

;; `(not-any? pred coll)` — true when `pred` is falsey for every item.
(def not-any?
  (fn* [pred coll] (not (some pred coll))))

;; `(not-every? pred coll)` — true when `pred` is falsey for at least one item.
(def not-every?
  (fn* [pred coll] (not (every? pred coll))))

;; D-134 cluster 3 — unblocked by D-136 (universal `=`).

;; `(dedupe coll)` — drop consecutive duplicates (eager vector).
;; `(dedupe)` — the transducer (stateful: remembers the previous input via
;; two volatiles, avoiding a sentinel value that data could collide with).
(def dedupe
  (fn* ([]
        (fn* [rf]
          (let [pv (volatile! nil) seen (volatile! false)]
            (fn* ([] (rf))
                 ([result] (rf result))
                 ([result input]
                  (let [had @seen prior @pv]
                    (vreset! seen true)
                    (vreset! pv input)
                    (if (if had (= prior input) false) result (rf result input))))))))
       ([coll]
        ;; O(n) via the transducer (the old `(last acc)` per step was O(n²)
        ;; — `(dedupe (range 5000))` timed out).
        (into [] (dedupe) coll))))

;; `(distinct coll)` — drop all duplicates, first occurrence wins.
;; Linear `=` scan (structural, so strings/collections dedupe); O(n^2).
(def distinct
  (fn* ([]
        ;; transducer: a volatile set of already-seen inputs
        (fn* [rf]
          (let [seen (volatile! #{})]
            (fn* ([] (rf))
                 ([result] (rf result))
                 ([result input]
                  (if (contains? @seen input)
                    result
                    (do (vswap! seen conj input) (rf result input))))))))
       ([coll]
        ;; O(n) via the transducer's volatile seen-set (the old linear
        ;; `some` scan per element was O(n²) — `(distinct (range 5000))`
        ;; timed out).
        (into [] (distinct) coll))))

;; `(frequencies coll)` — map of item -> occurrence count. Keys via map
;; assoc (bit-pattern keyEq → number/keyword keys; structural keys D-092).
(def frequencies
  (fn* [coll]
    (reduce (fn* [acc x] (assoc acc x (inc (get acc x 0)))) {} coll)))

;; `(group-by f coll)` — map of (f x) -> vector of items. Same key caveat.
(def group-by
  (fn* [f coll]
    (reduce (fn* [acc x] (let [k (f x)] (assoc acc k (conj (get acc k []) x))))
            {}
            coll)))

;; ----------------------------------------------------------------
;; D-134 cluster 4 — eager seq helpers (Pattern A; recursion for
;; zipmap/interleave).
;; ----------------------------------------------------------------

;; `(empty? coll)` — true when coll has no items (nil counts as empty).
(def empty?
  (fn* [coll] (= 0 (count coll))))

;; `(fnil f x)` — f with its first arg defaulted to x when nil.
;; 1-arg patched form (multi-arg fnil awaits multi-arity follow-up).
;; `(fnil f x)` / `(fnil f x y)` / `(fnil f x y z)` — wrap f so its first
;; 1/2/3 args are replaced by the defaults when nil; trailing args pass
;; through (the returned fn is variadic, matching Clojure).
(def fnil
  (fn* ([f x] (fn* [a & args] (apply f (if (nil? a) x a) args)))
       ([f x y] (fn* [a b & args] (apply f (if (nil? a) x a) (if (nil? b) y b) args)))
       ([f x y z] (fn* [a b c & args] (apply f (if (nil? a) x a) (if (nil? b) y b) (if (nil? c) z c) args)))))

;; `(interpose sep coll)` — sep between consecutive items (eager).
;; Prepend sep before each, then drop the leading sep with `rest`.
(def interpose
  (fn* [sep coll]
    (rest (reduce (fn* [acc x] (conj (conj acc sep) x)) [] coll))))

;; `(zipmap ks vs)` — map pairing keys with values, stopping at the
;; shorter. Recursive parallel walk.
;; loop/recur (NOT fn* self-recursion): the original `(assoc (zipmap …) …)`
;; was non-tail and segfaulted at ~5000 pairs. Looping head-first also makes
;; duplicate keys last-wins (Clojure semantics; the old recurse-first was
;; head-wins).
(def zipmap
  (fn* [ks vs]
    (loop [ks (seq ks) vs (seq vs) acc {}]
      (if (and ks vs)
        (recur (next ks) (next vs) (assoc acc (first ks) (first vs)))
        acc))))

;; `(interleave c1 c2)` — alternate items from two colls, stopping at
;; the shorter (eager vector). Two-coll form. loop/recur (NOT fn* self-
;; recursion): the original `(into [x y] (interleave …))` was non-tail and
;; segfaulted at ~1000 elements per coll.
(def interleave
  (fn* [c1 c2]
    (loop [s1 (seq c1) s2 (seq c2) acc []]
      (if (and s1 s2)
        (recur (next s1) (next s2) (conj (conj acc (first s1)) (first s2)))
        acc))))

;; ----------------------------------------------------------------
;; D-134 cluster 5 — reduce-shaped helpers (Pattern A).
;; sort / sort-by deferred (need a compare op + sort algorithm).
;; ----------------------------------------------------------------

;; `(max-key f & xs)` — the x with the greatest (f x); ties keep the
;; earlier-seen. `(min-key …)` is the mirror. reduce uses (first xs)
;; as the seed (≥1 arg required, matching JVM).
(def max-key
  (fn* [f & xs]
    (reduce (fn* [a b] (if (>= (f a) (f b)) a b)) xs)))

(def min-key
  (fn* [f & xs]
    (reduce (fn* [a b] (if (<= (f a) (f b)) a b)) xs)))

;; `(flatten coll)` — recursively splice nested sequentials into one
;; flat eager vector. Non-sequential leaves are kept.
(def flatten
  (fn* [coll]
    (reduce (fn* [acc x] (if (sequential? x) (into acc (flatten x)) (conj acc x)))
            []
            coll)))

;; `(reductions f init coll)` — like reduce but collects every
;; intermediate, starting with init (eager vector). 3-arg form;
;; the 2-arg `(reductions f coll)` awaits multi-arity.
(def reductions
  (fn*
    ([f coll]
      (let [s (seq coll)]
        (if s
          (reductions f (first s) (rest s))
          (vector (f)))))
    ([f init coll]
      (reduce (fn* [acc x] (conj acc (f (last acc) x))) [init] coll))))

;; ----------------------------------------------------------------
;; D-134 cluster 6 — trivial accessors (no compare dependency).
;; sort / sort-by await D-137 (compare is numeric-only).
;; ----------------------------------------------------------------

;; `(second coll)` — the second item (nil if absent).
(def second (fn* [coll] (first (rest coll))))

;; `(ffirst coll)` — `(first (first coll))`.
(def ffirst (fn* [coll] (first (first coll))))

;; `(not-empty coll)` — coll if it has items, else nil.
(def not-empty (fn* [coll] (if (empty? coll) nil coll)))

;; `(take-last n coll)` — the last n items (eager).
(def take-last
  (fn* [n coll] (reverse (take n (reverse coll)))))

;; `(drop-last coll)` — all but the last item. 1-arg form (same body as
;; butlast, inlined to avoid a forward reference); the n-arity
;; `(drop-last n coll)` awaits multi-arity.
(def drop-last (fn* [coll] (reverse (rest (reverse coll)))))

;; ----------------------------------------------------------------
;; D-134 sort cluster — unblocked by D-137 (general compare).
;; STABLE merge sort (ADR-0053 D3: Clojure sort is stable). Eager
;; vector result (DIVERGENCE: JVM returns a seq). cmp returns -1/0/1.
;; ----------------------------------------------------------------

;; Stable merge of two cmp-sorted vectors; on a tie the left item wins
;; (`<=` keeps `a` first), preserving input order.
;; loop/recur (NOT fn* self-recursion): the merge is non-tail when written
;; as `(into [x] (-merge-sorted …))`, so it recursed one frame per element
;; and `(sort (range 5000))` segfaulted. Accumulating into `acc` and
;; recurring is constant-stack; stability holds (`<= 0` drains `a` first).
(def -merge-sorted
  (fn* [cmp a b]
    (loop [a a b b acc []]
      (if (empty? a)
        (into acc b)
        (if (empty? b)
          (into acc a)
          (if (<= (cmp (first a) (first b)) 0)
            (recur (rest a) b (conj acc (first a)))
            (recur a (rest b) (conj acc (first b)))))))))

;; Merge sort over a vector with comparator `cmp`.
(def -msort
  (fn* [cmp v]
    (if (<= (count v) 1)
      v
      (let [mid (quot (count v) 2)]
        (-merge-sorted cmp
                       (-msort cmp (vec (take mid v)))
                       (-msort cmp (vec (drop mid v))))))))

;; Normalize a user comparator (Clojure AFunction.compare semantics, D-159):
;; a Boolean result reads as a less-than predicate (true → -1; else `(cmp b a)`
;; true → 1; else 0); a number passes through (its sign is the order). Lets
;; `(sort < coll)` / `(sort > coll)` work next to numeric comparators, since
;; `-merge-sorted` compares the result with `<= 0`.
(def -comparator
  (fn* [cmp]
    (fn* [a b]
      (let [r (cmp a b)]
        (if (boolean? r)
          (if r -1 (if (cmp b a) 1 0))
          r)))))

;; `(sort coll)` — natural order via `compare`. `(sort comp coll)` — order by
;; the (boolean-or-number) comparator `comp`. Stable (merge sort).
(def sort
  (fn* ([coll] (-msort compare (vec coll)))
       ([comp coll] (-msort (-comparator comp) (vec coll)))))

;; `(sort-by f coll)` — order by `(compare (f a) (f b))`. `(sort-by f comp coll)`
;; — order by `(comp (f a) (f b))`. Stable.
(def sort-by
  (fn* ([f coll]
        (-msort (fn* [a b] (compare (f a) (f b))) (vec coll)))
       ([f comp coll]
        (let [c (-comparator comp)]
          (-msort (fn* [a b] (c (f a) (f b))) (vec coll))))))

;; ----------------------------------------------------------------
;; D-134 range + index fns. The finite arities `(range n)` /
;; `(range start end)` stay eager vectors (a tracked DIVERGENCE: JVM
;; returns lazy seqs — cheap-count consumers like `(count (range n))`
;; keep the eager form until lazy count/nth land). The 0-arg infinite
;; `(range)` IS lazy (ADR-0054 cycle 3) via `(iterate inc 0)`.
;; ----------------------------------------------------------------

;; Accumulate [start..end-1] into a vector (the eager range body).
;; loop/recur (NOT fn* self-recursion) so large ranges don't blow the
;; stack — `(range 100000)` was a segfault when this recursed fn-deep.
(def -range-acc
  (fn* [i n acc]
    (loop [i i acc acc]
      (if (>= i n) acc (recur (inc i) (conj acc i))))))

;; `(iterate f x)` — infinite lazy seq: x, (f x), (f (f x)), …. Defined
;; before `range` because `(range)`'s 0-arg body calls it: cw v1 resolves
;; a fn body's free symbols at analysis time, so a forward ref to a Var
;; def'd later in the file fails to resolve.
(def iterate
  (fn* [f x] (lazy-seq (cons x (iterate f (f x))))))

;; `(range)` → infinite lazy 0,1,2,…; `(range n)` → [0..n-1];
;; `(range start end)` → [start..end-1] (eager vectors). `(range start
;; end step)` → lazy seq; inline lazy recursion (NOT take-while — that is
;; def'd later in the file, and a fn body's free symbols resolve at
;; analysis time). Continuation matches JVM: step>0 while x<end, step<0
;; while x>end, step=0 while x≠end (so `(range 0 10 0)` is infinite 0s,
;; `(range 5 5 0)` is empty).
(def range
  (fn* ([] (iterate inc 0))
       ([n] (-range-acc 0 n []))
       ([start end] (-range-acc start end []))
       ([start end step]
        (lazy-seq
          (if (if (> step 0)
                (< start end)
                (if (< step 0) (> start end) (not (= start end))))
            (cons start (range (+ start step) end step))
            nil)))))

;; ----------------------------------------------------------------
;; D-134 index/accessor cluster. `iterate` is defined above `range` (its
;; 0-arg body resolves it at analysis time); map-indexed / keep-indexed
;; are eager index walks; butlast drops the final element.
;; ----------------------------------------------------------------

;; `(map-indexed f coll)` — eager map passing (index, item) to f.
(def map-indexed
  (fn* ([f]
        ;; transducer arity: stateful index starting at 0
        (fn* [rf]
          (let [iv (volatile! -1)]
            (fn* ([] (rf))
                 ([result] (rf result))
                 ([result input] (rf result (f (vswap! iv inc) input)))))))
       ([f coll]
        (mapv (fn* [i] (f i (nth coll i))) (range (count coll))))))

;; `(keep-indexed f coll)` — like map-indexed but drops nil results.
(def keep-indexed
  (fn* [f coll]
    (reduce (fn* [acc i]
              (let [r (f i (nth coll i))] (if (nil? r) acc (conj acc r))))
            []
            (range (count coll)))))

;; `(butlast coll)` — all but the final element (eager list via reverse).
(def butlast
  (fn* [coll] (reverse (rest (reverse coll)))))

;; ----------------------------------------------------------------
;; ADR-0054 cycle 4 — the last lazy-cluster cycle. repeat / repeatedly /
;; cycle / take-while / drop-while / partition are lazy `.clj`, mirroring
;; the cycle-2/3 lazy-cons shape so they compose with infinite producers
;; (`(take 3 (take-while #(< % 100) (range)))`, `(first (cycle [5 6]))`).
;; ----------------------------------------------------------------

;; `(repeat x)` → infinite lazy x,x,x,…; `(repeat n x)` → n copies (lazy).
(def repeat
  (fn* ([x] (lazy-seq (cons x (repeat x))))
       ([n x] (lazy-seq (if (> n 0) (cons x (repeat (dec n) x)) nil)))))

;; `(repeatedly f)` → infinite lazy (f),(f),…; `(repeatedly n f)` → n calls.
(def repeatedly
  (fn* ([f] (lazy-seq (cons (f) (repeatedly f))))
       ([n f] (take n (repeatedly f)))))

;; `(cycle coll)` → infinite repetition of coll's items; empty → empty.
;; Lazy-catenates one pass of `coll` ahead of the next cycle layer; the
;; trailing `(cycle coll)` is a thunk, so no eager infinite recursion.
(def cycle
  (fn* [coll]
    (lazy-seq
      (let [s (seq coll)]
        (if s
          (-concat2 s (cycle coll))
          nil)))))

;; `(take-while pred coll)` — leading run for which pred is truthy (lazy).
(def take-while
  (fn* [pred coll]
    (lazy-seq
      (let [s (seq coll)]
        (if s
          (if (pred (first s))
            (cons (first s) (take-while pred (rest s)))
            nil)
          nil)))))

;; `(drop-while pred coll)` — drop the leading pred-truthy run, lazy tail.
(def drop-while
  (fn* [pred coll]
    (lazy-seq
      (let [s (seq coll)]
        (if (and s (pred (first s)))
          (drop-while pred (rest s))
          s)))))
;; `(split-with pred coll)` → `[(take-while …) (drop-while …)]`.
(def split-with
  (fn* [pred coll] [(take-while pred coll) (drop-while pred coll)]))
;; `(split-at n coll)` — `[(take n coll) (drop n coll)]`. The pair holds lazy
;; seqs (JVM-faithful); printing the pair directly shows `#<lazy_seq>` per the
;; nested-lazy printer limit (D-134 note / ADR-0054 cycle-2), but the values
;; and destructured/realized use are correct.
(def split-at
  (fn* [n coll] [(take n coll) (drop n coll)]))

;; `(counted? x)` — true iff x supports O(1) count (vector / map / set /
;; list in cw v1). Lazy seqs and strings are NOT counted. `(reversible? x)`
;; — true iff x supports rseq: vector + sorted map/set (LLRB, ADR-0057).
(def counted? (fn* [x] (or (vector? x) (map? x) (set? x) (list? x))))
(def reversible? (fn* [x] (or (vector? x) (sorted? x))))
;; `(take-nth n coll)` — every nth item (lazy).
(def take-nth
  (fn* [n coll]
    (lazy-seq
      (let [s (seq coll)]
        (if s (cons (first s) (take-nth n (drop n s))) nil)))))
;; `(list* a* tail)` — prepend the leading args onto the final seq arg.
;; Explicit 1-4 arg forms (the common cases incl. the `(list* a args)`
;; macro idiom); 5+-arg variadic deferred (needs a primitive-only spread).
(def list*
  (fn* ([args] (seq args))
       ([a args] (cons a args))
       ([a b args] (cons a (cons b args)))
       ([a b c args] (cons a (cons b (cons c args))))))
;; `(partition-by f coll)` — lazy seq of runs where `(f x)` is constant
;; (a new run starts each time `(f x)` changes) (D-134). `run` is a
;; `take-while` lazy_seq (NOT `(cons fst (take-while …))`): a raw cons
;; onto a lazy_seq caches a wrong `count` (D-153), but a lazy_seq counts
;; by realizing — and `(f (first s)) = fv` so the first element is in run.
(def partition-by
  (fn* [f coll]
    (lazy-seq
      (let [s (seq coll)]
        (if s
          (let [fv (f (first s))
                run (take-while (fn* [x] (= (f x) fv)) s)]
            (cons run (partition-by f (drop (count run) s))))
          nil)))))

;; `(partition n coll)` / `(partition n step coll)` — lazy seq of n-item
;; groups stepping by `step` (default n); the final incomplete group is
;; dropped (matches JVM). Each group is an eager `take` list.
(def partition
  (fn* ([n coll] (partition n n coll))
       ([n step coll]
        (lazy-seq
          (let [s (seq coll)]
            (if s
              (let [p (take n s)]
                (if (= (count p) n)
                  (cons p (partition n step (drop step s)))
                  nil))
              nil))))
       ;; 4-arg pad (D-134): the final short partition is padded with
       ;; `pad` up to length n (JVM `(take n (concat p pad))` — if pad is
       ;; too short the last partition stays < n).
       ([n step pad coll]
        (lazy-seq
          (let [s (seq coll)]
            (if s
              (let [p (take n s)]
                (if (= (count p) n)
                  (cons p (partition n step pad (drop step s)))
                  (list (take n (concat p pad)))))
              nil))))))

;; `(partition-all n [step] coll)` — like `partition` but KEEPS the final
;; short partition (no length check, no pad). Lazy (D-134).
(def partition-all
  (fn* ([n]
        ;; transducer: buffer inputs in a volatile vector, emit each full
        ;; partition; the 1-arg completion flushes the short final one.
        (fn* [rf]
          (let [a (volatile! [])]
            (fn* ([] (rf))
                 ([result]
                  (let [result (if (empty? @a)
                                 result
                                 (let [v @a] (vreset! a []) (unreduced (rf result v))))]
                    (rf result)))
                 ([result input]
                  (vswap! a conj input)
                  (if (= n (count @a))
                    (let [v @a] (vreset! a []) (rf result v))
                    result))))))
       ([n coll] (partition-all n n coll))
       ([n step coll]
        (lazy-seq
          (let [s (seq coll)]
            (when s
              (cons (take n s) (partition-all n step (drop step s)))))))))

;; `(splitv-at n coll)` — `[(vec (take n coll)) (vec (drop n coll))]`
;; (the vector-returning sibling of split-with; D-134).
(def splitv-at
  (fn* [n coll] [(vec (take n coll)) (vec (drop n coll))]))

;; ----------------------------------------------------------------
;; Phase 7 §9.9 row 7.7 — hybrid polymorphic primitives' protocol surface.
;;
;; The `count` / `seq` / `conj` / `reduce` primitives keep their
;; Zig Tag-switch fast-path for native tags and route the slow-path
;; (= extend-type targets) through these protocol declarations. The
;; fqcn the slow-path matches in `MethodEntry.protocol_name` is the
;; bare symbol name (no ns prefix, per `allocFqcn` at
;; `lang/primitive/protocol.zig:41-51`), so `"IPersistentCollection"`
;; is the string the dispatch path uses.
;;
;; Methods land one per cycle: cycle 1 adds `-count`; cycles 2-4 add
;; `-seq` / `-cons` / `-reduce` as `seq` / `conj` / `reduce` are
;; wired into their hybrid shape.
;; ----------------------------------------------------------------

(defprotocol IPersistentCollection (-count [c]) (-cons [c x]) (-empty [c]))
(defprotocol Seqable (-seq [c]))
(defprotocol IReduce (-reduce [c f]))
(defprotocol ISeq (-first [s]) (-rest [s]) (-next [s]))
(defprotocol ILookup (-lookup [c k]))
(defprotocol Indexed (-nth [c i]))
(defprotocol Associative (-assoc [c k v]) (-contains-key? [c k]))
(defprotocol IPersistentMap (-without [m k]) (-keys [m]) (-vals [m]))
(defprotocol IPersistentSet (-disjoin [s k]))

;; `(satisfies? protocol x)` — true iff x's type implements protocol.
;; Thin wrapper over the rt/__satisfies? primitive, which consults x's
;; TypeDescriptor (typed_instance / reified_instance / native-Tag
;; default registry) for a method entry naming the protocol.
(def satisfies?
  (fn* [protocol x] (rt/__satisfies? protocol x)))

;; `(memoize f)` returns a cached version of f: each distinct argument
;; tuple computes f once, then returns the stored result. Keys the
;; atom-backed cache by `(vec args)` — vectors compare by value (D-092),
;; and the captured `cache` atom is shared by reference across calls so
;; swap! mutations persist despite snapshot closure capture. Defined at
;; the end of core.clj so `vec` / `contains?` / `get` / `assoc` (earlier
;; defns) are all resolvable (core.clj is analysed top-to-bottom).
(def memoize
  (fn* [f]
    (let* [cache (atom {})]
      (fn* [& args]
        (let* [k (vec args)]
          (if (contains? (deref cache) k)
            (get (deref cache) k)
            (let* [v (apply f args)]
              (do (swap! cache assoc k v) v))))))))

;; `(vary-meta obj f & args)` → obj with metadata `(apply f (meta obj) args)`.
(def vary-meta
  (fn* [obj f & args]
    (with-meta obj (apply f (meta obj) args))))

;; `(re-seq re s)` — seq of successive non-overlapping match strings of `re`
;; in `s` via the `re-find-from` primitive (loop/recur, advancing past each
;; match's end; +1 on an empty match to avoid looping). Capture-group vectors
;; land when groups do (regex cycle 3+).
(def re-seq
  (fn* [re s]
    (loop [pos 0 acc []]
      (let [m (re-find-from re s pos)]
        (if (nil? m)
          (seq acc)
          (recur (if (= (nth m 2) (nth m 1)) (inc (nth m 2)) (nth m 2))
                 (conj acc (nth m 0))))))))

;; ----------------------------------------------------------------
;; Ad-hoc hierarchies — make-hierarchy / derive / underive / isa? /
;; parents / ancestors / descendants over a global hierarchy.
;; DIVERGENCE: cljw has no JVM Class, so clojure.core's class? branches
;; are dropped (keyword / symbol / vector tags only). The global
;; hierarchy is an atom (cljw has no alter-var-root). derive is lenient
;; on namespacing (clojure.core asserts namespaced tags). Map entries are
;; [k v] vectors → nth for key/val.
;; ----------------------------------------------------------------

(def make-hierarchy
  (fn* [] {:parents {} :descendants {} :ancestors {}}))

(def -global-hierarchy (atom (make-hierarchy)))

;; Propagate a target relationship across source and source's sources.
(def -derive-tf
  (fn* [m source sources target targets]
    (reduce (fn* [ret k]
              (assoc ret k (reduce conj (get targets k #{}) (cons target (get targets target)))))
            m (cons source (get sources source)))))

(def derive
  (fn* ([tag parent] (swap! -global-hierarchy derive tag parent) nil)
       ([h tag parent]
        (let [tp (:parents h) td (:descendants h) ta (:ancestors h)]
          (if (contains? (get tp tag) parent)
            h
            (if (contains? (get ta tag) parent)
              (throw (ex-info (str tag " already has " parent " as ancestor") {}))
              (if (contains? (get ta parent) tag)
                (throw (ex-info (str "Cyclic derivation: " parent " has " tag " as ancestor") {}))
                {:parents (assoc tp tag (conj (get tp tag #{}) parent))
                 :ancestors (-derive-tf ta tag td parent ta)
                 :descendants (-derive-tf td parent ta tag td)})))))))

(def isa?
  (fn* ([child parent] (isa? (deref -global-hierarchy) child parent))
       ([h child parent]
        (or (= child parent)
            (contains? (get (:ancestors h) child) parent)
            (and (vector? parent) (vector? child)
                 (= (count parent) (count child))
                 (loop [ret true i 0]
                   (if (or (not ret) (= i (count parent)))
                     ret
                     (recur (isa? h (nth child i) (nth parent i)) (inc i)))))))))

(def parents
  (fn* ([tag] (parents (deref -global-hierarchy) tag))
       ([h tag] (not-empty (get (:parents h) tag)))))

(def ancestors
  (fn* ([tag] (ancestors (deref -global-hierarchy) tag))
       ([h tag] (not-empty (get (:ancestors h) tag)))))

(def descendants
  (fn* ([tag] (descendants (deref -global-hierarchy) tag))
       ([h tag] (not-empty (get (:descendants h) tag)))))

(def underive
  (fn* ([tag parent] (swap! -global-hierarchy underive tag parent) nil)
       ([h tag parent]
        (let [pm (:parents h)
              cps (if (get pm tag) (disj (get pm tag) parent) #{})
              new-parents (if (not-empty cps) (assoc pm tag cps) (dissoc pm tag))
              deriv-seq (flatten (map (fn* [e] (cons (nth e 0) (interpose (nth e 0) (nth e 1))))
                                      (seq new-parents)))]
          (if (contains? (get pm tag) parent)
            (reduce (fn* [hh pr] (derive hh (nth pr 0) (nth pr 1)))
                    (make-hierarchy) (partition 2 deriv-seq))
            h)))))

