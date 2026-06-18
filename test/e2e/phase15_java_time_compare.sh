#!/usr/bin/env bash
# test/e2e/phase15_java_time_compare.sh — java.time comparison predicates +
# Duration unary ops (D-462). isBefore/isAfter on the point types (Instant,
# LocalDate, LocalTime, LocalDateTime), isEqual on LocalDate/LocalDateTime,
# and Duration isZero/isNegative/negated/abs. All exact-match vs clj (no AD;
# compareTo's JVM magnitude is a separate follow-up). Uses `cljw -`. Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
out() { "$BIN" - ; }

A=$(out <<'EOF' 2>&1
(let [a (java.time.Instant/ofEpochSecond 5) b (java.time.Instant/ofEpochSecond 9)]
  (println (.isBefore a b) (.isAfter a b) (.isBefore a a) (.isAfter b a)))
EOF
)
eq 'instant' "$A" 'true false false true'

B=$(out <<'EOF' 2>&1
(let [a (java.time.LocalDate/of 2024 1 1) b (java.time.LocalDate/of 2024 6 1)]
  (println (.isBefore a b) (.isAfter a b) (.isEqual a b) (.isEqual a (java.time.LocalDate/of 2024 1 1))))
EOF
)
eq 'localdate' "$B" 'true false false true'

C=$(out <<'EOF' 2>&1
(let [a (java.time.LocalTime/of 6 0) b (java.time.LocalTime/of 18 0)]
  (println (.isBefore a b) (.isAfter a b)))
(let [a (java.time.LocalDateTime/of 2024 1 1 6 0) b (java.time.LocalDateTime/of 2024 1 1 18 0)]
  (println (.isBefore a b) (.isAfter a b) (.isEqual a b)))
EOF
)
eq 'localtime-ldt' "$C" $'true false\ntrue false false'

D=$(out <<'EOF' 2>&1
(println (.isZero (java.time.Duration/ofSeconds 0))
         (.isZero (java.time.Duration/ofSeconds 5))
         (.isNegative (java.time.Duration/ofSeconds -1))
         (.isNegative (java.time.Duration/ofSeconds 1)))
(println (str (.negated (java.time.Duration/ofMillis 1500)))
         (str (.abs (java.time.Duration/ofSeconds -30)))
         (str (.abs (java.time.Duration/ofSeconds 30)))
         (str (.negated (java.time.Duration/ofSeconds 0))))
EOF
)
eq 'duration-unary' "$D" $'true false true false\nPT-1.5S PT30S PT30S PT0S'

echo "OK — phase15_java_time_compare (D-462) green"
