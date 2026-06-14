#!/usr/bin/env bash
# test/e2e/phase14_self_seq_print.sh — D-422 (the finger-tree conjl segfault root).
# A deftype that is BOTH ISeq and Seqable with the clj idiom `(seq [this] this)`
# (a value that IS its own seq) used to SEGFAULT when printed: deepRealize's
# Sequential typed_instance arm dispatched -seq (→ the same instance), then
# deepRealize'd it again → infinite recursion. Now it walks the ISeq protocol
# (-first/-next) for a self-returning -seq. Synthetic repro (no finger-tree dep).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

FIX=/tmp/phase14_selfseq_$$.clj
cat > "$FIX" <<'CLJ'
;; A 2-element self-returning ISeq (the data.finger-tree SingleTree/DoubleList shape).
(deftype Node [x nxt]
  Seqable (seq [this] this)
  Sequential
  ISeq (first [_] x) (more [_] (or nxt ())) (next [_] nxt))
(def two (Node. 1 (Node. 2 nil)))
(prn (seq two))            ; (1 2) — printing a self-returning ISeq no longer loops
(prn (vec two))            ; [1 2]
(prn (first two))          ; 1
(prn (map inc two))        ; (2 3)
;; an empty self-returning seq → printed as ()
(deftype Empty []
  Seqable (seq [_] nil)
  Sequential
  ISeq (first [_] nil) (more [this] this) (next [_] nil))
(prn (seq (Empty.)))       ; nil
CLJ
out=$("$BIN" "$FIX" 2>&1) || fail "run: non-zero exit ($out)"
rm -f "$FIX"
assert_eq 'self_seq_print'  "$(sed -n '1p' <<< "$out")" '(1 2)'
assert_eq 'self_seq_vec'    "$(sed -n '2p' <<< "$out")" '[1 2]'
assert_eq 'self_seq_first'  "$(sed -n '3p' <<< "$out")" '1'
assert_eq 'self_seq_map'    "$(sed -n '4p' <<< "$out")" '(2 3)'
assert_eq 'empty_self_seq'  "$(sed -n '5p' <<< "$out")" 'nil'

echo "OK — phase14_self_seq_print (5 cases) green"
