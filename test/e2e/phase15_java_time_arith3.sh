#!/usr/bin/env bash
# test/e2e/phase15_java_time_arith3.sh — Instant / Duration / LocalTime arithmetic
# (D-462), closing the temporal-arithmetic area. Instant plus/minus Seconds/Millis/
# Nanos (carry into second-aligned epoch_ms); Duration plus/minus Seconds/Minutes/
# Hours/Days/Millis/Nanos + plus(Duration)/multipliedBy/dividedBy; LocalTime plus/
# minus Hours/Minutes/Seconds/Nanos (WRAP mod 24h, no day). clj-grounded. `cljw -`.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
out() { "$BIN" - ; }

# --- Instant
A=$(out <<'EOF' 2>&1
(let [i (java.time.Instant/ofEpochSecond 100 0)]
  (println (.getEpochSecond (.plusSeconds i 5)) (.toEpochMilli (.plusMillis i 1500))
           (.getNano (.plusNanos i 1)) (.getEpochSecond (.minusSeconds i 50))))
EOF
)
eq 'instant' "$A" '105 101500 1 50'

# --- Duration
B=$(out <<'EOF' 2>&1
(println (str (.plusSeconds (java.time.Duration/ofSeconds 5) 10))
         (str (.plusMinutes (java.time.Duration/ofSeconds 0) 2))
         (str (.plus (java.time.Duration/ofSeconds 5) (java.time.Duration/ofMillis 500)))
         (str (.multipliedBy (java.time.Duration/ofSeconds 3) 4))
         (str (.dividedBy (java.time.Duration/ofSeconds 10) 4))
         (str (.minusSeconds (java.time.Duration/ofSeconds 10) 3)))
EOF
)
eq 'duration' "$B" 'PT15S PT2M PT5.5S PT12S PT2.5S PT7S'

# --- LocalTime (wraps mod 24h)
C=$(out <<'EOF' 2>&1
(println (str (.plusHours (java.time.LocalTime/of 23 0) 2))
         (str (.minusHours (java.time.LocalTime/of 1 0) 2))
         (str (.plusMinutes (java.time.LocalTime/of 12 30) 45))
         (str (.plusNanos (java.time.LocalTime/of 12 0 0 0) 1500000000)))
EOF
)
eq 'localtime' "$C" '01:00 23:00 13:15 12:00:01.500'

echo "OK — phase15_java_time_arith3 (D-462) green"
