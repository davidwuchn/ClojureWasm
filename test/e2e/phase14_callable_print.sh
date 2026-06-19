#!/usr/bin/env bash
# test/e2e/phase14_callable_print.sh
#
# ADR-0121 / D-328 / AD-025 — callable values (fn / defmulti / protocol method
# fn) print their qualified name as `#<ns/name>` (`#<fn>` when unnamed), the
# AD-002 `#<…>` envelope filled with the name instead of the leaked internal tag
# (`#<fn_val>`). `str` and `pr` render identically (clj agrees). This is the
# AD-025 pin test.

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }

# --- Case fn_named: a named fn prints #<ns/name>, not #<fn_val> ---
out=$(printf '(defn boom [] 1)\n(println (pr-str boom))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"#<fn_val>"*) fail "fn_named: leaked internal tag #<fn_val>: '$out'" ;;
    *"#<user/boom>"*) echo "PASS callable_fn_named -> #<user/boom>" ;;
    *) fail "fn_named: expected #<user/boom>, got '$out'" ;;
esac

# --- Case fn_anon: an anonymous fn prints a name (#<user/fn__N> or #<fn>) ---
out=$(printf '(println (pr-str (fn [] 1)))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"#<fn_val>"*) fail "fn_anon: leaked internal tag #<fn_val>: '$out'" ;;
    *"#<"*) echo "PASS callable_fn_anon -> $(printf '%s' "$out" | tr -d '\n')" ;;
    *) fail "fn_anon: expected a #<…> form, got '$out'" ;;
esac

# --- Case defmulti: a multimethod prints its name, not #<multi_fn> ---
out=$(printf '(defmulti area :shape)\n(println (pr-str area))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"#<multi_fn>"*) fail "defmulti: leaked internal tag #<multi_fn>: '$out'" ;;
    *"#<area>"*|*"#<user/area>"*) echo "PASS callable_defmulti -> $(printf '%s' "$out" | tr -d '\n')" ;;
    *) fail "defmulti: expected #<area>/#<user/area>, got '$out'" ;;
esac

# --- Case builtin_named (D-327): a builtin prints its qualified name #<rt/+>,
# not the nameless internal tag #builtin (the home ns is rt — matches
# (resolve '+) => #'rt/+). clj prints #object[clojure.core$_PLUS_ …] = AD-025. ---
out=$(printf '(println (pr-str +))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"#builtin"*) fail "builtin_named: leaked nameless #builtin: '$out'" ;;
    *"#<rt/+>"*) echo "PASS callable_builtin_named -> #<rt/+>" ;;
    *) fail "builtin_named: expected #<rt/+>, got '$out'" ;;
esac

# --- Case builtin_inc: another builtin names cleanly ---
out=$(printf '(println (pr-str inc))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"#<rt/inc>"*) echo "PASS callable_builtin_inc -> #<rt/inc>" ;;
    *) fail "builtin_inc: expected #<rt/inc>, got '$out'" ;;
esac

# --- Case builtin_str_eq_pr: (str +) and (pr-str +) render identically ---
out=$(printf '(println (= (str +) (pr-str +)))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"true"*) echo "PASS callable_builtin_str_eq_pr -> str matches pr" ;;
    *) fail "builtin_str_eq_pr: expected true, got '$out'" ;;
esac

# --- Case str_eq_pr: (str fn) and (pr-str fn) render identically (clj agrees) ---
out=$(printf '(defn boom [] 1)\n(println (= (str boom) (pr-str boom)))\n' | "$BIN" - 2>&1 || true)
case "$out" in
    *"true"*) echo "PASS callable_str_eq_pr -> str matches pr" ;;
    *) fail "str_eq_pr: expected true, got '$out'" ;;
esac

echo
echo "ADR-0121 / AD-025 callable print e2e: all green."
