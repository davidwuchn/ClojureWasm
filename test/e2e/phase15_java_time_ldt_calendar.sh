#!/usr/bin/env bash
# test/e2e/phase15_java_time_ldt_calendar.sh — LocalDateTime calendar arithmetic
# (D-462): plusMonths/minusMonths/plusYears/minusYears. Applies the civil
# month/year clamp to the DATE part (epoch_day, shared with LocalDate) and KEEPS
# the time-of-day (nano_of_day). clj-grounded incl. the Feb-clamp + year-rollover
# edges. Uses `cljw -` (stdin). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }
out() { "$BIN" - ; }

A=$(out <<'EOF' 2>&1
(println (str (.plusMonths (java.time.LocalDateTime/of 2024 1 31 14 30) 1))     ; Feb29 clamp, keep 14:30
         (str (.plusMonths (java.time.LocalDateTime/of 2023 1 31 9 0) 1))       ; Feb28
         (str (.plusMonths (java.time.LocalDateTime/of 2024 12 15 6 0) 2))      ; year rollover
         (str (.minusMonths (java.time.LocalDateTime/of 2024 3 31 0 0) 1)))     ; Feb29
EOF
)
eq 'months' "$A" '2024-02-29T14:30 2023-02-28T09:00 2025-02-15T06:00 2024-02-29T00:00'

B=$(out <<'EOF' 2>&1
(println (str (.plusYears (java.time.LocalDateTime/of 2024 2 29 23 59 59) 1))   ; Feb28 clamp, keep time
         (str (.minusYears (java.time.LocalDateTime/of 2024 6 15 12 0) 5)))
EOF
)
eq 'years' "$B" '2025-02-28T23:59:59 2019-06-15T12:00'

echo "OK — phase15_java_time_ldt_calendar (D-462) green"
