#!/usr/bin/env bash
# test/e2e/phase14_with_in_str.sh — D-414 slice 1: the `*in*` input subsystem.
# `*in*` dynamic var + `read-line` + `with-in-str` over the existing host
# `cljw.internal/__string-reader` (.readLine). `line-seq` already reads any host reader;
# this wires it to `*in*`. (Pushback + the LispReader$StringReader shim that
# instaparse needs are later slices.) Oracle-confirmed: read-line/line-seq.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

got=$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "hello\nworld" [(read-line) (read-line) (read-line)]))  ; ["hello" "world" nil]
(prn (with-in-str "a\nb\nc" (doall (line-seq *in*))))                      ; ("a" "b" "c")
(prn (with-in-str "" (read-line)))                                         ; nil (empty)
(prn (read-line))                                                          ; nil (no *in* bound; cljw has no process-stdin)
EOF
) || fail "with_in_str: non-zero exit ($got)"
assert_eq 'read_line_lines'  "$(sed -n '1p' <<< "$got")" '["hello" "world" nil]'
assert_eq 'line_seq'         "$(sed -n '2p' <<< "$got")" '("a" "b" "c")'
assert_eq 'empty_read_line'  "$(sed -n '3p' <<< "$got")" 'nil'
assert_eq 'unbound_read_line' "$(sed -n '4p' <<< "$got")" 'nil'

# *in* is dynamically rebindable like *out* (nested bindings restore).
assert_eq 'nested_rebind' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "outer"
       [(read-line)
        (with-in-str "inner" (read-line))
        (with-in-str "x\ny" (read-line))]))
EOF
)" '["outer" "inner" "x"]'

echo "OK — phase14_with_in_str (5 cases) green"
