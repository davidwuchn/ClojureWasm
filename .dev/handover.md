# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. Newest = **honeysql (11th verified_projects, ADR-0115)**
  + **hiccup (10th, ADR-0114)**. `verified_projects/` → `-M:verify`, now **11**
  (medley, math.combinatorics, data.priority-map, core.cache, potpuri, data.zip,
  qbits.ex, core.unify, integrant, hiccup, honeysql).
- **The library-incorporation campaign is on STAY (user 2026-06-07).** hiccup +
  honeysql were the user-prioritised last two; the campaign is paused (not
  abandoned). **First task on resume: self-select the highest-value QUALITY work**
  — read the open `quality-loop floor:` debt rows FIRST (F-010 drain,
  highest-value-first) per CLAUDE.md § The only stop next-task rule, THEN broader
  quality (tests / robustness / error-path fidelity / moderate features). NOT more
  lib-probing (coverage has plateaued). Optimization stays DEFERRED per memory
  `optimization-deferred-until-15-libs` (measured via `scripts/perf.sh` Release).
- **For a future library-campaign re-expansion**: the patterns + gap-taxonomy +
  coverage-raising know-how are in **`.dev/library_incorporation_playbook.md`**
  (the method is `verified_projects/README.md`; the playbook is the know-how).
- **Parked libs (deeper blockers; re-probe only on a campaign re-open)**: schema
  (`clojure.lang.Compiler/CHAR_MAP` value-position), clip (`clojure.lang.Reflector`),
  data.avl (`clojure.lang.RT`/APersistentMap), data.xml (StAX), instaparse
  (java.io), data.json (PrintWriter/PushbackReader). Each names its blocker class
  (playbook §4) → start from the fix site.
- **Deferred — do NOT re-attempt the naive fix**: D-308 `(instance?
  clojure.lang.IDeref x)` needs a per-interface NATIVE-implementer table ∪ protocol
  satisfaction — NOT a `satisfies?` alias (reverted) · reify protocol_remap (D-280
  residual) · D-288 deftype `^:volatile-mutable`+set! · D-305 builtin var
  :arglists/:doc table · D-316 def-target metadata-map VALUES unevaluated · D-314
  defprotocol `:extend-via-metadata` dispatch · **D-317** ISeq extend-tag table
  (derive from markers) · **D-318** host_instance moving-GC / host_state_shape enum
  · **D-319** Object-as-descriptor-chain-root (perf) · **D-320** regex lookahead
  matcher fuse / perf.
- **⚠ USER must act (time-sensitive, NOT AI-doable)**: see
  `private/clojure_conj_2026_cfp/archive/DEFERRED_USER_ACTIONS.md` — (1) Sessionize submit
  by 6/13; (2) v0.1.0 tag/Release + make `cw-from-scratch` default branch;
  (3) edge-demo CRUD `git push` + `fly deploy`.
- **Forbidden**: the 3 USER actions above (credential/product — safety-blocked;
  **user gives concrete instructions later — do NOT touch tag/Sessionize/edge-demo
  until then**); bench/optimization before the lib bar; editing `.claude/rules/*`
  (permission-blocked → surface as carry-over); the naive D-308 `satisfies?`-rewrite;
  pinning an in-progress zwasm v2 state/tag (F-001); trusting `~/Documents/OSS/zig`.

## Just landed (2026-06-07, git log = SSOT)

- **ADR-0115 regex lookahead + honeysql** (11th). 5-blocker chain: java.util.Locale/
  US+ROOT object-static singletons + String 2-arg Locale overload + **regex
  lookahead `(?=…)`/`(?!…)`** (Pike-NFA zero-width predicate; FULL capture parity,
  no AD — the DA fork caught that silent capture-discard is forbidden, so captures
  thread through) + clojure.lang.IPersistentMap extend-TARGET + `.sym` keyword.
  D-315 discharged; D-320 (lookahead perf fuse) deferred. Before it: **ADR-0114
  hiccup** (10th) — Object-extension dispatch fallback + host_instance finalise/
  trace hooks + extend-TARGET native-tag distribution + syntax-quote alias fix.

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min;
  -P8 over-runs under load). Doc-only / verified_projects-only = no gate. Never
  poll a bg gate. New e2e MUST register in test/run_all.sh (e2e_reach gate).
- `verified_projects` sweep + clj-diff probes are NETWORK / many-`cljw` — never
  run concurrently with the gate. clj-diff harness = `scripts/clj_diff_sweep.sh`;
  `clj -M -e` → `timeout 20` + bound infinite seqs. Speed ONLY via `scripts/perf.sh`.
  Edit/Write TRANSCODES non-ASCII (splice via python). Default backend = VM (F-012).
  handover.md edits: the framing hook blocks an Edit when the file already holds a
  forbidden phrase — fix via Bash sed/python, not Edit.

## Cold-start reading order (tracked-only)

handover → **`.dev/library_incorporation_playbook.md`** (the campaign know-how, for
a re-expansion) + **`.dev/convergence_campaign.md`** (Stage 1.3 = verified_projects
driver) → `verified_projects/README.md` → `docs/works/ladder.md` + `.dev/debt.yaml`
(quality-loop floor rows = the next-task drain) + `compat_tiers.yaml` → ADRs
**`0114_hiccup_protocol_host_interop.md`** / **`0115_regex_lookahead_honeysql.md`** /
`0106` (host_instance) → `.dev/project_facts.md` (F-002/F-010/F-013/F-006) →
CLAUDE.md (§ Project spirit + The only stop) → `.dev/principle.md`.

## Stopped — user requested

User instruction (2026-06-07): stop the library-code-working effort here (after
hiccup + honeysql → 11); create a tracked reference doc capturing the gap-finding
patterns / coverage-raising know-how for a future re-expansion (done:
`.dev/library_incorporation_playbook.md`, wired into README / convergence_campaign /
ladder / this handover); then — because context is large — audit + update the
wiring / reference chain so a fresh `/continue` resumes autonomously, and stop.
Resume = the "First task on resume" above (self-select quality work; the campaign
is on STAY).
