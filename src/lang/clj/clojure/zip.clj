;; clojure.zip — Phase 7 §9.9 row 7.13 / D-080 / ADR-0043.
;;
;; Functional zipper over hierarchical data. cw v1 ports JVM
;; clojure.zip's public API but uses a `defrecord ZipLoc` carrier
;; rather than JVM's vector-with-metadata shape — see ADR-0043 for
;; the representation rationale. defrecord sidesteps the D-075
;; with-meta / IObj / IMeta hard dependency.
;;
;; Forward commitment: the defrecord shape is the **permanent
;; finished form** of cw v1's zipper. D-075 landing does NOT
;; trigger a JVM-faithful migration (per ADR-0043 amendment A).
;;
;; ## Cycle 1 — representation + ctors + 16 leaves (this commit)
;;
;; - `(defrecord ZipLoc ...)` + `->ZipLoc` factory.
;; - `zipper` / `vector-zip` / `seq-zip` / `xml-zip` constructors.
;; - `node` / `branch?` / `children` / `make-node` leaf accessors.
;; - `zip-loc?` / `seq-zip?` / `vector-zip?` / `xml-zip?` predicates.
;;
;; Cycles 2-4 land navigation / traversal / mutation.

(ns clojure.zip (:refer-clojure))

;; ZipLoc field layout (per ADR-0043 Decision section, expanded to
;; carry the zipper-type fns directly so the generic `(zipper)`
;; constructor works for user-defined tree shapes):
;;
;; - node         current node value.
;; - path         parent ZipLoc or nil at root.
;; - lefts        vector of sibling nodes to the left of `node`.
;; - rights       vector of sibling nodes to the right of `node`.
;; - end?         boolean — set by `(next loc)` once depth-first
;;                walk exhausts (cycle 3 wires this).
;; - branch-fn    predicate: is the current node a branch?
;; - children-fn  fn: branch node → seq of children.
;; - make-node-fn fn: (node, children-seq) → new branch node.
;; - kind         keyword `:zipper` / `:vector` / `:seq` / `:xml`
;;                — drives the source-shape predicates without
;;                comparing fn identity.
(defrecord ZipLoc [node path lefts rights end?
                   branch-fn children-fn make-node-fn kind])

;; ----------------------------------------------------------------
;; Constructors
;; ----------------------------------------------------------------

;; `(zipper branch? children make-node root)` — generic constructor.
;; Returns a fresh root ZipLoc. The 3 fns define the tree shape:
;; branch? recognises branch nodes; children returns a seq of a
;; branch's children; make-node rebuilds a branch given (node,
;; new-children-seq).
(defn zipper [b c m root]
  (->ZipLoc root nil [] [] false b c m :zipper))

;; `(vector-zip root)` — zipper over Clojure vectors (every vector
;; is a branch; children are its elements; rebuilding rewraps as
;; vector via `vec`).
(defn vector-zip [root]
  (->ZipLoc root nil [] [] false
            vector?
            (fn* [n] (seq n))
            (fn* [_node children] (into [] children))
            :vector))

;; `(seq-zip root)` — zipper over Clojure seqs (lists / cons /
;; lazy-seqs). Every seq is a branch; children pass through;
;; rebuilding is identity-on-children since children are already
;; a seq.
(defn seq-zip [root]
  (->ZipLoc root nil [] [] false
            seq?
            identity
            (fn* [_node children] children)
            :seq))

;; `(xml-zip root)` — zipper over Clojure XML element maps
;; (`{:tag :foo :attrs {} :content [...]}`-shaped). A node is a
;; branch when it is a map (= XML element); children come from
;; the `:content` key; rebuild keeps the rest of the map and
;; replaces `:content` with the new children vector.
;;
;; cw v1 uses `(get node :content)` rather than `(:content node)`
;; because D-085 keyword-as-fn callable is not yet landed
;; (ADR-0043 §Substrate verification). Once D-085 lands, the
;; `(get …)` calls can opportunistically flip to `(:content …)`
;; for ergonomic uniformity.
(defn xml-zip [root]
  (->ZipLoc root nil [] [] false
            (fn* [n] (map? n))
            (fn* [n] (get n :content))
            (fn* [n cs] (assoc n :content (into [] cs)))
            :xml))

;; ----------------------------------------------------------------
;; Leaf accessors — `node` / `branch?` / `children` / `make-node`
;; ----------------------------------------------------------------

(defn node [loc] (.node loc))

(defn branch? [loc] ((.branch-fn loc) (.node loc)))

(defn children [loc]
  (if (branch? loc)
    ((.children-fn loc) (.node loc))
    nil))

(defn make-node [loc nd cs] ((.make-node-fn loc) nd cs))

;; ----------------------------------------------------------------
;; Predicates
;; ----------------------------------------------------------------

(defn zip-loc?    [x] (instance? ZipLoc x))
;; The predicates use explicit `if` rather than `(and ...)` because
;; the bootstrap `and` macro (expandAnd) returns the FIRST falsy
;; operand's value rather than `false` per Clojure semantics, which
;; surfaces as a subtle bug when the false-arm caller compares to
;; the literal `false` Value. Explicit `if` is unambiguous + cheaper.
(defn vector-zip? [x]
  (if (instance? ZipLoc x) (identical? :vector (.kind x)) false))
(defn seq-zip? [x]
  (if (instance? ZipLoc x) (identical? :seq (.kind x)) false))
(defn xml-zip? [x]
  (if (instance? ZipLoc x) (identical? :xml (.kind x)) false))

;; ----------------------------------------------------------------
;; Row 7.13 cycle 2 — navigation (10 vars)
;; ----------------------------------------------------------------

;; Internal helper: rebuild a ZipLoc with overridden fields, copying
;; the others from `src`. cw v1 lacks `assoc` on defrecord today
;; (the typed_instance field-set surface is row 7.4+ deferred work
;; per D-086 `__extmap`); use the `->ZipLoc` factory explicitly.
;;
;; NOTE: would be `^:private` per JVM convention but cw v1's defn
;; macro does not yet parse the metadata-map reader form (D-091).
;; The name prefix `with-` + `-loc` suffix marks intent; future
;; D-091 discharge can flip to `^:private` non-breakingly.
(defn with-loc-internal
  [src nd path lefts rights end?]
  (->ZipLoc nd path lefts rights end?
            (.branch-fn src)
            (.children-fn src)
            (.make-node-fn src)
            (.kind src)))

;; `(lefts loc)` / `(rights loc)` / `(path loc)` — raw field reads
;; matching JVM clojure.zip's public accessors. `path` returns the
;; vector of node values walked from root down to (but not
;; including) `(node loc)`; cw v1's ZipLoc encodes this as a parent
;; ZipLoc chain rather than a vector, so `(path)` walks the chain
;; building the vector on demand.
(defn lefts  [loc] (.lefts loc))
(defn rights [loc] (.rights loc))

(defn path [loc]
  (loop* [p (.path loc) acc nil]
    (if (nil? p)
      (into [] acc)
      (recur (.path p) (cons (.node p) acc)))))

;; `(down loc)` — descend into the first child of a branch.
;; Returns nil if `loc` is not a branch or has no children.
;; The new loc's `.path` references `loc` (the parent); `.lefts`
;; starts empty; `.rights` = rest of the children.
(defn down [loc]
  (if (branch? loc)
    (let* [cs (children loc)]
      (if (nil? cs)
        nil
        (if (nil? (seq cs))
          nil
          (->ZipLoc (first cs)
                    loc
                    []
                    (into [] (rest cs))
                    false
                    (.branch-fn loc)
                    (.children-fn loc)
                    (.make-node-fn loc)
                    (.kind loc)))))
    nil))

;; `(up loc)` — ascend to the parent. Rebuilds the parent's node
;; via `make-node`, splicing the current node back into the parent's
;; children at position `(count (.lefts loc))`. Returns nil at root.
(defn up [loc]
  (let* [p (.path loc)]
    (if (nil? p)
      nil
      (let* [new-children (into (into (.lefts loc) [(.node loc)]) (.rights loc))
             new-node ((.make-node-fn loc) (.node p) new-children)]
        (with-loc-internal p new-node (.path p) (.lefts p) (.rights p) (.end? p))))))

;; `(root loc)` — repeatedly `(up)` until at the root, return the
;; root's node value (NOT a loc). JVM semantics — the value
;; reconstruction terminates at the topmost ZipLoc and yields its
;; `.node`.
(defn root [loc]
  (loop* [l loc]
    (if (nil? (.path l))
      (.node l)
      (recur (up l)))))

;; `(right loc)` — sibling step right. Reads `(.rights loc)` for
;; the next sibling; updates lefts / rights / node. Returns nil
;; if at the rightmost sibling.
(defn right [loc]
  (let* [rs (.rights loc)]
    (if (nil? (seq rs))
      nil
      (with-loc-internal loc
                (first rs)
                (.path loc)
                (into (.lefts loc) [(.node loc)])
                (into [] (rest rs))
                false))))

;; `(left loc)` — sibling step left. Symmetric to `right` but
;; harvests the last `.lefts` element. Returns nil at leftmost.
(defn left [loc]
  (let* [ls (.lefts loc)]
    (if (nil? (seq ls))
      nil
      (let* [n (count ls)
             new-current (nth ls (- n 1))
             new-lefts (into [] (take (- n 1) ls))
             new-rights (into [(.node loc)] (.rights loc))]
        (with-loc-internal loc new-current (.path loc) new-lefts new-rights false)))))

;; `(leftmost loc)` / `(rightmost loc)` — jump to the edge sibling
;; without walking step-by-step. JVM semantics.
(defn leftmost [loc]
  (let* [ls (.lefts loc)]
    (if (nil? (seq ls))
      loc
      (with-loc-internal loc
                (first ls)
                (.path loc)
                []
                (into (into [] (rest ls)) (into [(.node loc)] (.rights loc)))
                false))))

(defn rightmost [loc]
  (let* [rs (.rights loc)]
    (if (nil? (seq rs))
      loc
      (let* [all (into (into (.lefts loc) [(.node loc)]) rs)
             n (count all)
             new-current (nth all (- n 1))
             new-lefts (into [] (take (- n 1) all))]
        (with-loc-internal loc new-current (.path loc) new-lefts [] false)))))
