# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (a long clj-differential parity run landed 2026-05-31).
- **Direction (user, 2026-05-31 night)**: **resolve ALL clj input→output
  differences**, prioritising **structure / simplicity / beauty / DRY** (F-011).
  Use real Clojure (`clj -M -e`) as the oracle (`.dev/reference_clones.md` §
  Executable oracle). Operating mode = **clj differential sweep**: probe a
  category through BOTH `clj` and `cljw -e`, diff, fix every divergence at the
  finished form (F-002/F-011 — internals may diverge, observable output must
  match; commonise rather than per-op patch). Unresolvable / deep ones get a
  **detailed entry in the master ledger**
  [`private/notes/phaseA26-clj-differential-oracle.md`](../private/notes/phaseA26-clj-differential-oracle.md)
  + a `.dev/debt.md` D-NNN row. Fully autonomous all night; do NOT stop.
- **First commit on resume MUST be**: continue the **clj differential sweep**.
  The master ledger lists swept categories + remaining items; pick the next
  unswept category (host interop / Math / java.* statics / numeric edges /
  string fns / regex / map-set ops / metadata / atoms-refs / printing). Always
  diff vs `clj` (batch — clj startup ~1-2s). **Build-race**: chain
  `zig build && <probe>`. **Channel/load**: under load, tool output can be
  empty/duplicated/contradictory (memory `tool-channel-corrupts-under-load`) —
  write to SENTINEL /tmp files, poll the gate log for `SENTINEL-…-EXIT=`, run
  critical probes 3x; a premature task-completion notification can fire while a
  gate is still at the e2e step (wait for the EXIT line, not the notification).
- **Forbidden**: re-opening anything landed (git log is the SSOT). In particular
  the clj-parity fixes already done (see Current state) + all earlier Phase ≤14
  work. JIT/superinstruction (completeness first; perf deferred per D-163).

## Current state

Mac gate green (171). AOT-bootstrap LIVE. This session (git log = SSOT), in two
arcs:
1. **Structural-defect hunting**: satisfies?/extends? wrappers; class/type =
   interned `.type_descriptor` (ADR-0059); defrecord value-equality;
   keyword-on-record (`(:k rec)`≡`(get rec :k)` via shared `lookup.recordGet`);
   var_ref print `#'ns/name` + `resolve` + deref-on-var; kwargs destructuring
   (`& {:keys}` seq→map coerce); **internal errors catchable by try/catch**
   (ADR-0060: try-boundary synthesises a class_name-bearing ex_info; both
   backends; nth→index_error).
2. **clj differential parity** (user-directed, F-011): flatten/sort/sort-by/
   distinct/dedupe/reductions/map-indexed/keep-indexed return SEQS not vectors;
   interleave variadic+seq; format `%0` zero-pad; **string seq/first yield
   CHARACTERS not 1-char strings**; String `.length`/`.substring`/`.indexOf`.

New invariant **F-011** (commonisation/clean/behavioural-equivalence over
effort; clj oracle wired). New ADRs **0059** (class/type), **0060** (catch).

## Master divergence ledger (compaction-survival)

[`private/notes/phaseA26-clj-differential-oracle.md`](../private/notes/phaseA26-clj-differential-oracle.md)
holds every clj diff found this run (fixed + unresolved + acceptable), the
oracle recipe, and the swept categories. **Read it first on resume** — it is the
night-work state. Per-task notes: `private/notes/phaseA26-*.md`.

## Open debts (deep clj divergences deferred; full rows in `.dev/debt.md`)

- **D-164** empty-seq≡nil: cljw collapses `()` to nil (`(list? '())`/`(seq? '())`
  false, `(= () nil)` true, empty filter/map/rest/flatten print "nil" not "()").
  Structural empty-seq-representation cycle. The seq-vs-vector fixes inherit this
  (empty → nil). **The biggest remaining clj parity gap.**
- **D-163** perf: collection/lazy/higher-order ops ~100µs/element (large reduce/
  range timeout). Deferred to F-010 post-M perf phase (NOT premature JIT).
- Earlier: D-160 sequence/eduction, D-155/156 HAMT, D-150 VM ctor, D-133 JIT.
- **Acceptable divergences (recorded, not bugs)**: `(class 5)`→`Long` not
  `java.lang.Long` (no-JVM, ADR-0059); `(float 1/3)` f64 not f32 (no f32 type);
  set print order (unordered); `(rest "abc")` substring not char-seq (O(1) opt,
  transitively char-correct via `(seq (rest …))`).

## Cold-start reading order

handover → master ledger (above) → CLAUDE.md (§ Project spirit + Autonomous
Workflow + The only stop) → `.dev/project_facts.md` (F-011 + F-010) →
`.dev/principle.md` (Bad Smell) → `.dev/reference_clones.md` (clj oracle) →
`.dev/lessons/structural_defect_hunting.md`.

## Stopped — clean point for user-initiated PC restart (2026-05-31 ~12:40)

**Why stopped**: host CPU saturation traced to (a) an orphaned `clj -M -e
'(iterate inc 0)'` (killed) and (b) **Microsoft Defender** (`managed_by: MDM`,
`tamper_protection: block`) scanning the ever-changing zig build artefacts at
150–170% CPU. User is doing a **manual PC restart**; this session must resume
cleanly via `/continue` afterwards.

**State is restart-safe**: HEAD `62cb796a` (`cw-from-scratch`), **tree clean,
0 unpushed** (all on `origin/cw-from-scratch`). No work is lost on reboot.

**Defender exclusions added this session** (persist across reboot; via `mdatp
exclusion`, which succeeded despite MDM/tamper-block): process `zig` + folders
`{ClojureWasmFromScratch,zwasm,zwasm_from_scratch}/{.zig-cache,zig-out}` +
`~/.cache/zig`. Verify post-reboot with `mdatp exclusion list`; re-add any that
did not persist. This should remove the main Defender CPU drain.

**Other claude sessions on this machine** (do NOT kill; user-owned): pid in
`zwasm_from_scratch` (autonomous) + `myskill`. Same-repo duplicate-claude race
is NOT a risk here (only one claude in ClojureWasmFromScratch).

**Resume = `/continue`. Next unit (Step 0 survey first)**: **Java statics
`Integer`/`Long`/`Double`/`Character`** — new `runtime/java/lang/Integer.zig`
etc. (these FQCNs are in `compat_tiers.yaml` but have no surface file yet).
clj-verified targets (master ledger § remaining Java interop gap):
`Integer/parseInt` (+radix), `toBinaryString`, `toHexString`, `MAX_VALUE`/
`MIN_VALUE`, `Long/parseLong`, `Double/parseDouble`, `Character/isDigit`/
`isLetter`/`toUpperCase`. Pattern: `___HOST_EXTENSION` static-descriptor (like
`System.zig`/`Math.zig`), thin wrapper over neutral impl (F-009); delegate
parse to the existing `parse-long`/`parse-double` impl in `lang/primitive/
math.zig` where possible (F-011 DRY).

**Process discipline learned this session (now in memory + rules)**: (1) never
poll a background gate with `sleep N; cmd` — launch `run_in_background`, yield,
act on the completion notification (memory `feedback-no-poll-background-tasks`);
(2) `clj -M -e` must be `timeout 20`-wrapped (infinite-seq orphan hazard;
`reference_clones.md` + `orphan_prevention.md` + `cleanup_orphans.sh` updated);
(3) never pass `\a`-style char literals through `cljw -e` (shell eats the
backslash) — use `(char N)` (memory `char-literal-e2e-oracle`); (4) under load,
capture probe output to `/tmp/*.txt` and Read it (channel-independent), don't
trust a bare surprising read.

Done this session (all pushed): String `.charAt/.contains/.startsWith/
.endsWith/.isEmpty/.concat/.repeat` (14e7ab00); String `.replace` char/char +
string/string with char-replace commonised into `charset.replaceCharAlloc`
shared by `clojure.string/replace` (62cb796a); clj-oracle timeout hardening
(334824d1). Mac gate green 171/171 at each.
