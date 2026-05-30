#!/usr/bin/env bash
# e2e: clojure.core/eval (D-162 / ADR-0058)
# Proves eval reaches BOTH the runtime evaluator AND the built-in macro
# table (when / -> / and expand inside eval'd forms).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLJW="$ROOT/zig-out/bin/cljw"

pass=0
fail=0

check() {
  local desc="$1" expr="$2" want="$3"
  local got
  got="$("$CLJW" -e "$expr" 2>&1)" || true
  if [[ "$got" == "$want" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
    echo "  expr: $expr"
    echo "  want: $want"
    echo "  got:  $got"
  fi
}

# Motivating case: read-string then eval.
check "eval read-string arithmetic" '(eval (read-string "(+ 1 2)"))' '3'
# Self-evaluating literals round-trip through valueToForm.
check "eval self-eval int"     '(eval 42)' '42'
check "eval self-eval keyword" '(eval :kw)' ':kw'
check "eval self-eval vector"  '(eval [1 2 3])' '[1 2 3]'
# Constructed list with a quoted symbol head.
check "eval constructed list" '(eval (list (symbol "+") 1 2 3))' '6'
# Special form inside eval.
check "eval special form if" '(eval (quote (if true :yes :no)))' ':yes'
# THE structural proof: built-in Zig macros must expand inside eval
# (this is why eval needs the macro_table, not just env).
check "eval built-in macro when" '(eval (quote (when true 7)))' '7'
check "eval built-in macro ->"   '(eval (quote (-> 5 inc inc)))' '7'
check "eval built-in macro and"  '(eval (quote (and 1 2 3)))' '3'
# Nested eval.
check "eval nested" '(eval (quote (eval (quote (+ 4 5)))))' '9'

echo "pass=$pass fail=$fail"
if [[ $fail -gt 0 ]]; then exit 1; fi
