#!/usr/bin/env bash
# test/e2e/phase14_treemap.sh — java.util.TreeMap (D-431 interop completeness).
# A mutable SORTED key→value map as a .host_instance over a cljw persistent
# sorted-map (RB-tree, GC-traced via host_trace). put/get/containsKey/remove/
# getOrDefault/putIfAbsent/size/isEmpty/clear/keySet/values/firstKey/lastKey + the
# seq/count/into bridge. Iteration is by KEY (sorted). NOTE (AD-032): the raw
# `(seq tm)` yields cljw MapEntry pairs + `.keySet`/`.values` yield cljw seqs — the
# VALUE matches clj (clj yields TreeMap$Entry / Set / Collection views); this e2e
# pins cljw's forms, the clj-parity corpus (TreeMap.txt) pins the matched forms.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# put (returns prev) / get / containsKey / size / sorted seq / remove.
got=$("$BIN" - <<'EOF' 2>/dev/null
(def m (java.util.TreeMap.))
(prn (.isEmpty m))             ; true
(prn [(.put m 3 :c) (.put m 1 :a) (.put m 2 :b) (.put m 1 :A)])  ; [nil nil nil :a]
(prn (seq m))                  ; ([1 :A] [2 :b] [3 :c])  SORTED by key
(prn [(.get m 2) (.containsKey m 9) (.size m)])      ; [:b false 3]
(prn (.remove m 1))            ; :A
(prn (seq m))                  ; ([2 :b] [3 :c])
EOF
)
exp=$'true\n[nil nil nil :a]\n([1 :A] [2 :b] [3 :c])\n[:b false 3]\n:A\n([2 :b] [3 :c])'
assert_eq 'treemap_core' "$got" "$exp"

# seed from a cljw map (rebuilt SORTED) + keySet/values/firstKey/lastKey + into.
got=$("$BIN" - <<'EOF' 2>/dev/null
(def m (java.util.TreeMap. {3 :c 1 :a 2 :b}))
(prn (seq m))                  ; ([1 :a] [2 :b] [3 :c])
(prn (.keySet m))              ; (1 2 3)
(prn (.values m))              ; (:a :b :c)
(prn [(.firstKey m) (.lastKey m)])  ; [1 3]
(prn (into {} m))              ; {1 :a, 2 :b, 3 :c}
EOF
)
exp=$'([1 :a] [2 :b] [3 :c])\n(1 2 3)\n(:a :b :c)\n[1 3]\n{1 :a, 2 :b, 3 :c}'
assert_eq 'treemap_seed_views' "$got" "$exp"

# getOrDefault / putIfAbsent / clear / share from a sorted-map.
got=$("$BIN" - <<'EOF' 2>/dev/null
(def m (java.util.TreeMap. {1 :a 2 :b}))
(prn [(.getOrDefault m 1 :x) (.getOrDefault m 9 :x)])  ; [:a :x]
(prn (.putIfAbsent m 1 :z))    ; :a (unchanged)
(prn (.putIfAbsent m 3 :c))    ; nil (added)
(prn (seq m))                  ; ([1 :a] [2 :b] [3 :c])
(.clear m)
(prn (.isEmpty m))             ; true
(prn (seq (java.util.TreeMap. (sorted-map 9 :i 7 :g 8 :h))))  ; ([7 :g] [8 :h] [9 :i])
EOF
)
exp=$'[:a :x]\n:a\nnil\n([1 :a] [2 :b] [3 :c])\ntrue\n([7 :g] [8 :h] [9 :i])'
assert_eq 'treemap_default_share' "$got" "$exp"

# .firstKey on empty raises (no silent nil).
diag=$("$BIN" -e '(.firstKey (java.util.TreeMap.))' 2>&1 || true)
case "$diag" in *"TreeMap/firstKey"*|*"out of"*|*"range"*) echo "PASS treemap_firstkey_empty_raises" ;; *) fail "treemap_firstkey_empty: got '$diag'" ;; esac

echo
echo "java.util.TreeMap e2e: all green."
