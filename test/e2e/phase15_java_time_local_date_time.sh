#!/usr/bin/env bash
# test/e2e/phase15_java_time_local_date_time.sh — java.time.LocalDateTime (D-462).
# A `.typed_instance` (instant_value.zig model) carrying TWO fields:
# epoch-day (signed days since 1970-01-01, via daysFromCivil) + nano-of-day
# ([0,86400e9)). Factories of(y,m,d,h,mi[,s[,n]]) (arity 5-7), now, parse;
# instance getYear/getMonthValue/getDayOfMonth/getHour/getMinute/getSecond/
# getNano. `(str d)` = ISO local date-time (omits :ss when sec=nano=0, variable
# fraction) — clj-grounded. Uses `cljw -` (stdin). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
out() { "$BIN" - ; }

# --- str: ISO local, conditional seconds + variable fraction
A=$(out <<'EOF' 2>&1
(doseq [d [(java.time.LocalDateTime/of 2024 1 1 12 30)
           (java.time.LocalDateTime/of 2024 1 1 12 30 45)
           (java.time.LocalDateTime/of 2024 1 1 12 30 45 500000000)
           (java.time.LocalDateTime/of 2024 6 15 0 0 0)
           (java.time.LocalDateTime/of 2024 12 31 0 0)]]
  (println (str d)))
EOF
)
eq 'str-forms' "$A" $'2024-01-01T12:30\n2024-01-01T12:30:45\n2024-01-01T12:30:45.500\n2024-06-15T00:00\n2024-12-31T00:00'

# --- readers
B=$(out <<'EOF' 2>&1
(let [d (java.time.LocalDateTime/of 2024 3 9 14 5 45 123456789)]
  (println (.getYear d) (.getMonthValue d) (.getDayOfMonth d)
           (.getHour d) (.getMinute d) (.getSecond d) (.getNano d)))
EOF
)
eq 'readers' "$B" '2024 3 9 14 5 45 123456789'

# --- parse (with + without seconds)
C=$(out <<'EOF' 2>&1
(println (str (java.time.LocalDateTime/parse "2024-01-01T12:30:45")))
(println (str (java.time.LocalDateTime/parse "2024-01-01T12:30")))
EOF
)
eq 'parse' "$C" $'2024-01-01T12:30:45\n2024-01-01T12:30'

# --- value =
D=$(out <<'EOF' 2>&1
(println (= (java.time.LocalDateTime/of 2024 1 1 12 30 0) (java.time.LocalDateTime/of 2024 1 1 12 30)))
(println (= (java.time.LocalDateTime/of 2024 1 1 12 30) (java.time.LocalDateTime/of 2024 1 1 12 31)))
EOF
)
eq 'value-eq' "$D" $'true\nfalse'

echo "OK — phase15_java_time_local_date_time (D-462) green"
