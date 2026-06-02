# clj-diff sweep coverage ledger (tracked)

Resume-time SSOT for "what the F-011 differential sweep has covered and what
to sweep next". Promoted to git from the gitignored running ledger
`private/notes/phaseA26-clj-differential-oracle.md` so a clean session's
`/continue` reaches it without depending on scratch. Run the sweep with
`scripts/clj_diff_sweep.sh` (see `.claude/rules/clj_diff_sweep.md`); land
confirmed exprs into a `*.txt` corpus here via `--corpus`.

## Swept & at parity (don't re-sweep wholesale)

- **Numeric tower** — `bigint`/`bigdec` constructors (int/BigInt/ratio/string/
  scientific/large-float), bigdec `+ - * / quot rem mod` contagion incl.
  float→f64, ratio terminating-decimal + ArithmeticException. (D-191/D-194
  discharged.)
- **Integer/Long bit + Math `*Exact`** — bitCount/clz/ctz/highestOneBit/reverse;
  addExact/multiplyExact/… (D-172). Remaining low-value: see Next.
- **Coercion tower (`quot`/`rem`/`mod` + `int`/`long`/`num`/`double`/`float`/
  `numerator`/`denominator`/`rationalize`)** — all at parity over int/float/
  ratio/BigInt operands incl. truncation (`(int 3.7)`→3), `(num 1/2)`→ratio,
  `(rationalize 0.1)`→`1/10`, `(int \A)`→65. Corpus `coerce_tower` (27 exprs).
  Acceptable error-class divergences (both reject, see below): `(numerator 5)`,
  `(quot 10 0)`, `(mod 10 0)`.
- **Numeric coercion / parity** — `even?`/`odd?` over BigInt (incl. negative,
  zero, ≥2^64), plus **oversized integer-literal auto-promote**: a bare decimal
  literal too large for i64 now reads as BigInt (clj `…N`) instead of erroring,
  matching `(= 99…99 99…99N)`. Gap found+fixed: `even?`/`odd?` rejected `.big_int`
  (doc claimed a BigInt arm that was never wired) — now via `parity` helper
  (Long bottom-bit + BigInt least-significant-limb). Corpus `num_coerce`. (`*`
  overflow→`…N` vs clj ArithmeticException is F-005-intentional; large-Long→`…N`
  is D-165, both excluded from the corpus.) Residual: a **radix-prefixed**
  overflow (`0xFFFFFFFFFFFFFFFFFF`) still errors where clj promotes to BigInt —
  rare; `parseBase10` is base-10-only and the base-N setString path carries the
  D-047 Linux hazard, so deferred.
- **String / regex** — clojure.string surface, `format` conversion+flag family,
  re-find/re-matches/re-seq + capturing groups + `$N`/fn replace; regex prints
  `#"src"` (pr) / raw (str).
- **`format` conversions (deep)** — `%s`/`%d`(+grouping/sign/paren flags)/`%x`/
  `%X`/`%o`/`%f`(.prec)/`%e`/`%E`/`%g`/`%G` + width/`-`/`0`-pad/`%%`/`%n`, plus
  newly landed **`%b`/`%B`** (logical-truth → true/false, nil→false) and **`%c`**
  (char → UTF-8; a non-char arg like a Long errors, matching clj's
  IllegalFormatConversionException). Corpus `format_conv` (15). **Positional
  arg index `%N$s`** also landed (`(format "%2$s %1$s" "a" "b")`→"b a"; combines
  with flags/width as `%2$05d`; the `N$` lookahead is non-destructive so a
  `%05d` width-`0` flag is unaffected). Corpus `format_positional` (6).
- **Sequence / collection** — partition/interleave/reductions/mapcat/frequencies/
  group-by/dedupe/distinct/flatten/tree-seq/zipmap/merge-with/sort/sort-by/
  min-key/max-key/update(-in)/assoc-in/get-in (2+3-arity)/reduce-kv/juxt/comp/
  partial/subvec/replace/peek/pop/rseq/nthrest/take-last/drop-last (1+2-arity).
- **Transducer 1-arg (xform) arities** — map/filter/take/drop/keep/remove/
  map-indexed/keep-indexed/replace/take-while/drop-while/take-nth/partition-by/
  partition-all/dedupe/distinct/interpose/cat/mapcat (D-177 over-claim corrected).
- **Predicates** — number?/integer?/rational?/float?/double?/decimal?/ratio?/
  pos-int?/seqable?/coll?/associative?/indexed?/ident?/{simple,qualified}-
  {ident,keyword,symbol}?.
- **JSON (data.json)** — read/write number parity incl. BigInt both directions
  (D-182). `:bigdec` opt + ratio write are minor residuals.
- **functions as values / HOF** — set/map/keyword/vector as fn (+ not-found),
  fnil/complement/every-pred/constantly/comp/partial/juxt, keyword-in-map/filter,
  keep-with-set, remove-with-set, group-by. Gap found+fixed: `some-fn` returned
  `nil` when no pred matched; clj returns the LAST pred's value (`(or …)`
  semantics: `((some-fn neg? even?) 3)`→false not nil). Corpus `fn_as_value`.
- **sequence fns (lazy tail)** — iterate/cycle/repeat/repeatedly/lazy-cat/
  split-at/split-with/butlast/take-while/nthrest/partition-all/keep/mapcat/
  reductions/range-step, infinite-bounded-by-take. Gap found+fixed:
  `interleave` was EAGER (returned empty for two infinite colls) — rewritten
  LAZY (JVM parity): `(take 4 (interleave (range) (repeat :x)))`→`(0 :x 1 :x)`;
  finite/uneven/1-arity preserved (0-arity → nil per D-164). Corpus `seq_tail`.
- **atom / swap! family** — atom/deref, swap! (fn / +args / update), reset!,
  compare-and-set! (hit + miss), swap-vals!/reset-vals! ([old new]), swap-over-
  collection, dotimes-swap, reset-then-swap — all at parity. Corpus `atom_swap`.
  (Watch family `add-watch`/`remove-watch` is Phase-15-deferred, D-157.)
- **clojure.string deeper edges** — split (limit + regex), replace
  (literal-string / regex / `$N` capture / fn), replace-first, includes?/
  starts-with?/ends-with?, blank?(+nil), triml/trimr, capitalize, join,
  split-lines, no-match replace. Gap found+fixed: `index-of`/`last-index-of`
  3-arity `from-index` (`(index-of s sub from)`→4, `(last-index-of s sub from)`
  = last start ≤ from) — both the primitive + the string.clj wrapper went
  variadic. Corpus `string_deep`. Gap found+fixed: **`re-quote-replacement`**
  was unimplemented (name_error) — now a pure-Clojure escape of `\`→`\\` +
  `$`→`\$` over `replace` (string-literal match), so it works as the
  replacement in a regex `replace` (`(replace "abc" #"b" (re-quote-replacement
  "$X"))`). Corpus `string_misc` (also covers split-lines/reverse/replace-first/
  subs/name/namespace/keyword·symbol 2-arity + reduce-kv/group-by/take-nth/
  partition-all/keep/mapcat/vary-meta — all at parity).
- **exception / ex-info family** — `ex-info`/`ex-data`/`ex-message`, `ex-data`
  on non-ex→nil, `try`/`catch <Class>` (ExceptionInfo/Exception/Arithmetic/
  IndexOutOfBounds/AssertionError/Throwable)/`finally`, nested ex-data,
  `instance? ExceptionInfo` — the cljw-native error API at parity (16/18).
  Corpus `exception_api`. **`.getMessage`/`.getCause`/`.getData` LANDED**
  (D-198 partial): Java-interop read accessors on a caught/ex-info exception
  resolve via `.ex_info` native methods (Throwable.zig) — `(.getMessage e)` /
  `(:k (.getData e))` in catch bodies at parity on both backends, incl. a
  caught catalog error (`(/ 1 0)`). Corpus `host_exception` (6). **Remaining
  gap (D-198/D-048)**: `(Exception. msg)` host-class CONSTRUCTORS still
  `name_error` — use ex-info to mint exceptions (the native path).
- **vector / associative ops** — subvec (2+3-arity, empty), mapv/filterv,
  into (coll/xform/set/map), assoc (set + append-at-count), update (+args),
  get/nth (not-found), peek/pop, assoc-in/update-in/get-in (deep + not-found),
  replace, reduce-kv, into-sorted-map — all at parity (no gaps). Corpus
  `vec_assoc_ops`.
- **transients (mutation round-trip only)** — `transient`/`persistent!`
  round-trip (vector/map/set), `conj!`/`pop!`/`disj!`/`dissoc!`, `reduce conj!`,
  `reduce assoc!` at parity. Gap found+fixed: `assoc!` was 3-arity only — now
  `(assoc! t k1 v1 k2 v2 …)` multi-pair. `conj!` is single-element in BOTH
  (multi-arg → ArityException, F-011 class match). Corpus `transients`.
- **transients (read/query ops)** — `count`/`get`/`contains?`/`nth` on a live
  transient + `assoc!` on a transient *vector* (index-assign / append) now at
  parity across all 3 transient tags incl. hash-mode maps (>8 entries). clj
  treats a transient as a first-class read target; cljw now matches (was
  `type_error` / nil — D-199). Read accessors on
  `transient_{vector,array_map,hash_set}.zig` + the `.transient_*` arms wired
  into `count`/`get`/`contains?`/`nth`/`assoc!`. Corpus `transient_read` (21).
- **seq-return type class** — sort/sort-by/keys/vals/reverse/rest/next/seq/map/
  filter/distinct/take/drop/concat/remove/map-indexed/interpose/partition/
  flatten all return SEQS matching clj (NOT vectors — the feared sort-returns-
  vector class was a non-issue; only zip lefts/rights diverged, now fixed). Gap
  found+fixed: `array-map` constructor was unregistered (`name_error`) — now
  registered (cljw maps are array-backed ≤8, so array-map ≡ hash-map output for
  the small-map surface). Corpus `seq_return`.
- **clojure.zip** — vector-zip nav (down/up/right/left/next/node/root/edit/
  branch?/children/end?/append-child/insert-child) at parity. Gap found+fixed:
  `lefts`/`rights` returned the raw vector field; JVM returns a SEQ (`(1)` not
  `[1]`, empty→nil) — public fns now wrap `(seq …)` (internal nav still reads
  the vector fields). Corpus `zip`.
- **clojure.data/diff** (new ns) — recursive `[only-a only-b both]` over
  atom/map/set/sequential + nested, equal-shortcut, nil, growth. Pattern-A
  re-derivation over cljw predicates (no Java-interface protocols). Surfaced
  + fixed an independent bug: `(contains? vec i)` raised type_error — it now
  tests index validity (`true`/`false`, non-integer→false) per clj. Corpus
  `data_diff`.
- **destructuring** — vector `[a b & r :as all]` + missing→nil, map
  `:keys`/`:strs`/`:syms`/`{a :a}`/`:or`/`:as`, nested vector+map, fn-param +
  loop destructure, destructure on nil, **kwargs `& {:keys […]}`**. All at
  parity (D-076 surface). Gap found+fixed: **namespaced `:keys` entries**
  (`{:keys [a/b]}` binds local `b` to key `:a/b`; same for `:syms [m/n]` →
  `'m/n`) were rejected ("must be plain symbols") — now the entry's name part
  is the local and the namespace rides the key (clj parity). Corpus
  `destructuring`.
- **clojure.edn/read-string** — vector/map/set/list/string/keyword/ratio/
  bigint/bigdec/float/bool/nil/neg/nested/quote literals + pr-str round-trip
  all at parity (only set print order + `(class)`→`Long` diverge, both
  acceptable). Corpus `edn_readstring`. Tagged-literal reader infra + the
  2-arity `[opts s]` (`:readers`/`:default`/`:eof`) landed (ADR-0073); `#uuid`
  is a real value (ADR-0074); `tagged-literal`/`tagged-literal?` (ADR-0075).
  Only `#inst`/Date remains (structurally-deferred, D-200 row).
- **metadata (with-meta / vary-meta)** — meta read/attach on vector/map/list/
  set/seq, vary-meta assoc/update/multi-key/fn, nested re-wrap, `(with-meta x
  nil)`, meta-doesn't-affect-`=`, meta not printed. All at parity (no gaps).
  Corpus `metadata`. (`alter-meta!` on vars depends on var-metadata D-183.)
- **multimethod / hierarchy** — defmulti/defmethod dispatch, `:default`,
  custom dispatch fn, vector dispatch val, re-defmethod override; `derive` /
  `isa?` / `parents` / `ancestors` / `descendants` / `prefer-method`; gap
  found+fixed: `methods` / `get-method` / `remove-method` / `prefers` had no
  public wrapper over the rt/ primitives. no-match throws IllegalArgumentException
  (catchable; message format differs per F-011). Corpus `multimethod`.
- **`::` auto-resolved keyword** (D-195 discharged) — `::name`→current-ns,
  `::alias/name`→require-alias target ns; `(name ::foo)`/`(namespace ::foo)`/
  print/`=`/map-literal keys/multimethod `::` dispatch all at parity. Corpus
  `auto_keyword`. Residual: quoted `'::foo` interns `:foo` (formToValue has no
  env).
- **reduce / reduced / transduce** — reduce init/no-init/empty/nil, early
  `reduced`/`reduced?`/`unreduced`/`ensure-reduced`/`@reduced`, reduce-kv,
  reduce over map(entry)/set/string/range, transduce + xform compose. All at
  parity. Gap found+fixed: `key`/`val` were undefined (map entry = 2-vector →
  `(nth e 0/1)`). Corpus `reduce_reduced`.
- **Collections as keys / set elements** (D-092 discharged) — map / set / list
  AND cross-type vector≡list hash + compare by content (`(get {{:a 1} :x} {:a 1})`,
  `(get {[1 2] :v} '(1 2))`, set/`distinct`/`frequencies` dedup of collections,
  `clojure.set/index`/`join` map-key merge). `(hash coll)` is content-based +
  order-independent for maps/sets. Corpus `collection_keys`. Lazy/range keys
  stay identity (rt-free residual).
- **threading / conditional macros** — `->`/`->>`/`some->`/`some->>`/`cond->`/
  `cond->>`/`as->`/`doto` + `when-let`/`if-some`/`when-some` all at parity
  (nil short-circuit, predicate gating, binding shadowing). Corpus `threading`
  (14). Only DIFF: `(doto (atom …) …)` returns the atom whose print form is
  `#<atom>` vs clj's `#object[clojure.lang.Atom 0xADDR {…}]` — an acceptable
  print divergence (clj embeds a non-reproducible identity hash).
- **delay / for-modifiers / lazy** — `for` with `:when`/`:let`/`:while` (+
  multi-binding), nested `doseq`, `memoize`, `iterate`/`cycle`/`reductions`/
  `take-while`. Gaps found+fixed: **`force`** + **`delay?`** were unwired (the
  `.delay` type + `delay` macro + deref-forces + `realized?`-on-delay already
  existed — only the user-facing `force`/`delay?` fns were missing); and
  **`realized?` on a lazy-seq** raised "non-IPending" (added the `.lazy_seq`
  arm via `lazy_seq.isRealised`, the `realized_flag` discriminator). Corpus
  `lazy_eval` (15).
- **assoc-path + merge** — `assoc-in`/`update-in`/`get-in` (deep create +
  missing-path default) over maps AND vectors, `update`(+fnil)/`merge`(+nil)/
  `merge-with`/`select-keys`/`dissoc`(multi)/`reduce-kv`/`zipmap`/`frequencies`
  all at parity. Corpus `coll_path` (20).
- **bit-ops + Math + static fields** — `bit-test`/`bit-set`/`bit-clear`/
  `bit-flip`/`bit-and-not`; `Math/sqrt`/`pow`/`abs`/`floor`/`ceil`/`round`/
  `max`/`min`/`log`/`exp`/`signum`/`floorDiv`/`floorMod` (static methods); bare
  static FIELDS `Math/PI`/`Math/E`/`Integer/MAX_VALUE`·`MIN_VALUE`/`Long/MAX_VALUE`
  ·`MIN_VALUE` resolve + compose (`(* 2 Math/PI)`). Corpus `bit_math` (27).
  Edges: `(Math/PI)` (a static field in CALL position) — clj's compiler returns
  the field, cljw tries to call it ("Cannot call float"); rare (write `Math/PI`,
  not `(Math/PI)`). `Long/MAX_VALUE` prints `…N` (D-165 i48→i64, value-exact).
- **control-flow macros** — `case` (literal/keyword/char/string/list-of-keys
  test sets + default), `condp` (with `=`/`<`/`get` pred + `:else`), `loop`/
  `recur`, `for` (single + nested seq comprehension), `dotimes`, `cond` all at
  parity. Corpus `control_flow` (14). Gap (D-201, tracked): **`letfn`**
  unimplemented (needs a `letfn*` mutual-recursion special form — not
  expressible as a plain sequential `let*`).
- **print / pr-str representation** — `pr-str` (readable: strings quoted +
  `\n`/`\t`/`\"`/`\\` escaped, chars `\newline`/`\space`/`\a`, ratios `1/3`,
  keywords `:foo/bar`, nested vec/map/list/seq) vs `str`/`print-str`
  (human-readable: strings + chars bare). Gap found+fixed: **`print-str`** was
  unimplemented (name_error) — added as the `readable=false` peer of `pr-str`
  (space-separated, unquoted). Corpus `print_repr` (25).
- **sorted collections + clojure.set** — `sorted-map`/`sorted-set` (ordered
  keys/seq/first/get/keys/conj/disj/contains?), `subseq`/`rsubseq` (range
  scans), `into (sorted-map) …`, + `clojure.set` union/intersection/difference/
  subset?/superset?/select/rename-keys/map-invert all at parity by VALUE.
  Corpus `sorted_coll` (17). The only DIFFs are non-sorted hash-set print
  order (`#{2 3}` vs `#{3 2}`) — the documented acceptable divergence, not a
  bug (sorted colls print in order, so they match exactly).

## Next-sweep candidates (gap-confirmed or unswept)

- **Low-value bit ops** (unswept, low call-frequency): Integer/Long
  `lowestOneBit`/`reverseBytes`/`rotateLeft`(2-arg)/`rotateRight`(2-arg)/`signum`.
- **`clojure.set` / `clojure.walk`** — swept 2026-06-02 (§A26): union/intersection/
  difference/subset?/superset?/select/project/rename/rename-keys/map-invert/index/
  join + prewalk/postwalk/*-replace/keywordize-keys/stringify-keys/walk all at
  parity (only set print order + the now-fixed collection-key bug diverged).
  Residual: `intersection`/`difference` 0-arity (cljw variadic returns nil; JVM has
  no 0-arity → ArityException) — low-value edge; `macroexpand-all` is a stub.
- **Transient read/query ops** — CLOSED 2026-06-02 (D-199); see Swept areas.
- **polymorphism gaps** (D-202) — `defmulti :default` option LANDED 2026-06-02
  (expandDefmulti parses `:default`/`:hierarchy`; 1 diff_test). REMAINING:
  defrecord/deftype bare-field refs in protocol method bodies + `extend-type`
  on a java class (Long/String). Basics (defmulti/defmethod, defprotocol/
  defrecord/deftype w/ explicit field access, satisfies?, extend-type on cljw
  types) all work. NOTE: NOT sweep-verifiable — clj requires these forms
  top-level; the `(prn …)` batch wrap errors in clj. Verify via individual
  top-level `clj -M -e` or e2e files.
- **`letfn`** (D-201) — mutual-recursion local fns; needs a `letfn*` analyzer
  special form (pre-bind all names) + dual-backend arms. Not a plain `let*`
  macro (cljw `let*` is sequential, no forward-ref).
- **Unswept areas** worth a focused pass: EDN tagged literals
  (`#inst`/`#uuid`/custom `:readers`), `alter-meta!` (needs var-metadata
  D-183), `clojure.walk/macroexpand-all` (stub), `clojure.string` deeper edges,
  transients (`transient`/`conj!`/`persistent!`), `clojure.core.async`-free
  concurrency primitives.
- **`random-sample`** — undefined (1-arg transducer + 2-arg; non-deterministic).
- **Remaining Java interop** (structural-deferred, array/regex repr):
  `.split`/`.toCharArray`/`.getBytes` (needs F-004 Group-D `array` slot);
  `.replaceAll`/`.matches` (Pattern surface).

## Acceptable divergences (NOT bugs — do not "fix")

- Set / non-sorted-map **print order** differs from clj hash order.
- **Opaque-object print form**: an atom prints `#<atom>` vs clj's
  `#object[clojure.lang.Atom 0xADDR {:status :ready, :val N}]` — clj embeds a
  non-reproducible identity hash, so exact parity is neither possible nor
  desirable (same class as `#object[…]` for any opaque ref type).
- `(class 5)` → `Long` not `java.lang.Long` (ADR-0059 no-JVM rule); `(type …)` too.
- `(float 1/3)` is f64 (cljw has no f32).
- Subnormal `5.0E-324` vs JVM `4.9E-324` (same double).
- `Double/parseDouble` lower-case `inf`/`nan` + trailing `d`/`f` + hex-float —
  full Java FloatingDecimal grammar not reimplemented (rare edge).
- **Error class name** on a rejected operation: cljw renders its own catalog
  Kind (`[type_error]` / `[arithmetic_error]`) where clj prints the JVM
  exception class (`ClassCastException` / `ArithmeticException`). Both correctly
  reject — e.g. `(numerator 5)`, `(quot 10 0)`, `(mod 10 0)`. ADR-0059 no-JVM.
- **clojure.set** — `union`/`intersection`/`difference` (0..3-arity + empty),
  `subset?`/`superset?`, `select`, `map-invert`, `rename-keys`, `project`,
  `rename`, `index`, `join` all at parity. Corpus `clojure_set` (23 golden).
  The only DIFFs are **set print order** (`#{1 2 3}` vs `#{1 3 2}`) on the
  set-returning ops — the known non-bug (clj_diff_sweep.md), so those lines are
  verified-at-parity-modulo-order but intentionally NOT in the regression
  corpus (the deterministic-output ops are).
- **numeric heap keys** (D-205 BigInt+Ratio) — `BigInt`/`Ratio` as map keys /
  set elements / `distinct` dedup / `zipmap`, incl. cross-representation
  `(get {1 :v} 1N)`→`:v` (Long≡BigInt hash normalization) + a `>2^63` BigInt
  key (limb-hash path). Corpus `numeric_keys` (13). Fix: `keyEqValue` numeric
  arm (reuses `intEqual`; Ratio by reduced numer/denom) + value-based
  `valueHash` arms (`managedHash`). **BigDecimal keys are a tracked residual**
  (D-205): cljw's `(= 1.5M 1.50M)`→true is numeric/rt-aware, unmatchable by a
  rt-free key compare — needs a separate bigdecimal-`=` scale-sensitivity
  decision. `(hash 1.5M)` is now deterministic regardless.
- **clojure.walk** — `postwalk`/`prewalk` (identity + transform fns over
  nested map/vector/list/set), `walk` (inner+outer), `keywordize-keys` /
  `stringify-keys` (nested + mixed), `prewalk-replace` / `postwalk-replace`
  (incl. a vector key) all at parity. Corpus `clojure_walk` (19 golden); the
  only DIFF is the same set print-order non-bug.

## Structural-deferred (F-003 — big-bang, do NOT seize incrementally)

- **D-164** — `()` vs `nil` empty-seq unification (the single highest-leverage
  parity fix; collapses a whole class of diffs). `()` literal currently lowers
  to nil; empty lazy_seq prints `nil`; `rest`/`drop` collapse to nil.
- **D-165** — i48→i64 long print (`(2^47, 2^63]` long → BigInt `…N`); value-exact,
  print + `(class)` only. F-004 NaN-box payload consequence.
- D-086/D-088 (defrecord `__extmap` / protocol fqcn ns) · D-178/D-179 (seq-slot
  `.list`/`.cons`, `.string_seq`/`.array_seq` splits) · D-105 (java.time).
