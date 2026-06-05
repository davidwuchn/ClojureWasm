# Contributing to ClojureWasm

Thanks for your interest. ClojureWasm is an early-stage runtime, so the most
useful contributions right now are **bug reports** (especially behavioural
differences from JVM Clojure) and **small, focused fixes**.

## Reporting a divergence from Clojure

ClojureWasm targets behavioural equivalence with JVM Clojure on the
user-observable surface. If you find an expression that behaves differently:

1. Check whether it is already a known, intentional difference in
   [`docs/clojure_vs_clojurewasm.md`](./docs/clojure_vs_clojurewasm.md).
2. If not, open an issue with the expression, what `cljw` prints, and what a
   JVM Clojure REPL prints.

## Working on the code

```sh
direnv allow            # one-time: load Zig 0.16.0 via Nix (or: nix develop)
zig build               # build the `cljw` binary
bash test/run_all.sh    # the full test suite must be green before a change lands
```

The project follows a TDD loop (red → green → refactor) and keeps tests green on
every commit. The development workflow, design principles, and the amendment
process for the roadmap are documented in [`CLAUDE.md`](./CLAUDE.md) and
[`.dev/`](./.dev/) (ROADMAP, decision records, principles). Load-bearing
decisions are recorded as ADRs under [`.dev/decisions/`](./.dev/decisions/).

A note on provenance: much of this codebase is written by an autonomous
development loop under written guardrails and ADR discipline. Human review and
direction set the rails; contributions from people are very welcome and reviewed
the same way.

## Getting in touch

Questions and discussion are welcome on the
[Clojurians Slack](https://clojurians.slack.com).

## License

By contributing, you agree that your contributions are licensed under the
Eclipse Public License 2.0 (see [LICENSE](./LICENSE)).
