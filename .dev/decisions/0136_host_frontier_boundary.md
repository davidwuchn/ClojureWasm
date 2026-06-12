# ADR-0136 — The host-frontier boundary: a 4-rule decision procedure for "language feature" vs "Tier D JVM detail"

- **Status**: Proposed → Accepted (2026-06-13, autonomous per CLAUDE.md
  § ADR-level designs are handled inline; Devil's-advocate fork embedded
  below)
- **Driven by**: D-406 (the boundary was implicit / reactive
  marker-by-marker, so "Clojure assets run as-is" read as an unbounded
  treadmill) + the 2026-06-12/13 conformance campaign that produced enough
  concrete classifications to derive the rule (D-391..D-405, the
  bouncer/clj-time finding, the D-400 marker-family close-out).
- **Relates to**: ADR-0013 (Tier D rationale), ADR-0059 (no-JVM), ADR-0102
  (`host_interfaces.yaml` closed-set SSOT — the R2 leaf), ADR-0134
  (value-driven membership), ADR-0135 (Wasm components — the R1 refusal's
  forward pointer), F-009 (neutral impl + thin surfaces), F-011 (clj-oracle
  behavioural equivalence), F-013 (definition-derived coverage, closed-set
  SSOTs + gates), ROADMAP §6 (tier system; this ADR adds §6.5).

## Context

cljw's compatibility promise is "pure-Clojure assets run as-is" — but real
libraries constantly touch the JVM host surface (`clojure.lang.*`,
`java.*`). Until now each hit was classified reactively: a marker row here
(D-394/395/397/399/400), a Tier-D refusal there (gen-class), with the line
living only in precedent. D-406 named the consequence: without a stated
boundary the grind cannot *converge* — every new library may demand a new
judgement call, and "compatible" has no finite definition.

The 2026-06-12/13 conformance campaign (15 lib corpora, 284 golden pairs)
supplied the missing evidence: which host names real Clojure code actually
reaches, and which of those cljw could satisfy canonically vs which it must
refuse. This ADR turns that precedent into a **decision procedure** so the
next session classifies by running rules, not by pattern-matching history.

## Decision

A `clojure.lang.*` / `java.*` name hit during the compat grind classifies
by running these rules **in order** (first match wins):

- **R1 — Artifact test → Tier D.** Does satisfying the name require a Java
  *artifact* (joda-time, Jackson, guava, …) or JVM *machinery* (bytecode
  emission, classloaders, reflection metadata)? Then it is Tier D. The
  refusal's catalogue template names the cljw-native path (a pure-Clojure
  alternative, or a future Wasm component per ADR-0135 / F-001). The
  canonical instance: bouncer hard-requires clj-time (joda) — cljw never
  shims a Java library. R1 runs first because it is the cheapest and most
  total test.
- **R2 — Polymorphism-seam test → language feature.** Is the name a
  `clojure.lang.*` abstraction that clojure.core itself dispatches on — in
  deftype/reify/extend SUPERTYPE position or at the CLASS FACET
  (`instance?` / `isa?` / `extend-protocol` / `print-method` dispatch)?
  Then it is a language feature; coverage is definition-wide (the whole
  interface, F-013) and the closed set is **`host_interfaces.yaml`**
  (ADR-0102, gate G4).
- **R3 — Value-semantics test → language feature.** Is the observable
  behaviour a pure function of Clojure values (`Util/equiv`, `Murmur3`,
  `String`/`Long`/`Double` statics, `StringBuilder`/`StringWriter`,
  `Pattern`/`Matcher`, `UUID`, `Date`/`Instant`, the java.util
  collection-VIEW methods `.size`/`.contains`/`.indexOf`/`.comparator`/…)?
  Then it is a language feature, provided as a thin surface over a neutral
  impl (F-009); the closed set is **`compat_tiers.yaml`** (gates G2/G3).
  **Tiebreak (the Murmur3 case)**: a name that is both value-semantic and
  arguably a JVM implementation detail goes to R3 (language feature) iff
  its behaviour is clj-oracle-checkable per F-011; otherwise R4.
- **R4 — Implementation-leak default → Tier D.** Everything else —
  `clojure.lang.Compiler/*`, reflection (`getConstructor`/`newInstance`/
  `clojure.reflect` over host classes), JVM-internal statics
  (`PersistentArrayMap/createAsIfByAssoc`), raw `java.util.concurrent`
  surface beyond cljw's own concurrency vocabulary. **Default-deny**: a
  name no rule claims is Tier D until an ADR amendment claims it.

Operational consequences:

1. Each closed set declares its admitting rule at the FILE level —
   `host_interfaces.yaml` IS the R2 set, `compat_tiers.yaml` host_classes
   are R3-admitted (header declarations; a per-row constant tag would be
   ceremony — the DA's own over-formalisation warning). The one
   discriminating population — future `tier: D` rows, where R1 vs R4
   matters for the refusal text — carries `frontier_rule:` per row; the
   schema note mandates it and the gate lands with the first such row
   (avoiding an aspirational gate over a zero population). This is F-013
   clause 3 applied to the frontier itself.
2. ROADMAP gains **§6.5** carrying the procedure + the worked-example
   table, so the grind's convergence claim is structural: side-1 coverage
   is a finite, definition-derived surface; side-2 is refused with
   catalogued, alternative-naming errors.
3. The upstream-corpus scan (Alternative 3 below) is admitted as
   **non-normative evidence** for R2/R3 judgements (a
   `~/Documents/OSS/clojure/src/clj/**` hit is strong evidence of a seam),
   never as the rule.

## Alternatives considered

(Devil's-advocate fork output, fresh-context subagent, 2026-06-13 —
embedded verbatim:)

> **Devil's-advocate review.** No F-NNN violation is required for any
> finished-form-clean shape — the draft and all three alternatives below
> fit inside F-002/F-009/F-011/F-013/ADR-0059/F-001. The draft's main
> exposure: its nine buckets (a)–(i) are **campaign-derived, not
> definition-derived** — they generalise what the 2026-06-12/13 grind
> happened to hit. Bucket (d) ("java.* classes Clojure programs traffic
> in") is the weak point: "traffic in" is an observational predicate,
> which is exactly the treadmill D-406 exists to stop, and the
> bucket-shaped rule gives the next grind session no decision *procedure*
> for a name outside the examples.
>
> **Alt 1 — smallest-diff: no new ADR; amend ADR-0013 + add a `frontier:`
> field to compat_tiers.yaml / host_interfaces.yaml rows.** Each
> classification lands as data on the existing SSOTs; ADR-0013 gains a
> short "frontier" amendment; no ROADMAP §6.5.
> *Better than the draft:* zero new documentation surface; keeps §6.0's
> "the YAML carries the classification, the narrative documents the
> framework" division intact; every classification is already mechanically
> checkable by the existing G3/G4 gates.
> *Breaks:* the **rules themselves have no normative home** — the line
> stays emergent from row-by-row precedent, which is the exact "implicit
> (reactive marker-by-marker)" state D-406 names as the debt. Convergence
> is asserted, not derivable. Also leaves Java-library deps homeless:
> joda-time has no compat_tiers row to annotate. Rejected on F-002: it is
> the smallest-diff convenience the finished-form owner would unwind.
>
> **Alt 2 — finished-form-clean (recommended): replace the nine buckets
> with a 4-step ordered DECISION PROCEDURE, each leaf bound to a
> closed-set SSOT + gate.** [R1 artifact / R2 polymorphism-seam / R3
> value-semantics / R4 default-deny, as adopted above.]
> *Better than the draft:* definition-derived in the F-013 sense
> (predicates, not observed buckets); the next grind name classifies by
> running the procedure instead of pattern-matching nine examples;
> default-deny makes convergence structural rather than aspirational;
> bounds bucket (d) — a java.* class enters only by passing R3, killing
> the "traffic in" treadmill.
> *Breaks:* substantially larger landing (schema change on two YAMLs +
> gate script + ROADMAP §6.5 rewrite around the procedure); R3 has genuine
> hard cases (Murmur3 is value-semantic *and* a JVM hashing implementation
> detail — the procedure needs an explicit tiebreak: R2/R3 win over R4
> when behaviour is clj-oracle-checkable per F-011); risk of
> over-formalising leaves that only ever hold one row. Recommended anyway
> per F-002 — the diff size is not a constraint, and this is the shape
> under which the draft's own buckets become regression examples instead
> of the law.
>
> **Alt 3 — wildcard: derive SIDE 1 mechanically from upstream Clojure's
> own .clj corpus.** A host name is a language feature iff it appears in
> `~/Documents/OSS/clojure/src/clj/**/*.clj`; ship the scan as a script
> regenerating a frozen `frontier_corpus.yaml`.
> *Better than the draft:* the most literally definition-derived option —
> zero human bucket-judgement, re-derivable by anyone, auto-answers future
> names.
> *Breaks:* upstream core.clj freely uses `clojure.lang.Compiler`,
> `RT/classForName`, gen-class — the raw scan over-includes precisely the
> Tier D side, so an exclusion list re-imports all the judgement it
> claimed to remove; it under-includes names third-party libs call that
> core.clj never does; and it couples cljw's *language* definition to JVM
> Clojure's implementation file layout — tension with ADR-0059's spirit.
> Worth keeping as a *cross-check input* to Alt 2's R2/R3, not as the
> rule.
>
> **Recommendation: Alt 2**, absorbing the draft's buckets as the
> worked-example table and Alt 3's corpus scan as a non-normative evidence
> column.

The main loop adopted Alt 2 verbatim (finished-form first per F-002), with
Alt 3 admitted as evidence-only and the draft's buckets demoted to §6.5's
worked examples.

## Worked examples (the campaign's classifications under the rules)

| Name hit                                    | Rule          | Side             | Landing                                              |
|---------------------------------------------|---------------|------------------|------------------------------------------------------|
| deftype declares `clojure.lang.IKVReduce`   | R2            | language feature | host_interfaces.yaml + reduce-kv consult (D-400)     |
| `(instance? clojure.lang.IPersistentMap x)` | R2            | language feature | declared-interface class facet (2026-06-13)          |
| `clojure.lang.Murmur3` static hash          | R3 (tiebreak) | language feature | clj-oracle-checkable value fn (ADR-0108 am1)         |
| `(.indexOf [1 2] 2)` (java.util.List view)  | R3            | language feature | value-search trio on native colls (2026-06-13)       |
| `java.io.StringWriter`                      | R3            | language feature | host_instance container surface (2026-06-13)         |
| bouncer → clj-time → joda-time            | R1            | Tier D           | lib dropped from the conformance seed; doc'd example |
| `gen-class` / `definterface` bytecode       | R1            | Tier D           | per-form catalogue Codes (ADR-0018)                  |
| `clojure.lang.Compiler/eval`                | R4            | Tier D           | default-deny                                         |
| `(.getConstructor c)` reflection            | R4            | Tier D           | default-deny                                         |

## Consequences

- The compat grind has a finite goal: cover the R2/R3 closed sets
  definition-wide; refuse R1/R4 with catalogued errors. "Compatible"
  becomes checkable.
- New-name classification is procedural; ADR amendments are needed only
  to *move* a name across the line (per §6.3's promotion rule), not to
  classify one.
- The `frontier_rule:` schema + gate retrofit is the mechanisation half
  (framework_completion discipline) and lands in the same cycle as this
  ADR.

## Affected files

- `.dev/ROADMAP.md` — new §6.5 (the procedure + worked examples).
- `host_interfaces.yaml` — header declares the file as the R2 closed set.
- `compat_tiers.yaml` — header declares host_classes R3-admitted + the
  Tier-D `frontier_rule:` schema mandate.
- `.dev/debt.yaml` — D-406 discharge.
