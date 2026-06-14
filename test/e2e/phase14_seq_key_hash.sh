#!/usr/bin/env bash
# test/e2e/phase14_seq_key_hash.sh
#
# Track D D1 (D-432 + D-408): a content-equal lazy_seq / cons-over-lazy / range /
# Sequential-deftype used as a map/set KEY must hash + compare by element CONTENT,
# not by identity — so it buckets with the =-equal vector/list and `get`/`contains?`
# find it. Fix = Option A (ADR-0129 ambient `current_env`): realize the key, then
# delegate to the rt-free seqHash/seqKeyEq. Alt-1 arms `current_env` in
# `runEnvelope` so the AOT (`cljw build`) top-level path is armed too (no silent miss).
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() {
    local name="$1"; local got="$2"; local want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> $want"
}

# --- (1) lazy_seq key (the headline D-432 repro). `cljw -e` prints the value. ---
got=$("$BIN" -e "(get {(map inc [0 1 2]) :x} '(1 2 3))" 2>/dev/null)
assert_eq 'lazy_seq_key' "$got" ':x'

# --- (2) cons-over-lazy key (the D-408 half: a .list whose tail is lazy). ---
got=$("$BIN" -e '(get {(cons 1 (map inc [9])) :v} (cons 1 (map inc [9])))' 2>/dev/null)
assert_eq 'cons_over_lazy_key' "$got" ':v'

# --- (3) range key. ---
got=$("$BIN" -e "(get {(range 3) :r} '(0 1 2))" 2>/dev/null)
assert_eq 'range_key' "$got" ':r'

# --- (4) hash collides across lazy / vector / list forms. ---
got=$("$BIN" -e "(= (hash (map inc [0 1 2])) (hash [1 2 3]) (hash '(1 2 3)))" 2>/dev/null)
assert_eq 'hash_collides' "$got" 'true'

# --- (5) lazy_seq as a SET element. ---
got=$("$BIN" -e "(contains? #{(map inc [0 1 2])} '(1 2 3))" 2>/dev/null)
assert_eq 'lazy_seq_set_element' "$got" 'true'

# --- (6) Sequential deftype key (the D-432 instance half). A deftype declaring
#     clojure.lang.Sequential is realized element-wise (D-427) for hash too. ---
got=$("$BIN" - <<'EOF' 2>/dev/null
(deftype L [xs]
  clojure.lang.Sequential
  clojure.lang.Seqable (seq [_] (seq xs)))
(prn (get {(L. [1 2 3]) :d} '(1 2 3)))
EOF
)
assert_eq 'sequential_deftype_key' "$got" ':d'

# --- (7) AOT path (Alt-1): a top-level seq-keyed literal in a `cljw build`
#     artifact runs through `runEnvelope`/`vm.eval`, which must also arm
#     `current_env` — else the key hashes by identity at run and silently misses. ---
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/seqkey.clj" <<'CLJ'
(println (get {(map inc [0 1 2]) :x} '(1 2 3)))
CLJ
"$BIN" build "$TMP/seqkey.clj" -o "$TMP/seqkey" >/dev/null
got=$(cd "$TMP" && "$TMP/seqkey")
assert_eq 'aot_top_level_seq_key' "$got" ':x'

echo
echo "phase14_seq_key_hash (Track D D1, D-432/D-408) e2e: all green."
