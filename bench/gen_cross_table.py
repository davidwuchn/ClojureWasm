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
        # `wasm_*` workloads are cljw-FFI-only (no other-language source) — they
        # belong to the wasm harness (wasm_bench.sh), NOT the cross-language table,
        # where they would render as a cljw-only row with every other column "—".
        # Excluded here so the table stays cross-language-comparable regardless of
        # whether the source YAML carries them (compare_langs.sh runs every dir).
        if name.startswith("wasm_"):
            continue
        cells = {}
        for lang, ms in ((modes or {}).get(mode) or {}).items():
            nl = norm(lang)
            cells[nl] = ms
            present.add(nl)
        if "cw" in cells:
            rows[name] = cells
    return rows, present


def us(ms):
    """ms (the yaml's native unit) → integer microseconds for display."""
    return f"{round(float(ms) * 1000)}"


def render_table(rows, present):
    cols = [l for l in LANG_ORDER if l in present]
    lines = ["| Benchmark | " + " | ".join(DISPLAY[l] for l in cols) + " |",
             "|" + "---|" * (len(cols) + 1)]
    for name, cells in rows.items():
        vals = [(us(cells[l]) if cells.get(l) is not None else "—") for l in cols]
        lines.append(f"| {name} | " + " | ".join(vals) + " |")
    return lines


def render_startup(startup):
    """One-row µs table of per-language process-spawn + runtime-init time — the
    fixed overhead the warm table subtracts out."""
    norm_su = {norm(k): v for k, v in startup.items()}
    cols = [l for l in LANG_ORDER if l in norm_su]
    if not cols:
        return []
    header = "| Startup (µs) | " + " | ".join(DISPLAY[l] for l in cols) + " |"
    sep = "|" + "---|" * (len(cols) + 1)
    vals = [us(norm_su[l]) for l in cols]
    return [header, sep, "| process spawn + init | " + " | ".join(vals) + " |"]


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

    # Conditions up front: machine + the hyperfine settings the numbers were
    # measured under (runs/warmup must be visible at a glance).
    conditions = (
        f"**Conditions:** {env.get('machine', '?')}, {env.get('cpu', '?')}, "
        f"{env.get('ram', '?')} RAM, {env.get('os', '?')}, "
        f"hyperfine **{env.get('warmup', '?')} warmup + {env.get('runs', '?')} runs**, {date}.")

    # Cold-start only, on purpose. Cold-start = end-to-end wall-clock (process
    # launch → exit), the one metric that compares uniformly across languages.
    # We deliberately do NOT publish a startup-subtracted "compute" table: for
    # the fast (compiled) languages the per-run compute is far below process-
    # spawn noise (~3 ms ± 10%), so subtracting startup yields noise, not signal.
    why = ("_Cold-start = process launch → exit (startup included). Only "
           "cold-start is shown: it is the metric that compares uniformly across "
           "languages. A startup-subtracted compute number is omitted because, "
           "for the fast languages, compute sits below process-spawn noise._")

    print(conditions)
    print()
    print(why)
    print()
    print("#### Cold-start wall-clock (µs, lower is better)")
    print()
    print("\n".join(render_table(cold_rows, cold_present)))

    # Warm / startup tables are emitted ONLY if the yaml carries that data
    # (compare_langs.sh --both). The default --cold run omits them by design.
    if warm_rows:
        print()
        print("#### Warm — startup subtracted (µs, lower is better)")
        print()
        print("\n".join(render_table(warm_rows, warm_present)))

    startup_lines = render_startup(data.get("startup_ms", {}))
    if startup_lines:
        print()
        print("#### Startup — process spawn + runtime init (µs, lower is better)")
        print()
        print("\n".join(startup_lines))

    if warm_rows:
        print()
        print("_Warm = cold − startup; digits below startup-measurement noise "
              "are indicative._")


if __name__ == "__main__":
    main()
