#!/usr/bin/env python3
"""Generate the cross-language benchmark Markdown tables from compare_langs.sh's
--yaml output. The bench/README.md cross-lang tables are GENERATED, never
hand-maintained (v0's hand-curated table drifted from meta.yaml — see
private/notes/v0-bench-survey.md). This writes ONLY into bench/README.md, never
the repository-root README.md.

Usage:
    yq -o=json bench/cross-lang-latest.yaml | python3 bench/gen_cross_table.py
    # or
    python3 bench/gen_cross_table.py bench/cross-lang-latest.json

Emits a Markdown fragment on stdout: a Cold table (startup included) and, when the
YAML carries warm data (compare_langs.sh --both), a Warm table (startup-subtracted)
— both honestly, since neither number alone tells the whole story. Pipe through
`md-table-align` (or let the commit hook align) before committing.
"""
import json
import sys

# Column order is deliberate, not a leaderboard. cljw is the subject (first).
# Then the interpreter peers it actually compares against — Python, Ruby,
# Node.js, and Babashka (a fellow JVM-free Clojure). cljw and Babashka are NOT
# placed adjacent: out of respect, and because the honest peer set is
# "interpreters", not a head-to-head. The compiled baselines (Java JIT, Go gc,
# C native) come last as a reference floor — a script-vs-compiled gap is
# expected, not a verdict. TinyGo and Zig are intentionally NOT here: TinyGo is
# a Go variant (redundant with standard Go) whose role is the wasm comparison
# (wasm_bench.sh), and Zig — cljw's own implementation language — only restates
# the native floor C already provides. A lang absent from the data is dropped.
LANG_ORDER = ["cw", "python", "ruby", "node", "bb", "java", "go", "c"]
DISPLAY = {
    "cw": "ClojureWasm", "python": "Python", "ruby": "Ruby", "node": "Node.js",
    "bb": "Babashka", "java": "Java", "go": "Go", "c": "C",
    "tgo": "TinyGo", "zig": "Zig",
}
# compare_langs.sh writes either short (py/rb/js) or long (python/ruby/node)
# lang keys depending on version; normalise both to our canonical keys.
ALIAS = {"py": "python", "rb": "ruby", "js": "node", "clojurewasm": "cw"}


def norm(lang):
    return ALIAS.get(lang, lang)


def collect(benches, mode):
    """rows[name] = {lang: ms}, plus the set of langs present, for one mode."""
    rows, present = {}, set()
    for name, modes in benches.items():
        cells = {}
        for lang, ms in ((modes or {}).get(mode) or {}).items():
            nl = norm(lang)
            cells[nl] = ms
            present.add(nl)
        if "cw" in cells:
            rows[name] = cells
    return rows, present


def render_table(rows, present):
    cols = [l for l in LANG_ORDER if l in present]
    lines = ["| Benchmark | " + " | ".join(DISPLAY[l] for l in cols) + " |",
             "|" + "---|" * (len(cols) + 1)]
    for name, cells in rows.items():
        vals = [(f"{float(cells[l]):g}" if cells.get(l) is not None else "—") for l in cols]
        lines.append(f"| {name} | " + " | ".join(vals) + " |")
    return lines


def main():
    raw = (open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read())
    data = json.loads(raw)
    benches = data.get("benchmarks", {})
    env = data.get("env", {})
    date = data.get("date", "")

    cold_rows, cold_present = collect(benches, "cold")
    warm_rows, warm_present = collect(benches, "warm")
    if "cw" not in cold_present:
        sys.exit("no cw cold data in yaml — nothing to table")

    env_line = (f"{env.get('cpu', '?')}, {env.get('os', '?')}, "
                f"hyperfine runs={env.get('runs', '?')}/warmup={env.get('warmup', '?')}, {date}")

    print("#### Cold-start wall-clock — startup included (ms, lower is better)")
    print()
    print("\n".join(render_table(cold_rows, cold_present)))

    if warm_rows:
        print()
        print("#### Warm — startup subtracted (ms, lower is better)")
        print()
        print("\n".join(render_table(warm_rows, warm_present)))

    print()
    print(f"_{env_line}. Columns: ClojureWasm, then its interpreter peers "
          f"(Python / Ruby / Node.js / Babashka), then compiled baselines "
          f"(Java / Go / C) as a reference floor — not a leaderboard._")


if __name__ == "__main__":
    main()
