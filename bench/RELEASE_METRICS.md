# Release metrics

The number ClojureWasm locks as its headline is **binary size**, because it is
*reproducible*: given a Zig version and target, anyone re-running the build gets
the same bytes. Cold start is reported too, but as a secondary,
machine-dependent figure (it varies with CPU and filesystem cache).

Reproduce both:

```sh
bash bench/release_metrics.sh
```

## Locked figure

| Build (default `cljw`, no `-Dwasm`)          | Shipped (build-stripped)      | CLI-strip floor                 |
|----------------------------------------------|-------------------------------|---------------------------------|
| **ReleaseSafe** — recommended release build | **3.24 MB** (3,392,568 bytes) | 3.25 MB (link-strip is minimal) |
| ReleaseSmall — optimised for size           | 1.80 MB (1,882,616 bytes)     | 1.63 MB (1,707,888 bytes)       |

Measured with Zig 0.16.0 for `aarch64-macos` (re-measured 2026-06-11). **As of
O-008, `build.zig` strips the symbol table from every non-Debug build**
(`.strip = optimize != .Debug`) — so the *installed* `zig-out/bin/cljw` is the
"shipped" column directly, with no separate packaging step (cljw renders error
traces from its own runtime stack, not native symbols, so stripping costs no
diagnostics; Debug stays unstripped for `lldb`). **ReleaseSafe is the
recommended release build** (optimised *with* runtime safety checks), so 3.24 MB
is the honest "what you download" number. For the absolute size floor, a
post-build `strip zig-out/bin/cljw` shaves ReleaseSmall a further ~175 KB to
1.63 MB (Zig's link-time strip is less aggressive than the CLI `strip` for the
ReleaseSmall layout; for ReleaseSafe the link-strip is already minimal). Sizes
are for the default `cljw`; with the optional WebAssembly FFI engine (`-Dwasm`)
the ReleaseSafe build is about **3.64 MB** (3,820,664 bytes — still a single
binary, under 4 MB).

What sits inside that binary: a full Clojure numeric tower (Long→BigInt
promotion, Ratio, BigDecimal), MVCC software transactional memory, agents,
futures/promises/delays, lazy + chunked sequences, transducers,
protocols/records/multimethods, namespaces, a CIDER-compatible nREPL, and ~24
bundled `clojure.*` standard namespaces — plus both a tree-walking interpreter
and a bytecode VM.

## Cold start (secondary, machine-dependent)

End-to-end `cljw -e nil` (process spawn + runtime init + eval), measured on the
ReleaseSafe build with [`hyperfine`](https://github.com/sharkdp/hyperfine) `-N`
on an Apple M4 Pro (re-measured 2026-06-11):

```
≈ 5 ms (4.8 ms ± 0.2 mean), warm filesystem cache
```

This includes loading the AOT-compiled `clojure.core` bootstrap (ADR-0056), so
it is the real time-to-first-eval a user experiences. It is not a stable
cross-machine number — reproduce it on your own hardware with the script above.

## Honesty note

These figures supersede earlier rougher estimates (~600 KB / ~2.5 ms). The
binary grew as the numeric tower, STM, agents, nREPL, protocols, and the bundled
`clojure.*` namespaces landed; ~3.4 MB (ReleaseSafe) is the honest current size
for the full runtime, ~1.6 MB if built purely for size. The point is not a size
record — it is that a from-scratch Clojure runtime with this much of the
language ships as a single small binary that starts in a few milliseconds.
