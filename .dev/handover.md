# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: `main` (`git log` = SSOT; may lag). **NORMAL PUSH MODE**: each unit's
  smoke-green commit is followed immediately by `git push origin main` (Step 6).
  `build.zig.zon` `.zwasm` is SHA-PINNED (`#412966f7…`, `lazy`, pre-JIT). Per-commit =
  smoke; full gate batches at ceiling / boundary / pre-tag (last full gate 380/0).

- **First commit on resume MUST be**: finish the **clojure.spec.alpha port** (D-475,
  the highest-value unit — spec is now ~95% functional, dev'd on the `-cp /tmp/spec_cp`
  classpath harness so the tracked build stays green). The ONE remaining characterized
  blocker is the **`&`-destructure fix**: `sequentialDestructure`
  (`src/lang/macro_transforms.zig:344`) always lowers to `nth`/`nthnext`, but clj's
  destructure WITH a `& rest` expands to `(seq g)`/`(first cur)`/`(next cur)` (verified:
  clj `(let [[a b & r] {:x 1 :y 2}])` → `[:x 1]`; the NO-`&` path keeps `nth`, which
  errors on a non-Indexed map in BOTH clj and cljw — leave it). Make the `&`-case
  seq/first/next-based (clj-faithful, hot path → TDD every shape: no-`&`/`&`/nested/`:as`/
  vector/seq/range/map). This unblocks spec's `s/keys` conform loop (alpha.clj:837
  `(loop [… [[k v] & ks] m] …)`); then re-run the s/keys verify vs clj — MORE conform-path
  blockers may follow, drain each (every one this arc was a generic cljw fix). When the
  full spec surface is clj-green, PROMOTE the port from `/tmp` + `private/spec_port_wip/`
  into the bundle per D-475's plan (src/lang/clj/clojure/spec/ + bootstrap.zig FILES +
  EPL variant-① header per `clj_attribution.md`; AOT-rebuild; clj_corpus spec area).

- **Forbidden this session**: speculative JIT integration before zwasm's API stabilises
  (read `.dev/zwasm_capabilities.md` — the JIT row is BUILDING, not adoptable; request via
  the CODEV mailbox, don't shim). `git push --force*`. Bare `zig build test` WITHOUT
  `-Dwasm` (false fails — memory `zig_build_test_needs_dwasm`). Bare `zig build` for a
  probe (ADR-0133 — ReleaseSafe). A reader-macro NS-qualification MUST use `rt/`, not
  `clojure.core/`.

## Last landed (git log = SSOT; all pushed)

**This session — the clojure.spec.alpha port surfaced + fixed 10 GENERIC cljw clj-parity
bugs (each benefits ALL cljw code, not just spec); full gate 380/0 mid-arc:**
1. `BigDecimal/valueOf` static factory (empty static method_table) — `1a5e0ed0`
2. reify/deftype/extend-type destructured method params (route through transformFnArity) — `8c4f4827`
3. `(symbol var)` → var's qualified symbol — `f74f8f18`
4. reify IObj/IMeta + metadata slot (ADR-0134 reify slice, GC-torture verified) — `458be654`
5. `:keys [::ns-key]` auto-resolve destructuring (propagate the flag) — `a17b97c8`
6. `(conj map other-map)` merge (unblocked the regex-op pcat* machine) — `8fc081d4`
7. builtin-macro-shadow gate + caseTest `rt/or` hygiene (D-476) — `7c40041f`
8. `clojure.walk` over a list with a non-`.list` (cons/lazy) tail — `cf0b8dd2`
9. `valueToForm` handles a `.hash_map` macro return — `978b41e2`
- spec.alpha: from "won't load" → load + `s/def`/`and`/`or`/`valid?`/`conform`/`cat`/`*`/`+`/
  `alt`/`coll-of` all clj-verified. `s/keys` = the one remaining blocker (the `&`-destructure
  above). 4 port adaptations (bytes?-drop / Spec-FQCN→var / checkSpecAsserts→atom / fn-sym→nil)
  live in `private/spec_port_wip/` + `/tmp/spec_cp` — re-derivable from D-475's blocker chain.
- Convention added (user-directed): `.dev/zwasm_capabilities.md` + CLAUDE.md § Data sources —
  read the zwasm capability ledger at each gap-area-unit start + Phase boundary (the JIT
  north-star tracker; zwasm is building a JIT-backed engine, ADR-0200).

## North star (context, not the immediate task)

cljw's differentiator = **Wasm/edge-native (gap area II) × VM-perf fusion→JIT (gap area III)**.
The embedded **zwasm** runtime is now growing a **JIT-backed embedding API** (ADR-0200, zwasm#477
multi-arg invoke) — the cljw pin is still pre-JIT. Adoption is gated on zwasm marking it ready +
a user-confirmed pin bump → then a gap-area-II adoption unit (engine option on `(wasm/load …)`,
interp fallback, dual-engine diff oracle). Tracker + trigger: `.dev/zwasm_capabilities.md`.

## Cold-start reading order (resume)

handover → `.dev/project_facts.md` (F-001 zwasm / F-002 finished-form / F-011 clj-parity) →
`.dev/zwasm_capabilities.md` (JIT north-star status) → `.dev/debt.yaml` D-475 (spec blocker
chain + bundle-promotion plan) + D-476 (the macro-shadow fix that landed) →
`private/notes/spec-alpha-port-arc.md` (the arc + classpath-harness method). memory
`clj_diff_sweep_methodology` + `verify_actual_pattern_not_proxy`.

## Stopped — user requested

User instruction (2026-06-20): "クリアセッションから continue だけで再開できるよう、配線・
参照チェーン監査して止めて" — plus: explain the ClojureWasm forward flow (done in chat) and
define a convention where a marker file communicates zwasm's implementation status to cljw at
boundaries (done: `.dev/zwasm_capabilities.md` + CLAUDE.md wiring). Resume at the `&`-destructure
fix (D-475 spec port).
