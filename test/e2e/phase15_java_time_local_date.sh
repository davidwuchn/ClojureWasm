#!/usr/bin/env bash
# test/e2e/phase15_java_time_local_date.sh — java.time.LocalDate + LocalTime
# (D-462). Both are `.typed_instance` values: LocalDate = [epoch_day] (via
# daysFromCivil), LocalTime = [nano_of_day]. They are the two halves of
# LocalDateTime and share its ISO date/time format+parse helpers. Also wires
# LocalDateTime.toLocalDate / toLocalTime (return the new types). clj-grounded.
# Uses `cljw -` (stdin). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
out() { "$BIN" - ; }

# --- LocalDate: str (incl. zero-padded year), readers, parse, plusDays, =
A=$(out <<'EOF' 2>&1
(doseq [d [(java.time.LocalDate/of 2024 1 1) (java.time.LocalDate/of 2024 12 31) (java.time.LocalDate/of 1 1 1)]]
  (println (str d)))
(let [d (java.time.LocalDate/of 2024 3 9)] (println (.getYear d) (.getMonthValue d) (.getDayOfMonth d)))
(println (str (java.time.LocalDate/parse "2024-02-29")))
(println (str (.plusDays (java.time.LocalDate/of 2024 1 1) 40)))
(println (= (java.time.LocalDate/of 2024 1 1) (java.time.LocalDate/of 2024 1 1)))
(println (= (java.time.LocalDate/of 2024 1 1) (java.time.LocalDate/of 2024 1 2)))
EOF
)
eq 'localdate' "$A" $'2024-01-01\n2024-12-31\n0001-01-01\n2024 3 9\n2024-02-29\n2024-02-10\ntrue\nfalse'

# --- LocalTime: str (conditional sec + fraction), readers, parse, =
B=$(out <<'EOF' 2>&1
(doseq [t [(java.time.LocalTime/of 12 30) (java.time.LocalTime/of 12 30 45) (java.time.LocalTime/of 12 30 45 500000000) (java.time.LocalTime/of 0 0)]]
  (println (str t)))
(let [t (java.time.LocalTime/of 14 5 45 123456789)] (println (.getHour t) (.getMinute t) (.getSecond t) (.getNano t)))
(println (str (java.time.LocalTime/parse "06:07:08")))
(println (= (java.time.LocalTime/of 12 30) (java.time.LocalTime/of 12 30 0)))
(println (= (java.time.LocalTime/of 12 30) (java.time.LocalTime/of 12 31)))
EOF
)
eq 'localtime' "$B" $'12:30\n12:30:45\n12:30:45.500\n00:00\n14 5 45 123456789\n06:07:08\ntrue\nfalse'

# --- LocalDateTime.toLocalDate / toLocalTime return the new types
C=$(out <<'EOF' 2>&1
(let [dt (java.time.LocalDateTime/of 2024 3 9 14 5 45 500000000)]
  (println (str (.toLocalDate dt)))
  (println (str (.toLocalTime dt))))
EOF
)
eq 'to-local' "$C" $'2024-03-09\n14:05:45.500'

echo "OK — phase15_java_time_local_date (D-462) green"
