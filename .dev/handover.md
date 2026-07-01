# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; tip `ac1b883c`). Per-commit = smoke; commit
  **and** push (atomic Step 6). `build.zig.zon` `.zwasm` = tag pin `v2.0.0-alpha.3`.
- **ACTIVE CAMPAIGN (2026-07-01, user-directed): 1.0.0-rc.1 release readiness
  (ADR-0167).** Full-scope A+B, fully autonomous. Drive the finite Track-A gate
  below + the parallel Track-B (ADR-0166 D-522…D-529) quality drain. The final
  version bump + `git tag` is **USER-OWNED** (build.zig.zon SSOT; loop never tags).
- **rc.1 readiness gate (FINITE — the tag-cut SSOT):** D-537/539/540/541/542/543
  DONE (see `discharged:`); **D-544** (CI reproducibility+efficiency) = the one
  OPEN loop item — needs green CI re-verify. USER-OWNED residuals: settings.json
  `additionalDirectories` move (`.claude/`-blocked), zwasm-pin bump (CODEV), and
  the final `.version` bump + `git tag` (loop NEVER tags).
- **Track B (parallel, non-blocking for the tag):** the easiest-first `active:`
  drain continues — D-522 de-pointer / D-523 doc-audit / D-526 interop / D-527
  parity / D-528 real-deps.edn / D-529 / D-305 / D-470 / D-222 / D-460 / D-439 sqrt.
  A correctness / clj-parity floor still PREEMPTS.
- **Forbidden this session**: bare `zig build test` WITHOUT `-Dwasm`; bare `zig build`
  for a probe (use ReleaseSafe). **The FULL gate MUST run `--serial-e2e`** — the `-P8`
  parallel default flakes the **D-418/D-258 agent load-race** (`agent_conj` →
  `[#<promise> 2]`; green isolated/serial, NOT a regression). **Never run a concurrent
  build during a gate** (host contention → false timeout). `.claude/**` edits may hit
  the auto-mode self-modification block — surface those to the user.

## Last landed (git log = SSOT)

Easiest-first `active:` drain (2026-06-25): **D-472** `bytes?` (over-broad = `array?`
per AD-051, type-erasure-forced; DA-fork recommended always-false, overridden by a
probe). **D-480** `instance? Serializable` (last deferred marker; clj-oracle all tags,
`multi_fn` EXCLUDED — MultiFn is not AFunction). **D-439** BigDecimal `scaleByPowerOfTen`/
`ulp`/`divideAndRemainder`. **D-532** BigInteger `.add/.subtract/.multiply/.divide` (new
`allocDivTruncManaged` — trunc-toward-zero). **D-471** slurp/spit accept a `java.io.File`
arg (R4-clean coerceToPath). **D-511** exact `(BigDecimal. double)` ctor (reuses
`allocFromRatioParts`). **D-535** opened (user-directed): Java-interop import-gating
parity — the Java analogue of D-516/ADR-0163, deferred to the import-semantics owner
alongside D-461.

## Standing units (tracked in .dev/debt.yaml)

- **Perf campaign (§9.2.S) — PAUSED** (cheap levers exhausted; D-520 / D-386 / D-005/006).
- **D-439 sqrt(MathContext)** — the one BigDecimal remnant; a focused numeric cycle
  (correct rounding ×8 modes + JDK preferred output scale; base = the native Managed.sqrt).
- **D-513** — clojure.core.reducers / clojure.repl / var :doc (foundational).
- **D-418/D-258** — agent send/await + GC load-race (open, recall-trigger; re-gate serial).

## North star (ACTIVE, distal)

cljw's differentiator = **Wasm/edge-native (gap II) × VM-perf fusion→JIT (gap III)**.
zwasm JIT (ADR-0200) is the cljw default; remaining = components-through-the-JIT
(zwasm-side, D-500). Distal — needs a user nod; the §9.2.T public-ization sweep
(easiest-first debt drain) is the active near-term mode.

## Reading order (resume)

handover → **`private/notes/2026-06-25-debt-drain-order.md`** (easiest-first snapshot)
→ `yq` the live `active:` list → **ADR-0166** (public-ization sweep mode) → ROADMAP
§9.2.T. Memories: `verify_against_releasesafe_binary` / `smoke_first_batch_full_gate` /
`gate_parallel_e2e_timeout`.

## This session (2026-07-01) — rc.1 publicization campaign

Not the usual loop — plan + execute the 1.0.0-rc.1 publicization (zwasm v2 S0…S7
as template). Full scope, fully autonomous. LANDED + PUSHED: **ADR-0167** +
debt **D-536…D-543** + ROADMAP §9.2.T; **D-537** health files; **D-539** CI
wiring + repo `zig fmt`-clean; **D-540** CHANGELOG/THIRD_PARTY/attrs; **D-541**
version staging; **D-542** release.yml; **D-543** dep-pin; **D-538** env
decoupling (loop part); **D-536** down-payment. Local full gate 398/0.

**In-flight (uncommitted at note time — batch after smoke `bbqs1koyi`):** a big
publicization pass answering the user's 2nd directive:
- **README badges + subtle sponsor** (zwasm taste: CI/Zig/Clojure/EPL/Sponsors +
  bottom sponsor line). Issues/PRs **stay paused** (did NOT mirror zwasm's reopen).
- **CI reproducibility + efficiency (D-544, NEW)**: the D-539 CI's first run
  FAILED on runner tool-gaps (rg/mapfile/GNU-timeout) — a reproducibility gap,
  not a code bug (D-539 discharge note CORRECTED — the "verified" was premature).
  Fixed: mapfile→read loop, timeout→`run_bounded` fallback, ripgrep install-if-
  missing + added to flake.nix (+coreutils); + actions/cache of Zig deps/build +
  two-tier gate (push/PR=core, nightly/dispatch=full). **Pending green re-verify.**
- **大整理**: shipped host-name refs (ARCHITECTURE ubuntunote, build.zig OrbStack),
  8 src `private/` de-pointered, 6 mixed-JP src comments → English, provenance
  `~/Documents/OSS` paths → repo-relative (placement.yaml/host_interfaces/cw_ported),
  2 docs/works/ladder.md private/ refs. Inventory: `private/notes/2026-07-01-
  publicization-cleanup-inventory.md`. **Cat5 ~2962-line comment de-pointering
  (D-522) is the GRADUAL long tail — not one-shot.**

**First task on resume:** confirm the CI run on the pushed tip is GREEN on both
legs (D-544 barrier); iterate if a further runner gap surfaces. Then continue
Track B (D-522 de-pointer / D-523 doc audit vs code-truth / D-526/527/528).
zwasm reflection done: badges + CI-efficiency pattern adopted; Issues/PRs paused.
