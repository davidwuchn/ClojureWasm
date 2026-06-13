#!/usr/bin/env bash
# test/e2e/phase14_deftype_inherited_method.sh — D-419.
# clj's deftype is lenient about which `interface` header a method body sits
# under: it only requires the type to implement SOME interface declaring it,
# INCLUDING via interface inheritance. data.finger-tree's `defdigit` writes
# `count` under its `Indexed` header (clj `Indexed extends Counted`), and
# CountedDoubleList writes `valAt` under `Associative` (clj `Associative extends
# ILookup`). cljw's per-section remap was strict, so these raised "method not yet
# wired". The fix flattens the inherited method into the sub-interface's remap
# table (mirrors the existing Counted → IPersistentCollection/-count flatten), so
# the method lowers + dispatches through its real cljw protocol.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

FIX=/tmp/phase14_inherited_$$.clj
cat > "$FIX" <<'CLJ'
;; count under Indexed (Indexed extends Counted) — bare clojure.lang spelling,
;; exactly as data.finger-tree's defdigit writes it.
(deftype Digits [n]
  Indexed
    (count [_] n)
    (nth [_ i nf] (if (< i n) i nf)))
(println (count (Digits. 3)))           ; -> 3 (dispatches IPersistentCollection/-count)
(println (nth (Digits. 3) 1 :x))        ; -> 1 (Indexed/-nth)
(println (nth (Digits. 3) 9 :x))        ; -> :x

;; valAt under Associative (Associative extends ILookup) — CountedDoubleList's shape.
(deftype Lookup [m]
  Associative
    (valAt [_ k] (get m k))
    (valAt [_ k nf] (get m k nf))
    (assoc [this k v] this)
    (containsKey [_ k] (contains? m k))
    (entryAt [_ k] nil))
(println (get (Lookup. {:a 1 :b 2}) :a)) ; -> 1 (dispatches ILookup/-lookup)
(println (get (Lookup. {:a 1}) :z :none)) ; -> :none
CLJ

out=$("$BIN" "$FIX" 2>&1) || fail "run: non-zero exit ($out)"
rm -f "$FIX"
assert_eq 'count_under_indexed'  "$(sed -n '1p' <<< "$out")" '3'
assert_eq 'nth_under_indexed'    "$(sed -n '2p' <<< "$out")" '1'
assert_eq 'nth_notfound'         "$(sed -n '3p' <<< "$out")" ':x'
assert_eq 'valAt_under_assoc'    "$(sed -n '4p' <<< "$out")" '1'
assert_eq 'valAt_under_assoc_nf' "$(sed -n '5p' <<< "$out")" ':none'

echo "OK — phase14_deftype_inherited_method (5 cases) green"
