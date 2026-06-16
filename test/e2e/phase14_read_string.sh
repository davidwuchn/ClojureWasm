#!/usr/bin/env bash
# test/e2e/phase14_read_string.sh — clojure.core/read-string. In cljw the
# reader has no `#=` eval-reader, so core/read-string is the same full-reader
# readOne→formToValue as clojure.edn/read-string (a safe DIVERGENCE: JVM
# core/read-string can eval). Reads one form from a string as DATA.
#
# Layer 2 (e2e CLI) per ADR-0021.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_eq 'rs_int'     "$("$BIN" -e '(read-string "42")')"                  '42'
assert_eq 'rs_vec'     "$("$BIN" -e '(read-string "[1 2 3]")')"             '[1 2 3]'
assert_eq 'rs_map'     "$("$BIN" -e '(read-string "{:a 1 :b 2}")')"         '{:a 1, :b 2}'
assert_eq 'rs_set'     "$("$BIN" -e '(read-string "#{1 2 3}")')"            '#{1 2 3}'
assert_eq 'rs_str'     "$("$BIN" -e '(read-string "\"hi\"")')"              '"hi"'
assert_eq 'rs_kw'      "$("$BIN" -e '(read-string ":foo")')"                ':foo'
assert_eq 'rs_list1st' "$("$BIN" -e '(first (read-string "(a b c)"))')"     'a'
assert_eq 'rs_nested'  "$("$BIN" -e '(read-string "[1 {:a [2 3]}]")')"      '[1 {:a [2 3]}]'
assert_eq 'rs_count'   "$("$BIN" -e '(count (read-string "(1 2 3 4)"))')"   '4'
# AD-026 / SE-8: read-string is eval-free BY DESIGN (ADR-0122). clj's read-string
# evaluates `#=(…)` (read-eval) and returns 3; cljw's EDN-based reader must NOT —
# reading untrusted data never executes code. Lock the secure-by-default property.
rs_re="$("$BIN" -e '(read-string "#=(+ 1 2)")' 2>&1 || true)"
[[ "$rs_re" != "3" ]] || fail "rs_no_read_eval: #= was evaluated (got 3) — read-string must stay eval-free"
echo "PASS rs_no_read_eval -> not evaluated (eval-free reader)"
# D-457(3): read-string REJECTS a reader conditional #? (clj: "Conditional read
# not allowed") unless the caller opts in with :read-cond :allow.
assert_eq 'rs_readcond_rejected' "$("$BIN" -e '(try (read-string "#?(:clj 1 :cljs 2)") (catch Throwable e :raised))')" ':raised'
assert_eq 'rs_readcond_optin'    "$("$BIN" -e '(read-string {:read-cond :allow} "#?(:clj 1 :cljs 2)")')" '1'
# Safety: SOURCE evaluation still allows #? (require/load/eval of a .clj(c) is a
# source-load context — the Reader default). cljw -e is source-eval, not a data read.
assert_eq 'rs_source_allows_cond' "$("$BIN" -e '#?(:clj 42 :cljs 0)')" '42'
echo "OK — phase14_read_string (13 cases) green"
