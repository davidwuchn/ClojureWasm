#!/usr/bin/env bash
# test/e2e/phase14_text_reader.sh — ADR-0138 Track C build-step 3: the durable
# cljw-native Reader VALUE backing `*in*` (text_io). `with-in-str` now binds
# `*in*` to a text_io Reader (fqcn "Reader", 1-slot codepoint pushback), distinct
# from host_stream's file BufferedReader (JVM *in*=PushbackReader ≠ file reader).
# Surface: .read (codepoint int / -1) / .peek / .unread / .readLine / .close +
# the folded LispReader$StringReader literal-read op. read-line / line-seq /
# instaparse safe-read-string ride this (regression-guarded by the other e2e).
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# *in* under with-in-str is a Reader value, not the old host BufferedReader.
assert_eq 'in_is_reader' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "abc" (class *in*)))
EOF
)" 'Reader'

# .read returns the next codepoint as an int; -1 at EOF.
assert_eq 'read_codepoints' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "AB" [(.read *in*) (.read *in*) (.read *in*)]))
EOF
)" '[65 66 -1]'

# .peek returns the next codepoint WITHOUT advancing; a following .read sees it.
assert_eq 'peek_no_advance' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "XY" [(.peek *in*) (.read *in*) (.read *in*)]))
EOF
)" '[88 88 89]'

# .unread pushes a codepoint back so the next .read returns it (1-slot pushback).
assert_eq 'unread_pushback' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "Z" [(.read *in*) (do (.unread *in* 65) (.read *in*)) (.read *in*)]))
EOF
)" '[90 65 -1]'

# read-line / line-seq still work over the Reader value (D-414 regression).
assert_eq 'read_line_regress' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "p\nq" [(read-line) (read-line) (read-line)]))
EOF
)" '["p" "q" nil]'

# Multibyte: .read returns the full codepoint, .unread restores it intact.
assert_eq 'read_multibyte' "$("$BIN" - <<'EOF' 2>/dev/null
(prn (with-in-str "あい" [(.read *in*) (do (.unread *in* 12354) (.read *in*)) (.read *in*)]))
EOF
)" '[12354 12354 12356]'

echo "OK — phase14_text_reader (6 cases) green"
