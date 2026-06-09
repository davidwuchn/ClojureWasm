#!/usr/bin/env bash
# scripts/check_clj_attribution.sh
#
# PreToolUse hook on Bash that physically blocks `git commit` when any
# Clojure-namespace source file in the working tree lacks the EPL-2.0
# attribution header. Enforces .claude/rules/clj_attribution.md (D-366):
# every `src/lang/clj/clojure/**/*.clj` MUST carry
# `SPDX-License-Identifier: EPL-2.0` (both header variants ① upstream-text
# banner and ② independent-reimpl carry this single line, so one check
# guarantees both).
#
# Scope: src/lang/clj/clojure/ only. The `src/lang/clj/cljw/` namespaces
# are ClojureWasm-original and intentionally out of scope (no upstream
# lineage). `.zig` is clean-room; the import-relationship NOTICE covers
# the tree-level attribution.
#
# Why a working-tree (not staged-diff) check: a new clojure ns can be
# added untracked and committed in one step; scanning the working tree
# with `find` catches both tracked and untracked `.clj` so a header-less
# file can never slip in. This is the deterministic enforcement layer
# behind the probabilistic CLAUDE.md / clj_attribution.md rule.
#
# Safe no-op for any non-`git commit` Bash invocation.

set -euo pipefail

source "$(dirname "$0")/hook_lib.sh"

hook_read_command
hook_is_git_commit || exit 0
hook_cd_project_root

CLJ_DIR="src/lang/clj/clojure"
[[ -d "$CLJ_DIR" ]] || exit 0

# Working-tree sweep: every .clj under clojure/ (tracked or not). `find`
# avoids the `git ls-files 'clojure/**/*.clj'` pitfall — that glob misses
# the top-level clojure/*.clj files (pathspec `**` does not match a single
# path segment), so it would silently skip core.clj/set.clj/edn.clj/etc.
missing=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -q 'SPDX-License-Identifier: EPL-2.0' "$f"; then
    missing+=("$f")
  fi
done < <(find "$CLJ_DIR" -type f -name '*.clj' | sort)

if [[ ${#missing[@]} -eq 0 ]]; then
  exit 0
fi

cat >&2 <<'EOF'
✗ commit blocked by scripts/check_clj_attribution.sh

One or more Clojure-namespace source files under src/lang/clj/clojure/
are missing the EPL-2.0 attribution header.

Required first-line marker (both header variants carry it):
    ;; SPDX-License-Identifier: EPL-2.0

To recover, prepend the standard header from
.claude/rules/clj_attribution.md (B-1 of the D-366 work order):
  - variant ② (independent reimplementation — the common case): the
    4-line CW-copyright header citing the upstream namespace lineage.
  - variant ① (upstream source text reproduced — template.clj and
    core/protocols.clj only): the upstream EPL banner.

Files missing the header:
EOF
printf '  %s\n' "${missing[@]}" >&2

cat >&2 <<'EOF'

(Rule: .claude/rules/clj_attribution.md. Discovery recipe:
  find src/lang/clj/clojure -name '*.clj' | xargs grep -L 'SPDX-License-Identifier: EPL-2.0'
Discipline source: D-366 license attribution; framework_completion.md
requires the rule + this hook to land in the same cycle as the retrofit.)
EOF

exit 2
