#!/usr/bin/env bash
# check_tier_d_error_msg.sh — pre-commit gate.
# Verifies Tier D forms / fns produce structured error messages
# referencing the rationale ADR.
#
# Active phase: 6. Tier D error messages are landed inline at each
# `tier_d_*` Code in src/runtime/error/catalog.zig per ADR-0018
# amendment 2. Promotion to gate deferred until a real drift surfaces;
# script stays informational meanwhile.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
YAML="$REPO_ROOT/data/compat_tiers.yaml"

# Expected format: each Tier D Code in error_catalog.zig carries a
# multi-sentence hand-written template (ADR-0018 amendment 2). A full
# grep gate could verify presence of `tier_d_*` Code variants vs
# compat_tiers.yaml; deferred until needed.
echo "[check_tier_d_error_msg] informational mode; full template-presence check is a future cycle."
exit 0
