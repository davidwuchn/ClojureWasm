# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (D-373 instance?-fn / gate-cadence docs / keyword-hash fix
  / D-375 clojure.lang hash statics / D-378 multi-pair assoc, all pushed). Gate
  cadence (ADR-0107, now documented everywhere): per-commit **smoke**
  (`bash test/run_all.sh --smoke <step>`, background it, don't block); **batch the
  full gate** at the ≤5 ceiling / Phase boundary / pre-tag; manual probes on a
  **ReleaseSafe** binary (`zig build -Doptimize=ReleaseSafe -Dcpu=baseline`).
- **First on resume MUST be: confirm direction with the human** — this session
  pursued the flatland.ordered.map blocker chain under the user's "work the
  soon-a-problem properly" go (keyword-hash + D-375 + D-378). ordered.map is a DEEP
  chain; its LIVE next blocker is **D-379** (`(.get ^Map backing-map k)` =
  java.util.Map `.get` on a native map, map.clj:72). If the human says continue the
  chain, start D-379; otherwise await a new direction.
- **Forbidden**: pushing to `main`. The fly demos (D-362) are DONE + live.

## Just landed

- **D-373 / ADR-0128** — `instance?` is a fn over a class VALUE (drop expandInstanceQ;
  higher-order condp/map/partial works; one classValueKeyFor analyzer arm; interface
  markers resolve as values; exceptionDescriptor→classDescriptor; Map$Entry). DA-fork
  Alt 2' (complete the isInstance oracle, no class_role enum).
- **Gate-cadence scaffolding** reconciled to ADR-0107 (smoke per-commit / batch full)
  across CLAUDE.md + gate_cadence.md (SSOT) + continue SKILL + exploration_vs_done.
- **Keyword-hash determinism** — valueHash had no `.keyword` arm (fell to the
  non-deterministic pointer hash); added `hash_cache +% 0x9e3779b9` (clj parity).
- **D-375 / ADR-0108 am1** — clojure.lang APersistentMap/APersistentSet/Murmur3 static
  hash/equality helpers (F-013 closed set; coll_hash.zig vtable-seq walk; mapHash =
  cljw single content hash = AD-028; deftype `.hashCode` == equal native map's).
- **D-378** — multi-pair assoc folds over pairs on an Associative deftype receiver.
- ordered.map advanced map.clj:59 → 123 (D-375) → 159 (D-378) → 72 (D-379).

## Follow-ups tracked

D-379 (`.get`/java.util.Map read methods on native colls — ordered.map LIVE blocker) ·
D-377 (cross-impl map-hash consistency: contentHash≠collHash + `(hash deftype)` ignores
hasheq) · D-374 (top-level-`do` unroll) · D-376 (Murmur3/hashUnencodedChars UTF-16) ·
D-369 / D-238 / D-276. quality_floor rows = the standing correctness-first drain.
Per-task notes: `private/notes/D37{3,5}-*.md`.

## Cold-start reading order

handover → `.dev/debt.yaml` D-379 (+ D-377) → `.dev/decisions/0128_*` + `0108_*` (am1)
→ CLAUDE.md § Autonomous Workflow.

## Stopped — user requested

User instruction (2026-06-10): freeze after D-373 until an explicit human go
(verbatim recorded in the prior handover). The human then lifted it for the
"soon-a-problem" work — 「すぐ問題になる系であれば、しっかり取り組んでください」 — under
which this session landed the keyword-hash fix + D-375 + D-378. ordered.map proved a
deep multi-blocker chain (D-379 next, more likely after). Checkpoint: confirm with the
human whether to keep chasing the ordered.map chain (→ D-379) or take a new direction
before continuing.
