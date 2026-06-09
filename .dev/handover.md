# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `8a9460fd` (D-361 runner cap-lift; see `git log` for current).
  Mac gate baseline **303/0** `--serial-e2e`. Tree clean.
- **First commit on resume MUST be**: the **D-355 babashka-free playground
  port** — rewrite `~/Documents/MyProducts/playground-v2/server/playground/
  {server,sandbox}.clj` to run ON cljw (no babashka), using the now-landed
  `clojure.java.io` / `cljw.fs` / `cljw.json` / `cljw.eval/with-budget` /
  `cljw.http.server`. First: `zig build -Dwasm -Doptimize=ReleaseSafe && cp
  zig-out/bin/cljw zig-out/bin/cljw-wasm` (the demo binary predates the io
  work). Any cljw gap the port hits → fix cljw-side (TDD, finished-form), the
  playground repo is NOT cljw-gated.
- **In flight**: a background ubuntunote Linux gate verifies the D-361 fix on
  `8a9460fd` (`/tmp/cljw_ubuntu_d361.txt`). If it still shows
  `e2e_phase16_eval_budget` red, the cap-lift hypothesis was incomplete —
  re-open D-361 and inspect the actual Linux render path.
- **Forbidden**: pushing to `main`; pinning a zwasm tag (F-001 relative-path
  co-dev). Two gates at once (share `/tmp/codev_gate.lock` — `mkdir` acquire,
  `rmdir` release).

## Just landed — clojure.java.io subsystem (ADR-0126, 9 commits)

Full cljw-native io, `bca4eb9d..8a9460fd`: `java.io.File` host type (Cycle 1) ·
`clojure.java.io` file family + reader/writer/input-stream/output-stream + copy
+ as-url/resource stubs (Cycles 2,4,5,6) · `clojure.core/line-seq` · generic
buffer-backed `host_stream` (Cycle 3, `runtime/io/host_stream.zig`) ·
`cljw.json` (encode/decode-keywordized) + `cljw.fs` (babashka.fs-style) (Cycle
7) · D-361 Linux heap-render fix. cljw-style (no-JVM, F-009 neutral impl, FS-jail
reused, cond dispatch). Deferrals tracked: D-357 (getAbsolutePath, no cwd path),
D-358 (stream leaf-name instance?), D-359 (URL/resource), D-360 (read-str
:key-fn), D-051 (byte-array Value, Phase 16).

## Process discipline (SSOT)

- **Gate cadence**: additive (pure-insertion .clj/new file) commits ride on
  per-feature smoke (`zig build` + `cljw -e` probes + the new e2e) up to 5
  before a full gate; **shared-code (existing-line edit / build.zig\*) needs a
  fresh full gate**. `bash test/run_all.sh --serial-e2e`; verify Summary
  `failed: 0` + `.dev/.gate_pass` == `scripts/gate_state_hash.sh`.
- **Linux gate is independent** (ubuntunote, remote): launch in background
  against a pushed HEAD as look-ahead; it does not contend with local smoke.
  `timeout 1800 bash scripts/run_remote_ubuntu.sh`.
- Demo binary is `cljw-wasm` (separate from the gate's `cljw`); rebuild before
  any playground run.

## Cold-start reading order

handover → `.dev/decisions/0126_clojure_java_io.md` (the io subsystem ADR +
DA Alt 2) → `.dev/debt.yaml` (D-355 playground, D-357..361 io deferrals) →
`~/Documents/MyProducts/RESUME_cfp_demos.md` (demo background) → CLAUDE.md.
