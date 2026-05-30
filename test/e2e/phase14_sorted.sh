#!/usr/bin/env bash
# test/e2e/phase14_sorted.sh — sorted-map / sorted-set cycle A (ADR-0057,
# persistent LLRB red-black tree, default valueCompare): build / get /
# contains? / count / keys / vals / seq (in key order) / assoc / conj /
# sorted?. dissoc / disj / -by / subseq are cycle B/C.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
# sorted-map: ordered keys/vals regardless of insertion order
assert_eq 'keys_ord'  "$("$BIN" -e '(keys (sorted-map :c 3 :a 1 :b 2))')"  '(:a :b :c)'
assert_eq 'vals_ord'  "$("$BIN" -e '(vals (sorted-map :c 3 :a 1 :b 2))')"  '(1 2 3)'
assert_eq 'get'       "$("$BIN" -e '(get (sorted-map :a 1 :b 2) :b)')"     '2'
assert_eq 'count'     "$("$BIN" -e '(count (sorted-map :a 1 :b 2 :c 3))')" '3'
assert_eq 'cont_t'    "$("$BIN" -e '(contains? (sorted-map :a 1) :a)')"    'true'
assert_eq 'cont_f'    "$("$BIN" -e '(contains? (sorted-map :a 1) :z)')"    'false'
assert_eq 'num_ord'   "$("$BIN" -e '(keys (sorted-map 3 :c 1 :a 2 :b))')"  '(1 2 3)'
assert_eq 'dup_val'   "$("$BIN" -e '(get (sorted-map :a 1 :a 2) :a)')"     '2'
assert_eq 'dup_cnt'   "$("$BIN" -e '(count (sorted-map :a 1 :a 2))')"      '1'
assert_eq 'assoc'     "$("$BIN" -e '(keys (assoc (sorted-map :z 26) :a 1 :m 13))')" '(:a :m :z)'
assert_eq 'into20'    "$("$BIN" -e '(vec (keys (into (sorted-map) (map (fn [i] [(- 20 i) i]) (range 20)))))')" '[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]'
assert_eq 'print_map' "$("$BIN" -e '(str (sorted-map :b 2 :a 1))')"        '"{:a 1, :b 2}"'
assert_eq 'as_fn'     "$("$BIN" -e '((sorted-map :a 1 :b 2) :b)')"         '2'
# sorted-set
assert_eq 'set_seq'   "$("$BIN" -e '(seq (sorted-set 5 3 1 4 2))')"        '(1 2 3 4 5)'
assert_eq 'set_cont'  "$("$BIN" -e '(contains? (sorted-set 1 2 3) 2)')"    'true'
assert_eq 'set_conj'  "$("$BIN" -e '(seq (conj (sorted-set 1 3) 2))')"     '(1 2 3)'
assert_eq 'set_dup'   "$("$BIN" -e '(count (sorted-set 1 2 2 3))')"        '3'
assert_eq 'set_print' "$("$BIN" -e '(str (sorted-set 3 1 2))')"           '"#{1 2 3}"'
# sorted?
assert_eq 'sortedQ_m' "$("$BIN" -e '(sorted? (sorted-map))')"            'true'
assert_eq 'sortedQ_s' "$("$BIN" -e '(sorted? (sorted-set))')"            'true'
assert_eq 'sortedQ_n' "$("$BIN" -e '(sorted? {})')"                      'false'
echo "OK — phase14_sorted smoke (21 cases) green"
