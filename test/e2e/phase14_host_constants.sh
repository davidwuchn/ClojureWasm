#!/usr/bin/env bash
# test/e2e/phase14_host_constants.sh
#
# ADR-0174 D7b + D8 — host-class constants + uniform enum statics +
# java.time fill: java.time singleton constants (Instant/EPOCH,
# Duration/ZERO, LocalTime/NOON, ...), BigDecimal ZERO/ONE/TWO/TEN,
# host-enum values/valueOf/of (the ADR-0161 registry, one generic body),
# Pattern 2-arg compile (flag ints -> engine Flags; (str p) stays the
# ORIGINAL source), File/createTempFile + listRoots, Duration/parse +
# Duration/of, LocalDate/ofEpochDay, LocalTime/ofSecondOfDay.
# Every expected value below is pinned against the local clj oracle.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() {
    local name="$1" got="$2" want="$3"
    [[ "$got" == "$want" ]] || fail "$name: got '$got', want '$want'"
    echo "PASS $name -> $want"
}

run() { "$BIN" - <<EOF 2>&1 || true
$1
EOF
}

# --- time constants (Singleton pattern, ADR-0174 D7b) ---
assert_eq 'instant_epoch' "$(run '(println (str java.time.Instant/EPOCH))')" '1970-01-01T00:00:00Z'
assert_eq 'localtime_noon' "$(run '(println (str java.time.LocalTime/NOON))')" '12:00'
assert_eq 'duration_zero' "$(run '(println (str java.time.Duration/ZERO))')" 'PT0S'
assert_eq 'localdate_min_max' "$(run '(println [(str java.time.LocalDate/MIN) (str java.time.LocalDate/MAX)])')" '[-999999999-01-01 +999999999-12-31]'

# --- BigDecimal value constants ---
assert_eq 'bigdec_two' "$(run '(prn java.math.BigDecimal/TWO)')" '2M'
assert_eq 'bigdec_ten_eq' "$(run '(println (= java.math.BigDecimal/TEN 10M))')" 'true'

# --- host-enum uniform statics (values / valueOf / of) ---
assert_eq 'roundingmode_values' "$(run '(println [(count (vec (java.math.RoundingMode/values))) (str (first (vec (java.math.RoundingMode/values))))])')" '[8 UP]'
assert_eq 'roundingmode_valueof' "$(run '(println (str (java.math.RoundingMode/valueOf "HALF_UP")))')" 'HALF_UP'
assert_eq 'month_values_count' "$(run '(println (count (java.time.Month/values)))')" '12'
assert_eq 'month_of' "$(run '(println (str (java.time.Month/of 3)))')" 'MARCH'
assert_eq 'dayofweek_of' "$(run '(println (str (java.time.DayOfWeek/of 7)))')" 'SUNDAY'
# values returns the SAME interned constants as the static-field reads
assert_eq 'values_identity' "$(run '(println (identical? (first (vec (java.time.Month/values))) java.time.Month/JANUARY))')" 'true'
# an unknown name / out-of-range value is a catchable value error (clj: IllegalArgumentException / DateTimeException)
assert_eq 'valueof_unknown_catchable' "$(run '(println (try (java.math.RoundingMode/valueOf "NOPE") (catch Exception e :caught)))')" ':caught'
assert_eq 'of_range_catchable' "$(run '(println (try (java.time.Month/of 13) (catch Exception e :caught)))')" ':caught'

# --- Pattern/compile 2-arg (flags) ---
# (str p) must return the ORIGINAL pattern source (JVM Pattern.toString)
assert_eq 'pattern_flags_str' "$(run '(println (str (java.util.regex.Pattern/compile "a" 2)))')" 'a'
assert_eq 'pattern_flags_ci' "$(run '(prn (re-seq (java.util.regex.Pattern/compile "ab" 2) "AB ab"))')" '("AB" "ab")'

# --- File/createTempFile + listRoots ---
assert_eq 'tempfile_roundtrip' "$(run '(println (let [f (java.io.File/createTempFile "cljw" ".txt")] [(.exists f) (.delete f)]))')" '[true true]'
assert_eq 'tempfile_nil_suffix' "$(run '(println (let [f (java.io.File/createTempFile "cljw" nil)] [(.endsWith (.getName f) ".tmp") (.delete f)]))')" '[true true]'
assert_eq 'listroots' "$(run '(println (mapv (fn [f] (.getPath f)) (vec (java.io.File/listRoots))))')" '[/]'

# --- java.time fill (D8) ---
assert_eq 'duration_parse' "$(run '(println (str (java.time.Duration/parse "PT1H30M")))')" 'PT1H30M'
assert_eq 'duration_parse_days' "$(run '(println [(str (java.time.Duration/parse "P1DT2H")) (.getSeconds (java.time.Duration/parse "PT1H"))])')" '[PT26H 3600]'
assert_eq 'duration_parse_neg' "$(run '(println [(str (java.time.Duration/parse "PT-6H")) (str (java.time.Duration/parse "-PT6H")) (str (java.time.Duration/parse "PT-0.5S"))])')" '[PT-6H PT-6H PT-0.5S]'
assert_eq 'duration_of_unit' "$(run '(println (str (java.time.Duration/of 90 java.time.temporal.ChronoUnit/MINUTES)))')" 'PT1H30M'
assert_eq 'localdate_ofepochday' "$(run '(println [(str (java.time.LocalDate/ofEpochDay 0)) (str (java.time.LocalDate/ofEpochDay 19723))])')" '[1970-01-01 2024-01-01]'
assert_eq 'localtime_ofsecondofday' "$(run '(println (str (java.time.LocalTime/ofSecondOfDay 43200)))')" '12:00'

echo "ALL PASS"
