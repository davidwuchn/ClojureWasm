#!/usr/bin/env bash
# test/e2e/phase14_deftype_kvreduce_blocking.sh — the D-400 marker-family
# remainder: clojure.lang.IKVReduce (reduce-kv dispatch), IBlockingDeref
# (3-arity timed deref on deftypes + native future/promise), Indexed 3-arity
# not-found nth on deftypes, and IFn applyTo registration. All expected
# values oracle-verified against clj 2026-06-13.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

got=$("$BIN" - <<'EOF' 2>/dev/null
(deftype KvBag [m]
  clojure.lang.IKVReduce
  (kvreduce [_ f init] (reduce (fn [acc [k v]] (f acc k v)) init (seq m))))
(prn (reduce-kv (fn [acc k v] (assoc acc v k)) {} (->KvBag {:a 1 :b 2})))
(prn (reduce-kv (fn [acc k v] (+ acc v)) 0 (->KvBag {:a 1 :b 2})))
(deftype TimedBox [v]
  clojure.lang.IBlockingDeref
  (deref [_ ms timeout-val] (if (neg? ms) timeout-val v))
  clojure.lang.IDeref
  (deref [_] v))
(prn (deref (->TimedBox 42) 10 :timeout))
(prn (deref (->TimedBox 42) -1 :timeout))
(prn @(->TimedBox 42))
(deftype Idx [n]
  clojure.lang.Indexed
  (nth [_ i] (* i n))
  (nth [_ i nf] (if (< i 3) (* i n) nf)))
(prn (nth (->Idx 10) 2))
(prn (nth (->Idx 10) 9 :nf))
(deftype CallMe []
  clojure.lang.IFn
  (invoke [_ a] [:one a])
  (invoke [_ a b] [:two a b])
  (applyTo [this args] (case (count args) 1 (this (first args)) 2 (this (first args) (second args)))))
(prn ((->CallMe) 1))
(prn (apply (->CallMe) [1 2]))
(prn (deref (future 7) 50 :timeout))
(prn (deref (promise) 30 :timeout))
(let [p (promise)] (deliver p :pv) (prn (deref p 30 :timeout)))
EOF
) || true
want='{1 :a, 2 :b}
3
42
:timeout
42
20
:nf
[:one 1]
[:two 1 2]
7
:timeout
:pv'
assert_eq 'kvreduce_blocking_indexed_applyto' "$got" "$want"

# reduce-kv on a RECORD (no IKVReduce) still takes the keys fallback.
got=$("$BIN" - <<'EOF' 2>/dev/null
(defrecord R [a b])
(prn (reduce-kv (fn [acc k v] (assoc acc v k)) {} (->R 1 2)))
EOF
) || true
assert_eq 'reduce_kv_record_fallback' "$got" '{1 :a, 2 :b}'

echo "OK — phase14_deftype_kvreduce_blocking (2 cases) green"
