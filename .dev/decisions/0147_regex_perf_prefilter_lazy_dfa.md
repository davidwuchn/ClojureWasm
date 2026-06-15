# ADR-0147 — Regex perf: borrow-and-adapt the literal-prefilter + lazy-DFA techniques into cljw's Pike-NFA, equivalence-locked (goal = properly incorporate the optimizations, not just beat Python)

- **Status**: **Proposed** (direction-setting; the implementing session refines + stamps
  Accepted after its Devil's-advocate pass — see § Process). Authored 2026-06-15 as
  the next-session bridge (user-directed "腰を据えて … 工夫をしっかり入れ込む").
- **Relates to**: ADR-0031 (regex engine choice — Pike NFA over backtracking, the
  reserved lazy-DFA design `src/runtime/regex/dfa.zig`), ADR-0145 (regex after sieve +
  nested_update, with the cross-lang equivalence audit as the gate — DONE), F-002
  (finished-form: do the optimization properly), F-011 (clj-equivalence — locked by
  the 48-golden corpus), F-015 (completion-grade), the perf campaign §9.2.S /
  memory `perf-beat-python-every-bench`.
- **Audit (the ADR-0145 gate, DONE)**: `private/notes/9.2.S-regex-equivalence-audit.md`
  + `test/diff/clj_corpus/regex_equivalence.txt` (48 goldens, committed = the F-011
  optimization-safe surface).

## Context

`regex_count` (cljw 45ms vs py 26ms = 1.74×) is the last open Python-loser. cljw's
matcher is a **Pike NFA** (Thompson thread-list VM, non-backtracking, ReDoS-immune,
ADR-0031) in `src/runtime/regex/{compile,match,value}.zig`; re-seq is eager (`.clj`).
The cross-lang equivalence audit is done (GO): 48/48 vs clj; cljw's 5 gaps (reluctant
quantifiers, lookbehind, named groups, backrefs, `\A\z\Z`, POSIX `[[:class:]]`) all
**raise NotImplemented (never silently wrong)**.

**User direction (2026-06-15): do this properly.** The goal is NOT "barely beat
Python" — it is to **incorporate the proven fast-regex techniques into cljw's
architecture**, adapting (not using) the Zig/C/Rust references. "どうせやるなら
しっかり." So this ADR sets the *full* approach, staged, rather than the audit's
minimal 3-lever path.

## What the fast engines actually do (research synthesis, 2026-06-15)

Engine families: **backtracking** (PCRE/Python `sre`/Java — feature-rich, ReDoS,
O(2ⁿ)) · **Thompson-NFA / Pike VM** (grep/RE2-fallback/**cljw** — linear, ReDoS-immune,
captures+`\b` are the cost) · **DFA** (RE2/grep/Rust — fastest table-walk, no captures,
O(2ᵐ) build blowup). The fast safe engines (RE2, Rust `regex`/burntsushi, the Zig
`ezi-gex`) layer these techniques, by ROI:

1. **Literal prefilter (biggest practical win)** — extract the pattern's determinable
   leading literal/class and SKIP via fast byte search to candidate positions; run the
   engine only there. `\d+` → memchr/byte-class-scan to the next digit. memchr/Two-Way
   (single literal, SIMD rare-byte), Teddy (multi-literal, `pshufb`), Aho-Corasick (huge
   sets). **This is why Python/Java's `findall` is fast — the prefilter, not the VM.**
2. **Lazy DFA** (RE2/grep core) — build the DFA on-the-fly, cache visited states, fall
   back to NFA on cache thrash. ~DFA speed, no O(2ᵐ) build. cljw's ADR-0031 reserved
   `dfa.zig` for exactly this.
3. **Two-pass for captures** — find match bounds with the fast DFA, extract captures with
   the NFA only inside the matched region.
4. **reverse-DFA two-pass** (ezi-gex) — "prone" patterns (`\w+@\w+`, start-everywhere) use
   forward-end + reverse-leftmost-start; "non-prone consuming loops" (`\w+`, `\d+` — the
   bench) use **anchored-restart on the eager-DFA frozen table** (one pass).
5. **NFA opts** — sparse states + literal tries + UTF-8 minimal DFAs (Daciuk) to kill the
   ε-closure cost that dominates a naive Thompson VM.
6. **SIMD + zero-alloc** — prefilters are SIMD; caller-supplied Scratch (no per-match alloc).

## Decision (Proposed — the approach)

Keep cljw's **Pike NFA as the safe base** (ReDoS-immune, F-011, ADR-0031 — do NOT
reintroduce backtracking) and **incorporate the techniques in stages**, each
**equivalence-locked** by the 48-golden corpus (48/48 after every change) + the diff
oracle, each **measured** (`bench/benchmarks/35_regex_count`):

- **Stage 1 — the supporting shaves** (equivalence-neutral, quick): (a) `seen`
  generation-counter in `match.zig` `tryMatchAt` (O(1) clear vs per-position `@memset`);
  (b) a `rt/re-find-all` Zig primitive backing `re-seq` (one pass, one ThreadList reuse,
  removes the ~10ms `.clj` layer). Audit measured (a) at 45→41.5ms.
- **Stage 2 — the literal/first-byte/class PREFILTER** (the beat-Python lever): extract
  the Program's determinable leading byte-set at compile time (a 256-bit bitmap on the
  `Program`); `findFrom` skips to the next position whose byte is in that set instead of
  restarting `tryMatchAt` everywhere. Disabled when no leading set is determinable
  (`.`/`^`/wide alternation). Equivalence-neutral (only skips provably-non-startable
  positions). Borrow the SIMD byte-scan shape from `ezi-gex/src/engine/memmem.zig` +
  `backends/literal.zig` (rare-byte `@Vector` masks) — re-derive in cljw's Zig 0.16
  idiom; a scalar byte-class scan is the portable floor, SIMD the accelerator.
- **Stage 3 — the lazy DFA** (the structural ceiling, ADR-0031's reserved `dfa.zig`): an
  on-the-fly DFA over the byte automaton with a bounded state cache + NFA fallback;
  anchored-restart for `\w+`/`\d+`-shaped consuming loops (ezi-gex's `auto` routing). This
  is the "しっかり" half — it makes cljw's regex fast across patterns, not just the bench.
  Captures still ride the Pike VM (two-pass: DFA bounds → NFA captures-in-region).
- **NO-GO**: backtracking (ReDoS), a machine-code JIT (ADR-0145 / cross-platform), a
  fully-compiled eager DFA for untrusted patterns (O(2ᵐ) build). Reluctant quantifiers +
  the `compile.zig:22-23` stale lookaround-doc are an optional parity-gap follow-up
  (D-051/D-447), pairing naturally with the engine work.

## Borrow-and-adapt discipline (references, NOT dependencies)

cljw does NOT depend on or vendor any Zig regex lib — it **reads the references for the
algorithm + re-derives** in cljw's own engine (`no_copy_from_v1` spirit extended to OSS
refs; the 48-golden corpus is the F-011 equivalence proof that the re-derivation is
correct). Cloned / available references (`.dev/reference_clones.md` § Perf-reference):

- **`~/Documents/OSS/ezi-gex/`** (cloned 2026-06-15) — a Zig Thompson-NFA engine with
  Literal Prefilter + Lazy/Eager DFA + Teddy + zero-alloc, WASM-compatible. **Targets Zig
  0.17.0-dev — will NOT compile on stable 0.16** (so it is a *source blueprint*, not a
  dependency). The directly-applicable files: `src/engine/memmem.zig` (2-byte rare-byte
  SIMD), `src/engine/teddy.zig`, `src/engine/simd.zig`, `src/engine/backends/{literal,
  dfa,edfa,pikevm,auto}.zig`, `src/engine/redos.zig`.
- **burntsushi `regex-internals`** (https://burntsushi.net/regex-internals/) + the Rust
  `regex-automata` architecture — the authoritative meta-engine design (PikeVM + lazy DFA
  + bounded backtracker + one-pass + literal prefilters + Teddy).
- **RE2** (Google) — the safe-non-backtracking lazy-DFA design (refuses backrefs, like
  cljw). **CPython `Modules/_sre`** (the `SRE_OP_LITERAL` prefix scan) + **OpenJDK
  `java.util.regex`** (`BnM` Boyer-Moore prefilter) — clone on demand.

## Process (the implementing session)

Per the user's workflow preference (2026-06-15): **the main agent does the
design-exploration + measurement DIRECTLY** (read `ezi-gex`/RE2/burntsushi, reason,
measure-first), NOT via a survey/DA fork — premise errors hide in forked summaries (the
ADR-0146 filter-chain lesson: a forked survey propagated a wrong "depth-bound" premise
that direct measurement falsified). Reserve forks for the **well-specified mechanical
implementation** (the build-iterate-test loop, once the design + the prefilter byte-set
extraction are settled by direct reasoning). Each stage: design directly → implement
(self or fork) → diff oracle + corpus 48/48 + bench re-measure → commit. Stamp this ADR
Accepted (with the Devil's-advocate pass on the lazy-DFA structural choice) when Stage 2
or 3 is committed; Stages can land as separate commits under this one ADR.

## Consequences

- The regex unit is a **multi-cycle engine unit** done properly (prefilter → lazy DFA),
  not a one-cycle alloc shave. Stage 2 (prefilter) is the beat-Python milestone; Stage 3
  (lazy DFA) is the "incorporate the optimization" goal (fast across patterns).
- F-011 is held by the 48-golden corpus (48/48 after every change) + the diff oracle.
  cljw stays ReDoS-immune (no backtracking) and cross-platform (no machine code).
- New tracked refs: `ezi-gex` cloned; ADR-0031's `dfa.zig` finally built in Stage 3.
- A follow-up debt **D-447** (regex parity gaps: reluctant quantifiers / lookbehind /
  named groups / backrefs / `\A\z\Z` / POSIX classes — currently NotImplemented) is the
  home for the equivalence gaps the perf work does not need but can opportunistically
  close (reluctant quantifiers pair with the engine work).

## Affected files (the implementing session)

- `src/runtime/regex/match.zig` (seen-gen, the prefilter byte-scan in `findFrom`),
  `compile.zig` (leading byte-set extraction onto `Program` + the stale doc fix),
  `dfa.zig` (Stage 3 lazy DFA), `value.zig`.
- `src/lang/primitive/regex.zig` + `src/lang/clj/clojure/core.clj` (`rt/re-find-all` +
  re-seq re-point).
- `test/diff/clj_corpus/regex_equivalence.txt` (extend as gaps close, anti-D-177) +
  `.dev/optimizations.md` (O-NNN rows). `.dev/debt.yaml` D-447 (parity gaps).
