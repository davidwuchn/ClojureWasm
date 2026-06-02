# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: see `git log` (clj-parity campaign on `cw-from-scratch`).
  Gate green (Mac 206). debt ledger = **`.dev/debt.yaml`**.
- **First commit on resume MUST be: clj-parity campaign C4 = D-209**
  (`map-entry?` + a distinct MapEntry: activate the RESERVED Group-A
  `.map_entry` slot — consuming a reservation ≠ amending F-004). C1 (D-164
  empty `()`) + C2 (D-205 BigDecimal map-key, ADR-0077) + C3 (D-207 Object
  methods) are DONE. Remaining order: C4 D-209 → C6 D-200 (no-slot Date β) →
  C5 D-198 (host-class exc ctors, after D-048) → C7 D-165 (heap-Long B2).
  Full unit table: D-210 anchor row + ROADMAP §9.2.P. All loop-resolvable
  (ADR-0076 am1).
- **Forbidden**: "fixing" an AD-001..008 accepted divergence (set print-order,
  `(class)` simple name, error Kind, **AD-008 Long-overflow auto-promote** —
  see `.dev/accepted_divergences.yaml`); for C7 D-165, widening the NaN-box
  inline int or adding a `.date`/heap-Long slot (use **B2**: a flag on the
  heap-int, F-004 layout UNCHANGED); re-opening landed work (git log = SSOT);
  perf without a Release `scripts/perf.sh` number.

## Just landed (this session; git log = SSOT, full rows in `.dev/debt.yaml`)

- **C1 D-164 DISCHARGED**: distinct empty list `()` (interned count-0 `.list`
  on `rt.empty_list`, no new NaN-box slot) threaded big-bang through rest/
  empty/take/print/analyzer/**serialize**/lazy_seq.seq/core.clj; `()` truthy,
  `(seq?/list? '())`→true, `(= '() nil)`→false. Corpus `empty_seq` (70).
- **C2 D-205 DISCHARGED** (ADR-0077): BigDecimal scale-independent map-key via
  a CACHED stripped projection (`norm_unscaled`/`norm_scale`) read by the
  rt-free `keyEqValue`/`valueHash`; print + arithmetic keep the authoritative
  `(unscaled, scale)`. Chose Option A over the DA's Alt 2. Corpus `bigdecimal_key`.
- **C3 D-207 DISCHARGED**: universal Object methods via dispatch-level
  `object_method.tryObjectMethod` (both backends, after method-table miss) →
  str/=/hash/class; `str` core unified into `print.writeStrValue`. AD-009
  (`.hashCode`=cljw hash) + AD-003 (`.getClass` simple name). Surfaced D-212
  (str-of-BigInt/BigDecimal N/M suffix, pre-existing). Corpus `object_methods`.

## clj-parity campaign units (the A-half; full rows in `.dev/debt.yaml`, D-210 anchor)

- **All loop-resolvable** (ADR-0076 am1): C1 D-164 / C2 D-205 / C3 D-207 DONE
  · **C4 D-209** (`map-entry?` via reserved `.map_entry` slot) · C6 D-200
  (no-slot typed_instance Date, β) · C5 D-198 (host-class exc ctors, after
  D-048) · C7 D-165 (heap-boxed Long, B2 flag on heap-int — NO F-004
  amendment; NaN-box i64-inline is impossible, cw v0 also i48).
- **Decided, NOT campaign units**: AD-008 (Long overflow past i64 auto-promotes
  per F-005; clj throws — accepted divergence, user-ratified) · D-211 (`+'`/`*'`
  promoting arithmetic deferred; F-005's `+'`-clause is clj-inverted).

## Process discipline (SSOT = memory + rules; do NOT re-expand here)

- Gate: `timeout 1800 bash test/run_all.sh --serial-e2e` (~5min actual; 1800 is
  headroom — the -P8 pool over-runs under load, memory `gate-parallel-e2e-timeout`).
  Never poll a bg gate. `clj -M -e` → `timeout 20` + bound infinite seqs. Speed
  ONLY via `scripts/perf.sh`. Tool channel corrupts under host load — verify
  greps via Read / `bash grep`; and it TRANSCODES literal non-ASCII in
  Edit/Write (build expected non-ASCII via `printf` in tests, keep files ASCII).

## Cold-start reading order (tracked-only)

handover → `.dev/decisions/0076_clj_parity_campaign_and_accepted_divergences.md`
+ ROADMAP §9.2.P → `.dev/accepted_divergences.yaml` +
`.claude/rules/accepted_divergences.md` → `test/diff/clj_corpus/COVERAGE.md` +
`.claude/rules/clj_diff_sweep.md` → `.dev/debt.yaml` (open: D-210 anchor /
D-209(C4)/D-200/D-198/D-165 + D-212) + `.dev/decisions/0077_*` (C2) → CLAUDE.md
(§ Project spirit + Autonomous Workflow + The only stop) →
`.dev/project_facts.md` (F-002/004/005/009/010/011/012) → `.dev/principle.md`.
