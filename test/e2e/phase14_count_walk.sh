#!/usr/bin/env bash
# test/e2e/phase14_count_walk.sh — D-422 remainder: (count <deftype>) matches
# clj RT.count. A Counted type (or a Counted-extending interface: Indexed,
# IPersistentMap/Vector/Set) uses its -count directly; a type that declares
# only IPersistentCollection / ISeq / Seqable (NOT Counted) is WALKED via the
# seq, exactly like clj — which ignores IPersistentCollection.count() unless the
# type is also Counted (data.finger-tree's internal trees stub `(count [_])`
# but aren't Counted, so clj walks). Oracle-confirmed: 3 / 42 / 7.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

got=$("$BIN" - <<'EOF' 2>/dev/null
;; Non-Counted self-returning ISeq → count WALKS the seq (clj ignores a
;; non-Counted type's count()).
(deftype L [x nxt]
  clojure.lang.Seqable (seq [this] this)
  clojure.lang.Sequential
  clojure.lang.ISeq (first [_] x) (more [_] (or nxt ())) (next [_] nxt))
(prn (count (L. 1 (L. 2 (L. 3 nil)))))   ; 3 — walked
;; an empty self-returning seq → 0
(deftype E []
  clojure.lang.Seqable (seq [_] nil)
  clojure.lang.Sequential
  clojure.lang.ISeq (first [_] nil) (more [this] this) (next [_] nil))
(prn (count (E.)))                        ; 0 — walked, empty
;; Counted → -count is authoritative (returns its own value, no seq needed).
(deftype C [n]
  clojure.lang.Counted (count [_] n))
(prn (count (C. 42)))                     ; 42 — -count, not walked
;; Indexed extends Counted → -count authoritative.
(deftype I [n]
  clojure.lang.Indexed (count [_] n) (nth [_ i] i) (nth [_ i nf] i))
(prn (count (I. 7)))                      ; 7 — -count
EOF
) || fail "count_walk: non-zero exit ($got)"
assert_eq 'walk_three'   "$(sed -n '1p' <<< "$got")" '3'
assert_eq 'walk_empty'   "$(sed -n '2p' <<< "$got")" '0'
assert_eq 'counted_42'   "$(sed -n '3p' <<< "$got")" '42'
assert_eq 'indexed_7'    "$(sed -n '4p' <<< "$got")" '7'

# bare-name spelling (D-417): a deftype declaring bare Counted still uses -count.
assert_eq 'bare_counted' "$("$BIN" - <<'EOF' 2>/dev/null
(import '(clojure.lang Counted))
(deftype BC [n] Counted (count [_] n))
(prn (count (BC. 5)))
EOF
)" '5'

echo "OK — phase14_count_walk (5 cases) green"
