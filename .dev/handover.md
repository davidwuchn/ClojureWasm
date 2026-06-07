# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log`. Newest = **hiccup (10th verified_projects, ADR-0114)**:
  java.net.URI/URLEncoder + StringBuilder + java.util.Iterator (GC-traced
  host_instance) + String/valueOf surfaces; Object-extension universal
  protocol-dispatch fallback; IPersistentVector/ISeq/Named extend-TARGET →
  native-tag distribution; java.util.Map extend-TARGET inert (AD-023);
  syntax-quote alias resolution + `%N` anon-param fix; exception_descriptor
  method_table leak fix. `verified_projects/` → `-M:verify`, now **10** (medley,
  math.combinatorics, data.priority-map, core.cache, potpuri, data.zip, qbits.ex,
  core.unify, integrant, hiccup).
- **First commit on resume MUST be: land honeysql** (→ 11), then STAY the
  library-incorporation campaign. honeysql = **D-315**: (a) `java.util.Locale`
  US/ROOT static fields → a Locale value (host_instance, ADR-0106; GC-safe
  per-Runtime singleton — gc.infra-alloc like empty_queue OR root the rt slots,
  the earlier revert's lesson) + `.toUpperCase`/`.toLowerCase` optional Locale arg
  (cljw casing already locale-independent), AND (b) **regex lookahead `(?=…)`** in
  `src/runtime/regex/` (`honey.sql/dehyphen` `#"(\w)-(?=\w)"`; a real matcher
  feature). Land (a)+(b) TOGETHER (anti-drip-feed). Probe `verified_projects/honeysql`
  for the exact chain; add dir + `bash scripts/verify_projects.sh honeysql`, commit
  on green. SSOT = `.dev/convergence_campaign.md` Stage 1.3 item 3. A failure IS a
  coverage gap → fix root-cause (F-013), NOT a per-lib patch / Maven JAR.
- **After honeysql verifies (→ 11): STAY the campaign** (paused, not abandoned).
  The loop then **self-selects** remaining work (CLAUDE.md § The only stop next-task
  rule + the F-010 `quality-loop floor:` drain) — coverage has plateaued, so the
  precision-raise = quality work (tests, robustness, error-path fidelity) + any
  user-flagged feature, NOT more lib-probing. Optimization stays DEFERRED per memory
  `optimization-deferred-until-15-libs` (measured via `scripts/perf.sh` Release only).
- **Parked libs (deeper blockers; not the priority)**: schema (`clojure.lang.Compiler/
  CHAR_MAP` value-position), clip (`clojure.lang.Reflector`), data.avl (`clojure.lang.RT`/
  APersistentMap), bouncer/struct (clj-time / cuerdas Maven+regex). Re-probe after a
  campaign re-open; NOT now.
- **Deferred — do NOT re-attempt the naive fix**: D-308 `(instance?
  clojure.lang.IDeref x)` needs a per-interface NATIVE-implementer table ∪ protocol
  satisfaction — NOT a `satisfies?` alias (reverted) · reify protocol_remap (D-280
  residual) · D-288 deftype `^:volatile-mutable`+set! · D-305 builtin var
  :arglists/:doc table · D-316 def-target metadata-map VALUES unevaluated · D-314
  defprotocol `:extend-via-metadata` dispatch · **D-317** ISeq extend-tag table
  (derive from markers) · **D-318** host_instance moving-GC relocation /
  host_state_shape enum · **D-319** Object-as-descriptor-chain-root (perf).
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

- **ADR-0114 hiccup enablement** (10th verified_projects). The handover's "URI only"
  was a 7-blocker chain, each a general F-013 gap (not a hiccup patch). Three
  ADR-level decisions: Object-extension universal dispatch fallback (D-319 finished
  form); host_instance gains host_finalise/host_trace hooks (URI/StringBuilder free
  heap state, Iterator holds+traces a Value — gc_rooting.md §H, D-318); clojure.lang/
  java interfaces as extend-TARGETs (host_inert no-op AD-023, native-tag distribution
  D-317, host-surface-class value). DA-fork ran (depth-≥2); finished-form follow-ups
  scheduled as D-317/318/319 (F-002 honoured, not lost).

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate (source only): `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min;
  -P8 over-runs under load). Doc-only / verified_projects-only = no gate. Never
  poll a bg gate. New e2e MUST register in test/run_all.sh (e2e_reach gate).
- `verified_projects` sweep + clj-diff probes are NETWORK / many-`cljw` — never
  run concurrently with the gate. clj-diff harness = `scripts/clj_diff_sweep.sh`;
  `clj -M -e` → `timeout 20` + bound infinite seqs. Speed ONLY via `scripts/perf.sh`.
  Edit/Write TRANSCODES non-ASCII (splice via python). Default backend = VM (F-012).

## Cold-start reading order (tracked-only)

handover → **`.dev/convergence_campaign.md`** (driving SSOT; Stage 1.3 item 3 =
verified_projects + PRIORITY/STAY directive) → **`verified_projects/README.md`** (the
lib-load method) → `docs/works/ladder.md` (ranked candidates + NEEDS-ROW) +
`.dev/debt.yaml` (D-315 honeysql / D-317-319 ADR-0114 follow-ups) + `compat_tiers.yaml`
→ ADRs `0101_deps_git_fetch.md` (+am.1) / `0111_deps_run_modes.md` /
**`0114_hiccup_protocol_host_interop.md`** / `0106` (host_instance) → `.dev/project_facts.md`
(F-013/F-010/F-002/F-006) → CLAUDE.md (§ Project spirit + The only stop) → `.dev/principle.md`.
