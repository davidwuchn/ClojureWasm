# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (D-366 license + D-368 agent race fix + zwasm alpha.2
  tag-pin + demo-runway docs landed/pushed; Ubuntu serial gate 302/0 green).
- **First on resume MUST be (autonomous, overnight)**: the post-M quality loop
  (F-010), starting with **D-365 residual** — the bytecode-serializer **CHUNK
  round-trip gate** (side-table + field completeness; the 2 axes the Value-tag
  symmetry gate does not cover) — then **D-196 VM-parity** (e2e + corpus under
  `-Dbackend=vm`, toward the F-012 default-VM flip). Then the standing
  quality-loop floor drain per CLAUDE.md. Run autonomously.
- **Forbidden**: pushing to `main`. The fly demo deploy (D-362) is a separate
  user-triggered task, NOT the autonomous focus — if cw-serverless-demo is still
  crash-looping on resume, see D-362 (the `-Dcpu=baseline` fix + a quick verify),
  do not fold it into the quality loop.

## Just landed — D-366 + D-368 + zwasm tag-pin + demos on fly

- D-366 (`ca1578c9`) EPL-2.0 `clojure/**` attribution; D-368 (`7f12451c`,
  ADR-0093 am1) agent `await` delivers-after-`notifyWatches` (watch-race fix).
  Both Ubuntu-serial green (302/0).
- zwasm `v2.0.0-alpha.2` cut + pushed to clojurewasm/zwasm; build.zig.zon
  tag-pins it (`a8ca2007`); jtakakura remote removed.
- **Demos deployed to fly** (fresh self-contained repos: Dockerfile + run_local
  clone+build cljw `-Dwasm -Dcpu=baseline`, zwasm via the tag pin; committed
  frontend-release + Wasm + PROVENANCE; bookshelf config.edn → env via direnv /
  fly secrets + a fly volume for SQLite):
  - clojurewasm/cw-playground — <https://cw-playground.fly.dev> **verified live**
    (eval / numeric tower / wasm-FFI `nth_prime`=541 / per-eval budget).
  - clojurewasm/cw-serverless-demo — <https://cw-serverless-demo.fly.dev>
    **verified live** (the `-Dcpu=baseline` fix cleared the SIGILL crashloop;
    `/api/books` serves the seeded SQLite-via-Wasm data).
  - **Two fly gotchas fixed**: (1) cljw MUST build `-Dcpu=baseline` or it SIGILLs
    (exit 132) on a shared-cpu run machine lacking the build host's instructions;
    (2) the Zig tarball URL is `zig-<arch>-linux-<ver>` (arch first, since 0.14).
- README (D-367) URL-filled + committed (`41b89209`): logo 180px, GitHub
  Discussions (not Slack), no ideal section.

## Process discipline (SSOT)

- Gate cadence: per-commit `--smoke <step>` (don't block); batch full
  `bash test/run_all.sh` at boundaries. The Ubuntu remote gate (ubuntunote,
  load-immune) is the fallback — `timeout 1800 bash scripts/run_remote_ubuntu.sh`
  against the pushed HEAD.

## Cold-start reading order

handover → `.dev/debt.yaml` (**D-365** residual = NEXT; **D-196** VM-parity;
**D-362** = fly demo-deploy state) →
`private/notes/D365-serialize-regex-symmetry.md` → CLAUDE.md § Autonomous
Workflow + F-010 quality loop.
