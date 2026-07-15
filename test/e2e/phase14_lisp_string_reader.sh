#!/usr/bin/env bash
# test/e2e/phase14_lisp_string_reader.sh — D-414 slice 2: the
# clojure.lang.LispReader$StringReader host shim + java.util.LinkedList ctor.
# `(clojure.lang.LispReader$StringReader.)` returns a cljw-native reader-macro fn
# that reads a string LITERAL (up to + consuming the closing `"`, escape-aware)
# from an *in* reader — exactly instaparse's safe-read-string path. LinkedList is
# modelled as the shared mutable-list host_instance (= ArrayList). This clears the
# D-414 reader barrier (instaparse cfg.cljc:214); its remaining blocker is
# elsewhere (instaparse.gll.Failure, D-428 — a separate qualified-deftype gap).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

got=$("$BIN" - <<'EOF' 2>/dev/null
;; instaparse's safe-read-string shape (cfg.cljc:214-221): a StringReader read
;; from *in*, which contains the content + a trailing closing quote.
(def string-reader (clojure.lang.LispReader$StringReader.))
(defn safe-read-string [s] (with-in-str s (string-reader *in* nil)))
(prn (safe-read-string "hello\""))            ; "hello"
(prn (safe-read-string "a\\tb\\nc\""))        ; "a\tb\nc" (escapes decoded)
(prn (safe-read-string "with \\\"q\\\"\""))   ; "with \"q\"" (escaped quotes are literal)
(prn (safe-read-string "\""))                 ; "" (empty literal)
;; the wrap-reader 4-arg invoke (reader quote opts pending) — extra args ignored.
(prn (string-reader (cljw.internal/__in-reader "four\"") nil {} (java.util.LinkedList.)))  ; "four"
EOF
) || fail "string_reader: non-zero exit ($got)"
assert_eq 'srs_basic'   "$(sed -n '1p' <<< "$got")" '"hello"'
assert_eq 'srs_escapes' "$(sed -n '2p' <<< "$got")" '"a\tb\nc"'
assert_eq 'srs_quotes'  "$(sed -n '3p' <<< "$got")" '"with \"q\""'
assert_eq 'srs_empty'   "$(sed -n '4p' <<< "$got")" '""'
assert_eq 'srs_4arg'    "$(sed -n '5p' <<< "$got")" '"four"'

# java.util.LinkedList is a real mutable list (shares the ArrayList impl).
got=$("$BIN" - <<'EOF' 2>/dev/null
(def ll (java.util.LinkedList.))
(.add ll :a) (.add ll :b)
(prn [(.size ll) (.get ll 0) (vec ll)])
EOF
) || fail "linkedlist: non-zero exit ($got)"
assert_eq 'linkedlist' "$got" '[2 :a [:a :b]]'

echo "OK — phase14_lisp_string_reader (6 cases) green"
