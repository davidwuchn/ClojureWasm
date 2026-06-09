# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `adfc9d29` (see `git log` for current). D-358 fully landed +
  clj-faithful. Gate: HEAD is smoke-green; the look-ahead full gate on
  `59a1821a` was 302/1 where the 1 was a STALE assertion (`phase16_host_stream`
  `class_reader`), fixed in `adfc9d29` → expect 303/0. The `/continue` resume
  procedure re-runs the full gate on pickup; do that before D-356 source lands.
- **First commit on resume MUST be**: the **ADR for `cljw build` require-closure
  embedding** (D-356 Part 2 — ADR-0034 amendment or new ADR + mandatory DA fork;
  it is depth-3). THEN re-apply **D-356 Part 1** (the reverted classpath
  prerequisite — `buildFile` load_paths + `installChained` AFTER `setupCore`;
  cli.zig build branch `-cp/-A` + `loadDepsEdn`; the exact diff is in
  `private/notes/D356-cljw-build-classpath-prep.md`), then the closure-embed impl
  + the e2e. Full design + the op_require-idempotency enabler are in the D-356
  debt row + that note. After D-356: **D-362** (Clojure Conj 2026 CFP runway —
  org repo migration → fly deploy → zwasm `v2.0.0-alpha.2` tag → build.zig.zon
  pin → README/CFP; user-collaborative).
- **Forbidden**: pushing to `main`; pinning a zwasm tag (F-001 relative-path
  co-dev); committing D-356 Part 1 (classpath) ALONE — it leaves the built
  BINARY failing at run (`lib_not_found`), so Part 2 (closure embed) must land
  with it. Two gates at once (share `/tmp/codev_gate.lock`).

## Just landed — D-358 clj-faithful stream class/instance? + import resolution

`820977dd` (ADR-0126 amendment + debt) · `59a1821a` (source) · `adfc9d29` (stale
test fix). `(class s)` now returns the clj-concrete buffered type
(`io/reader`→`BufferedReader` …); `instance?` is true for the concrete + its
java.io superclass chain only, with a COMPREHENSIVE sibling set known-false
(F-013); an imported simple class name resolves LEXICALLY at analyze time
(`special_forms.resolveInstanceClassArg`, reusing `ns.imports`) + a runtime
fallback in `__instance?`, so `(import …)` AND `(ns …(:import …))` work incl. the
cross-ns-fn case. cljw keeps ONE generic host_stream internally; only the
observable answers mirror clj (F-011). Corpus `io_stream_class.txt` (13 lines).

## Process discipline (SSOT)

- **Gate cadence**: per-commit run the fast **`--smoke <changed-e2e-step>`**
  (ADR-0107 two-tier) and **don't block** — launch it `run_in_background`, yield,
  commit+push when the stamp lands. The smoke tier authorizes shared-code commits
  too, up to 5 before a forced full gate. Batch the **full gate**
  (`bash test/run_all.sh --serial-e2e`, the 248 e2e shell + perf) at the ceiling
  / Phase boundary / pre-release — also backgroundable as a look-ahead. See
  memory `smoke_first_batch_full_gate`. (The look-ahead full gate caught the
  D-358 stale assertion the smoke missed — keep using it.)
- **Linux gate is independent** (ubuntunote): `timeout 1800 bash
  scripts/run_remote_ubuntu.sh` against a pushed HEAD.
- Demo binary is `cljw-wasm` (separate from the gate's `cljw`); rebuild before
  any playground run.

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-356** = next, scope-corrected to require-closure
embedding; D-362 = CFP runway) → `private/notes/D356-cljw-build-classpath-prep.md`
(full design + the prototyped Part-1 diff) → `.dev/decisions/0126_clojure_java_io.md`
(io subsystem ADR + the D-358 amendment) → CLAUDE.md.

## Stopped — user requested

User instruction (2026-06-09): after D-358 completed and D-356 was found to be a
real cljw feature (require-closure AOT embedding, not just a classpath), the user
agreed to take the あるべき論 (full feature) BUT asked to stop here and wire the
remaining work for the next clear session: "あるべき論を取るべきだとは思いますが、
…残件がしっかり次のクリアセッションに伝わるように、配線・参照チェーンを整えて監査し、
このセッションは止めにしましょう（そしたらclearからcontinueをします）". The D-356
working changes were prototyped, verified at build-time, then REVERTED so the tree
stays clean across `/clear`; the design + exact diff are persisted in the D-356
debt row + `private/notes/D356-cljw-build-classpath-prep.md`. Resume at **D-356**.
