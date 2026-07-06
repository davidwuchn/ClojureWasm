#!/usr/bin/env bash
# test/e2e/phase16_clojure_repl.sh — clojure.repl bundled ns (D-513 finding 2,
# unblocked by D-305's :doc/:arglists metadata): doc / dir-fn / apropos /
# demunge / find-doc; source throws (per-var source text is not retained).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
assert_has() { local n="$1" g="$2" w="$3"; [[ "$g" == *"$w"* ]] || fail "$n: '$g' lacks '$w'"; echo "PASS $n =~ $w"; }

assert_has 'doc_header'   "$("$BIN" -e '(require (quote clojure.repl)) (clojure.repl/doc interpose)' 2>&1)" 'clojure.core/interpose'
assert_has 'doc_arglists' "$("$BIN" -e '(require (quote clojure.repl)) (clojure.repl/doc interpose)' 2>&1)" '([sep] [sep coll])'
assert_has 'doc_text'     "$("$BIN" -e '(require (quote clojure.repl)) (clojure.repl/doc interpose)' 2>&1)" 'separated by sep'
assert_eq 'apropos'  "$("$BIN" -e '(require (quote clojure.repl)) (first (clojure.repl/apropos "interpos"))' 2>&1 | tail -1)" 'clojure.core/interpose'
assert_eq 'dir_fn'   "$("$BIN" -e '(require (quote clojure.repl) (quote clojure.set)) (pos? (count (clojure.repl/dir-fn (quote clojure.set))))' 2>&1 | tail -1)" 'true'
assert_eq 'demunge'  "$("$BIN" -e '(require (quote clojure.repl)) (clojure.repl/demunge "my_fn_QMARK_")' 2>&1 | tail -1)" '"my-fn?"'
assert_has 'find_doc' "$("$BIN" -e '(require (quote clojure.repl)) (clojure.repl/find-doc "separated by sep")' 2>&1)" 'clojure.core/interpose'
assert_has 'source_throws' "$("$BIN" -e '(require (quote clojure.repl)) (try (clojure.repl/source-fn (quote map)) (catch Throwable e (ex-message e)))' 2>&1 | tail -1)" 'not available'

echo "OK — phase16_clojure_repl (8 cases) green"
