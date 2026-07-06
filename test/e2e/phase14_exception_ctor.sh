#!/usr/bin/env bash
# test/e2e/phase14_exception_ctor.sh
#
# D-198 / clj-parity C5: host-class Throwable-family CONSTRUCTORS —
# `(Exception. msg)` / `(RuntimeException. msg)` / `(Throwable. msg)`. cljw
# has no JVM class hierarchy (ADR-0059), so each mints an `.ex_info` tagged
# with the class name (ex_info bridge, ADR-0060); throw/catch/getMessage +
# the isSubclassOf hierarchy + instance? all work. `.getMessage`/catch were
# the earlier partial discharge; this adds the constructors.
#
# Layer 2 (e2e CLI) per ADR-0021.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
assert_eq() { local n="$1" g="$2" w="$3"; [[ "$g" == "$w" ]] || fail "$n: got '$g' want '$w'"; echo "PASS $n -> $w"; }

# Constructors + .getMessage.
assert_eq 'exc_msg'   "$("$BIN" -e '(.getMessage (Exception. "x"))')"          '"x"'
assert_eq 'rte_msg'   "$("$BIN" -e '(.getMessage (RuntimeException. "r"))')"   '"r"'
assert_eq 'thr_msg'   "$("$BIN" -e '(.getMessage (Throwable. "t"))')"          '"t"'

# throw → catch (by own class, by superclass, by Throwable).
assert_eq 'catch_self'  "$("$BIN" -e '(try (throw (Exception. "boom")) (catch Exception e (.getMessage e)))')" '"boom"'
assert_eq 'catch_super' "$("$BIN" -e '(try (throw (RuntimeException. "r")) (catch Exception e (.getMessage e)))')" '"r"'
assert_eq 'catch_thr'   "$("$BIN" -e '(try (throw (Exception. "e")) (catch Throwable e (.getMessage e)))')" '"e"'

# instance? rides the isSubclassOf hierarchy.
assert_eq 'inst_exc'  "$("$BIN" -e '(instance? Exception (Exception. "x"))')"   'true'
assert_eq 'inst_thr'  "$("$BIN" -e '(instance? Throwable (RuntimeException. "r"))')" 'true'
assert_eq 'inst_rte'  "$("$BIN" -e '(instance? RuntimeException (Exception. "x"))')" 'false'

# D-213: (class e) reports the value's SPECIFIC exception class (simple name
# per AD-003), not a generic "ex_info". ex-info → ExceptionInfo; ctor classes;
# caught catalog errors carry their Kind-derived class.
assert_eq 'cls_exinfo' "$("$BIN" -e '(str (class (ex-info "m" {})))')"          '"ExceptionInfo"'
assert_eq 'cls_exc'    "$("$BIN" -e '(str (class (Exception. "x")))')"          '"Exception"'
assert_eq 'cls_rte'    "$("$BIN" -e '(str (class (RuntimeException. "r")))')"   '"RuntimeException"'
assert_eq 'cls_div0'   "$("$BIN" -e '(try (/ 1 0) (catch Throwable e (str (class e))))')" '"ArithmeticException"'
assert_eq 'cls_nth'    "$("$BIN" -e '(try (nth [] 5) (catch Throwable e (str (class e))))')" '"IndexOutOfBoundsException"'
# Distinct exception types → distinct classes; same type → one interned class.
assert_eq 'cls_same'   "$("$BIN" -e '(= (class (ex-info "a" {})) (class (ex-info "b" {})))')" 'true'
assert_eq 'cls_diff'   "$("$BIN" -e '(= (class (Exception. "x")) (class (RuntimeException. "y")))')" 'false'

# D-425: the common java.lang throwable-subtype ctors (exception_ctors.zig
# comptime family). Each `(X. msg)` mints an .ex_info tagged X; catch routes via
# the hierarchy; (X. msg cause) carries the cause.
assert_eq 'iae_msg'  "$("$BIN" -e '(.getMessage (IllegalArgumentException. "bad"))')"        '"bad"'
assert_eq 'ise_msg'  "$("$BIN" -e '(.getMessage (IllegalStateException. "st"))')"            '"st"'
assert_eq 'uoe_msg'  "$("$BIN" -e '(.getMessage (UnsupportedOperationException. "no"))')"    '"no"'
assert_eq 'npe_msg'  "$("$BIN" -e '(.getMessage (NullPointerException. "np"))')"             '"np"'
assert_eq 'ioobe_msg' "$("$BIN" -e '(.getMessage (IndexOutOfBoundsException. "ix"))')"       '"ix"'
assert_eq 'ae_msg'   "$("$BIN" -e '(.getMessage (ArithmeticException. "ar"))')"              '"ar"'
assert_eq 'cce_msg'  "$("$BIN" -e '(.getMessage (ClassCastException. "cc"))')"               '"cc"'
assert_eq 'nfe_msg'  "$("$BIN" -e '(.getMessage (NumberFormatException. "nf"))')"            '"nf"'
# catch via the parent hierarchy (IllegalArgumentException < RuntimeException < Exception).
assert_eq 'iae_as_rte' "$("$BIN" -e '(try (throw (IllegalArgumentException. "x")) (catch RuntimeException e (.getMessage e)))')" '"x"'
assert_eq 'ise_as_thr' "$("$BIN" -e '(try (throw (IllegalStateException. "y")) (catch Throwable e (.getMessage e)))')" '"y"'
# (X. msg cause) — the cause chains.
assert_eq 'iae_cause' "$("$BIN" -e '(.getMessage (.getCause (IllegalArgumentException. "o" (RuntimeException. "in"))))')" '"in"'
# (class e) reports the specific subtype (AD-003 simple name).
assert_eq 'cls_iae'  "$("$BIN" -e '(str (class (IllegalArgumentException. "x")))')" '"IllegalArgumentException"'
# instance? rides the hierarchy: an IllegalArgumentException IS a RuntimeException.
assert_eq 'inst_iae_rte' "$("$BIN" -e '(instance? RuntimeException (IllegalArgumentException. "x"))')" 'true'

# str vs pr-str of an exception (D-433): `(str ex)` / `(.toString ex)` = the
# readable Throwable.toString one-liner `<class>: <message>` (AD-003 simple
# name — clj prints the FQCN); a real ex-info appends the data map (clj
# ExceptionInfo.toString). `pr-str` keeps the `#error{…}` data literal.
assert_eq 'str_exc'       "$("$BIN" -e '(str (Exception. "boom"))')"              '"Exception: boom"'
assert_eq 'tostr_exc'     "$("$BIN" -e '(.toString (Exception. "boom"))')"        '"Exception: boom"'
assert_eq 'str_iae'       "$("$BIN" -e '(str (IllegalArgumentException. "x"))')"  '"IllegalArgumentException: x"'
assert_eq 'str_exinfo'    "$("$BIN" -e '(str (ex-info "boom" {:a 1}))')"          '"ExceptionInfo: boom {:a 1}"'
assert_eq 'prstr_exinfo'  "$("$BIN" -e '(pr-str (ex-info "boom" {:a 1}))')"       '"#error{:message \"boom\" :data {:a 1}}"'
assert_eq 'prstr_exc'     "$("$BIN" -e '(pr-str (Exception. "boom"))')"           '"#error{:message \"boom\" :data nil}"'

echo "ALL phase14_exception_ctor PASS"
