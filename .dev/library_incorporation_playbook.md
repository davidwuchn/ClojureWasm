# Library-incorporation playbook — how cljw absorbs real-world Clojure libs

> A standing reference for the `test/conformance/verified_projects/` coverage engine (F-010 /
> F-013, convergence_campaign Stage 1.3). Written 2026-06-07 after landing 11
> libraries (medley → … → hiccup → honeysql). The campaign is on **STAY** (user
> directive 2026-06-07); this doc exists so a future re-expansion resumes with
> the accumulated know-how instead of re-deriving it.
>
> SSOT for the *method* lives in `test/conformance/verified_projects/README.md`; this doc is the
> SSOT for the *patterns, taxonomy, and coverage strategy* behind it.

## 1. The core mental model

**One real library is an N-blocker chain, not a single feature.** Every lib
landed so far revealed *more* blockers than the handover predicted:

- **hiccup**: handover said "java.net.URI only" → actually **7 blockers**
  (URI/URLEncoder/StringBuilder/Iterator surfaces, Object-extension dispatch
  fallback, extend-protocol native-tag distribution, syntax-quote alias + `%N`
  fix, exception_descriptor leak). ADR-0114.
- **honeysql**: survey said "Locale + lookahead" (2) → actually **5 blockers**
  (Locale static + String 2-arg + regex lookahead + IPersistentMap extend-target
  + `.sym` keyword method). ADR-0115.

The corollary: **a probe that fails is the START of the work, not the end.** The
first `name_error` / `not_implemented` / `type_error` is blocker #1 of many; fix
it, re-probe, get blocker #2, repeat until green. Budget for the chain, not the
first error.

## 2. The probe loop (the engine)

```
1. mkdir test/conformance/verified_projects/<lib>; write deps.edn (:git/url + :git/sha) + verify.clj
   (require the lib's CORE ns + assert REAL outputs, not just `require`).
2. bash scripts/verify_projects.sh <lib>   → read the FIRST blocker (file:line + Kind).
3. Classify the blocker (§4 taxonomy) → find its fix site (§4 "fixed in").
4. Fix the ROOT CAUSE (F-013: definition-derived, never a per-lib patch). Probe a
   minimal repro with `cljw -e` to confirm the fix in isolation.
5. Re-probe (step 2). New blocker → repeat. Green → run the FULL sweep
   (scripts/verify_projects.sh, no filter) to confirm no regression, then the gate, then commit.
```

**Why `verify.clj` must assert real outputs**: a bare `(require …)` passes when a
namespace merely *loads*; the functional bar (`(sql/format {…})` →
`["SELECT …" …]`) catches the runtime gaps (`.sym` undefined, Object-fallback
missing) that load-only misses. Every blocker after the analysis-time ones is a
runtime dispatch/interop gap that only a real exercise surfaces.

## 3. F-013 discipline (the thing that makes coverage compound)

**Fix the root cause, neutrally — never special-case the lib.** Every fix landed
so far is a *general capability* that helps the next lib too:

- hiccup's Object-extension fallback → every lib extending a protocol to Object.
- honeysql's regex lookahead → every lib using `(?=…)`.
- hiccup's syntax-quote alias resolution → every macro whose template calls an
  aliased ns (extremely common).

This is why the per-lib cost *decreases* over time: the 11th lib reused
mechanisms the 1st–10th built. A per-lib patch (a special case keyed on the lib's
name / a stub that fakes one call) would break this compounding and is forbidden
(the no-op-stub / permanent-no-op rule).

## 4. Gap taxonomy — where each class of blocker lives (the high-value map)

When a probe fails, classify the blocker and go straight to its fix site:

| Blocker shape (what the error looks like)                                   | Class                        | Fixed in                                                                                               | Examples (ADR)                      |
|-----------------------------------------------------------------------------|------------------------------|--------------------------------------------------------------------------------------------------------|-------------------------------------|
| `No namespace: 'java.x.Y'` on `(Y. …)` / `(Y/method …)`                   | **Host class surface**       | new `runtime/java/<pkg>/<Class>.zig` + `_host_api.zig` `java_surfaces` + compat_tiers row              | URI/URLEncoder/StringBuilder (0114) |
| stateful host object (mutable / holds state)                                | **host_instance**            | `host_instance.alloc`; heap state → `host_finalise` hook; live Value in state → `host_trace` (D-318) | StringBuilder/Iterator (0114)       |
| `No namespace: 'Class'` on `Class/STATIC` (scalar)                          | **Static field (scalar)**    | descriptor `static_fields` (int/float/bool)                                                            | Integer/MAX_VALUE, Math/PI          |
| `No namespace: 'Class'` on `Class/STATIC` (object value)                    | **Static field (object)**    | `Singleton` enum (type_descriptor.zig) + analyzer arm + gc.infra singleton                             | Locale/US (0115, ADR-0087)          |
| `No namespace: 'Class'` on `Class/staticMethod`                             | **Static method surface**    | `___HOST_EXTENSION` static descriptor (fqcn `cljw.java.<pkg>.<Class>` for bare resolve)                | String/valueOf (0114)               |
| `No implementation of method 'm' on protocol '<.member>' for type 'T'`      | **Native instance method**   | `runtime/<x>_methods.zig` installNativeMethods on `nativeDescriptor(.<tag>)`                           | .sym keyword (0115), .name ns       |
| `.method: index/arity` — wrong arity on an existing method                 | **Method overload**          | arity-range check in the method fn (ignore unused args if semantically irrelevant)                     | toUpperCase(Locale) (0115)          |
| `Unable to resolve symbol: 'Interface'` as an `extend-protocol` TARGET      | **extend-protocol target**   | host_interface: `NATIVE_EXTEND_TARGETS` (native tags) / host_inert no-op / host-surface-class value    | IPersistentVector/Map (0114/0115)   |
| `No implementation … for type 'String'` when a protocol has an Object impl | **Object dispatch fallback** | dispatch.zig (Object-extension universal fallback)                                                     | hiccup HtmlRenderer (0114, D-319)   |
| macro template references an aliased ns / `#()` param errors                | **syntax-quote hygiene**     | `qualifySym` (alias resolution, `%N` bare)                                                             | hiccup html→hiccup2 (0114)         |
| `regex literal (unsupported syntax …)`                                     | **regex engine feature**     | `runtime/regex/{compile,match}.zig`                                                                    | lookahead `(?=…)` (0115)           |
| `No namespace: 'clojure.lang.X'` (call/value position, JVM-internal)        | **deferred host ref**        | ADR-0113 (defers to a CALL-time feature_not_supported; the ns LOADS)                                   | integrant RT/baseLoader (0113)      |
| a memory leak / crash surfaced by the above                                 | **latent bug**               | wherever — these are real bugs the new exercise first triggers; fix + regression-test                 | exception_descriptor leak (0114)    |

This table IS the methodology compressed: most future blockers fall into one of
these ~12 classes, and each has a known fix site. A genuinely novel class is rare
and warrants an ADR.

## 5. Raising the coverage rate effectively

- **Batch by shared blocker class, big-bang the mechanism.** Libs cluster on the
  same gaps (many use `(extend-protocol P Object)`; many use aliased-ns macro
  templates). Landing the *general* mechanism once clears a whole cluster. Pick
  the next lib partly by which mechanism it would unlock for others.
- **Anti-drip-feed (D-315 lesson).** When a lib reveals blockers one-at-a-time,
  do NOT land them one-per-cycle forever — the Micro-coverage-grind smell. honeysql
  was parked precisely because Locale-alone landed no verified lib (the next
  blocker, regex lookahead, was still there). Land the *whole* chain to green in
  one focused push, or park the lib until you can. A half-fixed lib that still
  fails verify is worse than an unstarted one (the ladder reads "covered").
- **Probe-derived, not guess-derived.** The chain is discovered empirically by
  re-probing, not by reading the lib's source up front and guessing. The probe is
  cheaper and never wrong about what actually blocks.
- **Reuse `test/conformance/verified_projects/<lib>` as a regression net.** Each landed lib stays
  as a committed proof; `scripts/verify_projects.sh` re-runs all of them, so a
  later change that breaks an earlier lib is caught (run the full sweep before
  every honeysql/hiccup-class commit).

## 6. Discipline reminders (so the coverage stays honest)

- **Divergence → AD-NNN** (`accepted_divergences.yaml`), never a silent gap
  (java.util.Map extend-target inert = AD-023). BUT a divergence only qualifies
  when its justification is a *project invariant*, not convenience — a silent
  semantic drop dressed as an AD is forbidden (`no_op_stub_forbidden`). The
  ADR-0115 DA fork caught exactly this: a "capture-free lookahead" AD was rejected
  because discarding captures is a silent drop, so the finished form (full capture
  parity) shipped instead. *Eliminating the loss beats recording it.*
- **Finished-form deferral → debt row** with the clean shape recorded + scheduled
  at its owning point (D-317/318/319 for ADR-0114; D-320 lookahead perf for
  ADR-0115). F-002: the clean shape is captured, not lost.
- **ADR-level decision → inline ADR + mandatory DA fork** (depth ≥ 2). The DA
  fork challenges the design from fresh context; its output goes verbatim into
  "Alternatives considered" (see ADR-0114/0115).
- **Never trust a "covered" claim without a corpus/verify proof** (anti-D-177):
  the `test/conformance/verified_projects/<lib>` dir + its assertions ARE the proof.

## 7. Where to look next (when re-expanding)

- `docs/works/ladder.md` — the ranked candidate ladder + the first-blocking gap
  per lib (the NEEDS-ROW list). The next libs + their predicted blockers live there.
- Parked libs (deeper blockers, handover): schema (`clojure.lang.Compiler/CHAR_MAP`
  value-position), clip (`clojure.lang.Reflector`), data.avl (`clojure.lang.RT`/
  APersistentMap), data.xml (StAX), instaparse (java.io), data.json (PrintWriter/
  PushbackReader). Each names its blocker class (§4) — start from the fix site.
- The deferred-host-ref class (ADR-0113) is the biggest remaining lever: many libs
  park on a single `clojure.lang.*` peripheral ref; the per-interface NATIVE-
  implementer table (D-308) would unlock a cluster.

## Cross-references

- `test/conformance/verified_projects/README.md` — the mechanical how-to-add (the method).
- `.dev/convergence_campaign.md` Stage 1.3 — the campaign driver this doc serves.
- `docs/works/ladder.md` — the candidate ladder + per-lib first blocker.
- ADR-0113 (deferred host refs) / ADR-0114 (hiccup) / ADR-0115 (honeysql) — the
  worked examples this playbook generalises.
