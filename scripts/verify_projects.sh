#!/usr/bin/env bash
# scripts/verify_projects.sh — real-world library regression sweep.
#
# Runs every verified_projects/<lib>/ through cljw using its own deps.edn
# (git-coordinate resolution + the verify.clj exercise). The PRESENCE of a
# verified_projects/<lib>/ dir is the committed claim "this library loads +
# works on cljw"; this script re-checks that claim, so a later change that
# breaks a previously-working lib is caught (the F-010 regression-detection
# role the convergence campaign Stage 1.3 / F-013 ladder feeds).
#
# NETWORK-DEPENDENT (git clone, cached under $CLJW_HOME/gitlibs) — so it is
# NOT part of the per-commit gate (test/run_all.sh). Run it on demand and at
# Phase boundaries (where network is available). The per-commit deps.edn
# mechanism test stays hermetic in test/e2e/phase14_deps_edn.sh (local bare
# repo). See verified_projects/README.md for the convention.
#
# Usage:  bash scripts/verify_projects.sh            # all projects
#         bash scripts/verify_projects.sh medley     # one project (by dir name)
set -uo pipefail
cd "$(dirname "$0")/.."
BIN="$PWD/zig-out/bin/cljw"
[ -x "$BIN" ] || { echo "build cljw first: zig build" >&2; exit 1; }
if ! command -v git >/dev/null 2>&1; then
    echo "SKIP verify_projects: git not on PATH (deps.edn :git/url needs git)"
    exit 0
fi
CACHE="${CLJW_HOME:-$HOME/.cljw}"
filter="${1:-}"
fails=0; n=0
for dir in verified_projects/*/; do
    name="$(basename "$dir")"
    [ -f "$dir/deps.edn" ] && [ -f "$dir/verify.clj" ] || continue
    [ -z "$filter" ] || [ "$filter" = "$name" ] || continue
    n=$((n + 1))
    if out="$(cd "$dir" && CLJW_HOME="$CACHE" timeout 180 "$BIN" verify.clj 2>&1)"; then
        msg="$(printf '%s' "$out" | grep '^OK' | tail -1)"
        echo "PASS $name -> ${msg:-ok}"
    else
        echo "FAIL $name"
        printf '%s\n' "$out" | tail -6 | sed 's/^/    /'
        fails=$((fails + 1))
    fi
done
echo "verified_projects: $((n - fails))/$n passed"
[ "$fails" -eq 0 ]
