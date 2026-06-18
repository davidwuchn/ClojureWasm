#!/usr/bin/env bash
# test/e2e/phase15_java_time_instant.sh — java.time.Instant wiring (D-462).
# Instant is a `.typed_instance` (timestamp.zig/date.zig model: per-Runtime
# descriptor + epoch-ms + nanos fields; no new NaN-box tag). Static factories
# (now/ofEpochSecond/ofEpochMilli/parse) + instance methods (getEpochSecond/
# getNano/toEpochMilli). Values are clj-grounded via `(str …)` = ISO_INSTANT
# (variable fraction + Z) and the method results — NOT pr-str (clj prints the
# opaque `#object[…]` identity form, AD). Uses `cljw -` (stdin). Layer 2.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null
fail() { echo "FAIL $1" >&2; exit 1; }
eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

out() { "$BIN" - ; }

# --- epoch 0: str = ISO_INSTANT (no fraction) + the three readers
A=$(out <<'EOF' 2>&1
(let [i (java.time.Instant/ofEpochSecond 0)]
  (println (str i))
  (println (.getEpochSecond i))
  (println (.getNano i))
  (println (.toEpochMilli i)))
EOF
)
eq 'epoch0' "$A" $'1970-01-01T00:00:00Z\n0\n0\n0'

# --- seconds + nanos: str shows the millis fraction; getNano = full nanos
B=$(out <<'EOF' 2>&1
(let [i (java.time.Instant/ofEpochSecond 1704067200 500000000)]
  (println (str i))
  (println (.getNano i))
  (println (.toEpochMilli i)))
EOF
)
eq 'sec-nanos' "$B" $'2024-01-01T00:00:00.500Z\n500000000\n1704067200500'

# --- parse (ISO-8601) round-trips to the same ISO_INSTANT str
C=$(out <<'EOF' 2>&1
(println (str (java.time.Instant/parse "2024-01-01T00:00:00Z")))
EOF
)
eq 'parse' "$C" '2024-01-01T00:00:00Z'

# --- ofEpochMilli
D=$(out <<'EOF' 2>&1
(println (str (java.time.Instant/ofEpochMilli 1704067200000)))
EOF
)
eq 'ofEpochMilli' "$D" '2024-01-01T00:00:00Z'

# --- (class …) is the simple name (AD-003 no-JVM), and = is by value
E=$(out <<'EOF' 2>&1
(println (= (java.time.Instant/ofEpochSecond 5) (java.time.Instant/ofEpochSecond 5)))
(println (= (java.time.Instant/ofEpochSecond 5) (java.time.Instant/ofEpochSecond 6)))
EOF
)
eq 'value-eq' "$E" $'true\nfalse'

echo "OK — phase15_java_time_instant (D-462) green"
