#!/usr/bin/env bash
# test/e2e/phase14_deps_edn.sh
#
# Convergence Campaign Stage 1.2 — deps.edn source resolution.
# A `./deps.edn` in the working directory contributes its `:paths` and
# `:local/root` deps to the front of the require classpath; `:mvn/version`
# is rejected (ClojureWasm resolves source-only). Layer 2 (e2e CLI).

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="$(pwd)/zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }
last_line() { printf '%s' "$1" | tail -1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Case 1: :paths makes a ns under src/ requirable ---
proj="$WORK/proj1"; mkdir -p "$proj/src/myproj"
printf '{:paths ["src"]}\n' > "$proj/deps.edn"
printf '(ns myproj.core)\n(defn greet [] "hello-deps")\n' > "$proj/src/myproj/core.clj"
got="$(cd "$proj" && "$BIN" -e "(require 'myproj.core) (myproj.core/greet)" 2>/dev/null)"
[[ "$(last_line "$got")" == '"hello-deps"' ]] || fail "paths: got '$(last_line "$got")'"
echo "PASS deps_paths -> hello-deps"

# --- Case 2: control — without deps.edn the same src/ tree is NOT on the path ---
ctrl="$WORK/ctrl"; mkdir -p "$ctrl/src/myproj"
printf '(ns myproj.core)\n(defn greet [] "x")\n' > "$ctrl/src/myproj/core.clj"
if (cd "$ctrl" && "$BIN" -e "(require 'myproj.core)" >/dev/null 2>&1); then
    fail "control: require unexpectedly succeeded without deps.edn :paths"
fi
echo "PASS deps_control_no_edn -> require fails (proves :paths drove it)"

# --- Case 3: :local/root pulls in a sibling lib's :paths transitively ---
mono="$WORK/mono"; mkdir -p "$mono/app/src/app" "$mono/lib/src/lib"
printf '(ns lib.util)\n(defn tag [] "from-lib")\n' > "$mono/lib/src/lib/util.clj"
printf '{:paths ["src"]}\n' > "$mono/lib/deps.edn"
printf '{:paths ["src"] :deps {lib/lib {:local/root "../lib"}}}\n' > "$mono/app/deps.edn"
printf '(ns app.main)\n' > "$mono/app/src/app/main.clj"
got="$(cd "$mono/app" && "$BIN" -e "(require 'lib.util) (lib.util/tag)" 2>/dev/null)"
[[ "$(last_line "$got")" == '"from-lib"' ]] || fail "local-root: got '$(last_line "$got")'"
echo "PASS deps_local_root -> from-lib"

# --- Case 4: :mvn/version is rejected with a source-only hint, exit 1 ---
mvn="$WORK/mvn"; mkdir -p "$mvn"
printf '{:deps {x/y {:mvn/version "1.0"}}}\n' > "$mvn/deps.edn"
err="$(cd "$mvn" && "$BIN" -e "(+ 1 1)" 2>&1 1>/dev/null)" && fail "mvn: expected non-zero exit"
case "$err" in
    *":git/url"*) echo "PASS deps_mvn_reject -> source-only hint" ;;
    *) fail "mvn: message lacks :git/url hint: $err" ;;
esac

echo "ALL phase14_deps_edn PASS"
