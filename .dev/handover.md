# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `ec9ccfed` (ADR-0054 lazy-seq Layer-2 actually landed; gate
  102/102; see `git log` for exact HEAD — it advances each commit).
- **First commit on resume MUST be**: **row 14.11 — D-100 (b) step 3b:
  self-embedding `cljw build` CLI + startup trailer-detect.** DONE: (a)
  BytecodeChunk serializer @194eefaf; (b) step 1 envelope
  (`serialize.serializeEnvelope`/`deserializeEnvelope`); step 2
  compile-core (`builder.zig::buildEnvelope`); step 3a artifact trailer
  (`serialize.frameArtifact`/`extractPayload`,
  `[runtime][payload][u64 len]["CLJC"]`). **Do NOT re-implement (a) /
  envelope / buildEnvelope / trailer.** Exact APIs (probed): self-exe =
  `std.Io.File.openSelfExe(io, .{})`; read a file =
  `std.Io.Dir.cwd().openFile(io, path, .{})` then
  `f.reader(io,&buf).interface.allocRemaining(gpa,.unlimited)` (mirror
  `cli.zig:163-171`); `cli.dispatch(init)` has `io=init.io /
  gpa=init.gpa / arena=init.arena.allocator()` + a `first`-arg
  subcommand chain at `cli.zig:33-69` (add a `build` arm there). Step
  3b: (1) `builder.buildFile(io,gpa,arena,in,out)` = read source →
  setup+`buildEnvelope` → `frameArtifact(self_exe_bytes,payload)` →
  write `out` (createFile+writeAll) + chmod 0o755; (2) `build` dispatch
  arm parsing `<in.clj> -o <out>`; (3) startup: at `dispatch` top,
  `extractPayload(self_exe_bytes)` — if non-null, deserializeEnvelope +
  `vm.eval` each chunk after `loadCore` (D-131) instead of REPL/argv;
  (4) e2e `cljw build fx.clj -o /tmp/out && /tmp/out` (and `tail -c4 ==
  CLJC`). F-009-extract the shared bootstrap setup (runner + builder).
  Then (e) `cljw-formats/0.1.0.edn` archive lock. Design: ADR-0034 am1
  (Alt B) + ADR-0015 am5; survey `private/notes/phase14-14.11-survey.md`.
- **Resume disambiguation**: §9.16's numerically-first `[ ]` row IS
  14.11 (`[ ] partial` — (a)/(c)/(d) done, (b)/(e) outstanding) and it
  is now the resume target (lazy-seq row 14.13.5 closed). 14.12 is
  zwasm-v2-gated (defer per F-010). 14.13 polish + 14.14 release follow.
- **Forbidden this session**: re-opening D-126/D-127/D-134/D-136/D-137
  or lazy-seq cycles 1-4 (the whole cluster is discharged). Making
  finite `(range n)` lazy (deferred — needs count/nth on lazy_seq; a
  tracked DIVERGENCE in core.clj). Widening wasm FFI / row 14.12 (F-010
  de-prioritizes it). Pulling the v0.1.0 tag (row 14.14) before 14.11 +
  14.13 land. Chunking (defer per ADR-0054 D5). Exact cross-category
  `==` / `compare` (D-014a ladder).

## Current state

Phase 14 v0.1.0 IN-PROGRESS. Mac gate **102/102** (read from the on-disk
log; ubuntunote re-verify at the next Phase boundary per ADR-0049).
**ADR-0054 lazy-seq Layer-2 is COMPLETE** (row 14.13.5 `[x]`). cycle 4
(repeat/repeatedly/cycle/take-while/drop-while/partition) + `list`
actually landed at `ec9ccfed`: the earlier "repair" (8f7a1e63) and
roadmap flip (240749ed) had claimed it, but the six fns + `list` were
never in core.clj (red gate masked by flaky output). Caught on resume by
reading run_all.sh from the log; also removed a duplicate `iterate` and
realigned the phase6 private_leaf test to ADR-0054's `-drop-eager`
deletion.

## Active task

**Row 14.11 — D-100 (b) step 3b: self-embedding `cljw build` CLI.**
Done: (b) step 1 envelope + step 2 compile-core + step 3a artifact
trailer (`serialize.frameArtifact`/`extractPayload`, unit-tested). Step
3b = self-exe read (`std.Io.Dir`, Juicy-Main `init.io`) + `buildFile`
(read→buildEnvelope→frameArtifact→write+chmod) + `cli.zig` `build`
dispatch + startup `extractPayload` detect + e2e. F-009-extract the
shared bootstrap setup (runner + builder). Then (e)
`cljw-formats/0.1.0.edn` archive lock. See Resume contract. F-009: the
per-form helper is shared by runner + builder, not duplicated.

## Open debts (named; full rows in `.dev/debt.md`)

- **D-100** (b)/(e) outstanding (a/c/d done): (b) `cljw build`
  (`builder.zig` not yet written; payload envelope + per-form
  compile-then-eval + `"CLJC"` trailer; ADR-0034 am1 + ADR-0015 am5);
  (e) cljw-formats archive lock.
- **D-131** ADR-0034 deferred trailer blocks (post-v0.1.0). **D-103**
  bytecode-cache version scope must include peephole rule set (latent
  until D-100(b) ships). **D-092** keyEq→valueEqual + structural
  valueHash. **D-135** bare `()`. **D-138** `e2e_phase14_error_format`
  flaky-once watch.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow + § The
only stop) → `.dev/project_facts.md` (esp. F-010) → `.dev/principle.md`
→ ADR-0034 (cljw build) + ADR-0015 am5 → ROADMAP §9.16 row 14.11 →
`.dev/debt.md` (D-100 / D-131 / D-103).
