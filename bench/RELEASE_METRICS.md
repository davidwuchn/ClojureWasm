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

| Build (`-Dwasm` — the SHIPPED config, embedded zwasm JIT engine included) | On-disk (build-stripped)      | CLI-strip floor |
|---------------------------------------------------------------------------|-------------------------------|------------------|
| **ReleaseSafe** — the release build                                      | **6.97 MB** (6,974,584 bytes) | 7.01 MB (CLI strip is a no-op here) |
| ReleaseSmall — the size floor (safety checks off; NOT shipped)           | 3.55 MB (3,547,336 bytes)     | 3.21 MB (3,213,360 bytes) |

Measured with Zig 0.16.0 for `aarch64-macos` (re-measured **2026-07-16**, after
the ADR-0172 binary-size campaign: 9,469,816 → 6,974,584 bytes, −26.3% in one
campaign — unwind-table strip O-052, envelope-v7 constant pool + flate
regions/sources ADR-0173, zwasm v2.2.1 thunk collapse, sort dedup O-053; the
per-component budget + `size_claims` gate now govern growth). The pre-campaign
2026-06-11 row (no `-Dwasm`, 3.24 MB) predates the always-embedded Wasm engine
and is superseded — the `-Dwasm` build IS the artifact users download. **As of
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
on an Apple M4 Pro (re-measured 2026-07-16, the `-Dwasm` shipped config):

```
≈ 6 ms (6.3 ms ± 0.5 mean), warm filesystem cache
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
