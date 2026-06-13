#!/usr/bin/env bash
# test/e2e/phase14_reify_remap.sh — reify protocol_remap awareness.
# `reify` formerly bypassed the host_interface remap tables entirely (it built
# its method rows with the clj method name verbatim), so a clojure.lang.*
# interface method registered under (DeclaredInterface, cljName) and never
# dispatched through its real cljw (protocol, -method) target. Worst case was a
# SILENT failure: `(get (reify Associative (valAt [_ k] …)) k)` → nil. Now reify
# routes each protocol_remap section through the SAME remapMethod translation
# deftype/extend-type use (D-280/286/417/419), incl. inheritance-flatten
# (count under Indexed, valAt under Associative) and the D-283 dual clj-name row.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

FIX=/tmp/phase14_reify_remap_$$.clj
cat > "$FIX" <<'CLJ'
;; valAt under Associative (Associative extends ILookup) — formerly SILENT nil.
;; Bodies delegate to a backing map, as real reify code does.
(def a (reify Associative
         (valAt [_ k] (get {:x 42} k))
         (valAt [_ k nf] (get {:x 42} k nf))
         (assoc [this k v] this)
         (containsKey [_ k] (contains? {:x 42} k))
         (entryAt [_ k] nil)))
(println (get a :x))            ; -> 42 (dispatches ILookup/-lookup; was silent nil)
(println (get a :y :dflt))      ; -> :dflt (3-arity not-found)
(println (.valAt a :x))         ; -> 42 (D-283 dual: clj name dot-call resolves)

;; count/nth under Indexed (Indexed extends Counted) — formerly an ERROR.
(def b (reify Indexed (count [_] 7) (nth [_ i nf] (if (< i 7) i nf))))
(println (count b))             ; -> 7 (IPersistentCollection/-count)
(println (nth b 2 :z))          ; -> 2

;; base protocol_remap (non-inheritance): valAt under ILookup directly (D-280).
(def c (reify ILookup
         (valAt [_ k] (str "k=" k))
         (valAt [_ k nf] (str "k=" k))))
(println (get c :q))            ; -> "k=:q"
CLJ

out=$("$BIN" "$FIX" 2>&1) || fail "run: non-zero exit ($out)"
rm -f "$FIX"
assert_eq 'valAt_under_assoc'    "$(sed -n '1p' <<< "$out")" '42'
assert_eq 'valAt_under_assoc_nf' "$(sed -n '2p' <<< "$out")" ':dflt'
assert_eq 'valAt_dotcall_dual'   "$(sed -n '3p' <<< "$out")" '42'
assert_eq 'count_under_indexed'  "$(sed -n '4p' <<< "$out")" '7'
assert_eq 'nth_under_indexed'    "$(sed -n '5p' <<< "$out")" '2'
assert_eq 'valAt_under_ilookup'  "$(sed -n '6p' <<< "$out")" 'k=:q'

echo "OK — phase14_reify_remap (6 cases) green"
