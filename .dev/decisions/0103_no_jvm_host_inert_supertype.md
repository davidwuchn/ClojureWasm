# ADR-0103 — no-JVM host-inert deftype/reify supertypes (java.util.Map, java.lang.Iterable): recognised-but-inert

- **Status**: Proposed → Accepted (2026-06-07)
- **Driven by**: D-281 — clojure.data.priority-map (and collection libs broadly)
  declare `java.util.Map` (bare `Map`) + `java.lang.Iterable` as deftype
  supertypes for java-interop compat. The D-280e `(require)` advances past every
  clojure.lang.* declaration (ADR-0102) and stops at `Map` (priority_map.clj:374)
  with name_error. cljw has no JVM (ADR-0059), so these interfaces' methods are
  inert here — but the deftype must still LOAD.
- **Relates to**: ADR-0059 (no-JVM), AD-003 (simple class name), ADR-0102 (the
  host-interface SSOT + recognition kinds this extends), F-013 (closed-set +
  generic-route discipline), F-009, F-002, D-281.

## Context

A no-JVM Clojure runtime still has to *load* libraries that implement java
host interfaces for java-interop compatibility — `java.util.Map`,
`java.lang.Iterable`, `java.util.List`, `java.lang.Comparable`, … A collection
deftype frequently declares `java.util.Map` so JVM code can treat it as a map;
priority-map's `Map` section impls `size/isEmpty/containsValue/get/put/remove/
putAll/clear/keySet/values/entrySet`, and its `Iterable` section impls
`iterator`.

In cljw these method impls are **inert**: there is no java-interop dispatch
surface — no cljw code ever calls `.size()`/`.get()` on a value as a
`java.util.Map`. They are dead weight that exists only for the JVM. Two facts
make naive handling wrong:

1. **Collision.** cljw dispatch matches `(protocol, method)` strictly.
   priority-map declares BOTH `count` (clojure.lang.IPersistentMap → cljw
   IPersistentCollection/`-count`, ADR-0102) AND `size` (java.util.Map). Mapping
   `size`→`-count` collides with `count`→`-count`. Same for `get` (java.util.Map)
   vs `valAt` (clojure.lang.ILookup → `-lookup`).
2. **No generic surface.** Unlike the clojure.lang.* family (which routes to real
   cljw collection protocols), java.util.Map's methods have no meaningful cljw
   target — they are JVM-only.

ADR-0102's three recognition kinds don't fit: `protocol_remap` needs a real
target protocol (none exists); `marker` (zero-method) raises
`feature_not_supported` on a declared method; `method_family` (Object) is for
methods cljw DOES consult.

## Decision

Add a fourth recognition kind **`host_inert`** to the ADR-0102 host-interface
SSOT: a recognised supertype whose declared methods are **accepted and recorded
but never dispatched** by cljw (the honest ADR-0059 reading — cljw recognises
java.util.* for load-compat; it does not implement java-interop dispatch).

1. **Closed set at the INTERFACE level.** `java.util.Map` + `java.lang.Iterable`
   are `host_interfaces.yaml` rows with `kind: host_inert`. A new java host
   interface cannot be recognised without a row (F-013 closed-set — the G4 gate
   still bounds the recognised interface set). This is NOT an open "tolerate any
   unknown host supertype" policy (the DA's rejected Alt C — that masks typos and
   defeats library-driven discovery, since clj itself rejects unknown interfaces).
2. **Methods accepted-any-inert.** Under a `host_inert` interface, ANY declared
   method is accepted and registered under the interface's canonical name (e.g.
   `(java.util.Map, size)`), never dispatched. No per-method enumeration: every
   method is inert, so a typo'd inert method is harmless (still dead), making the
   method-level guardrail valueless here. The macro quote-wraps the supertype
   (isMarker→true) so the analyzer never Var-resolves it; the primitive registers
   the methods inertly instead of raising.
3. **No collision by construction.** Inert methods register under the interface's
   own canonical name (`java.util.Map` / `Iterable`), a namespace cljw never
   dispatches — so `size`/`get` cannot shadow `-count`/`-lookup`.
4. **Distinct kind keeps `marker`'s guardrail.** `marker` (Serializable,
   MapEquivalence) still raises `feature_not_supported` on a stray method — the
   guardrail that catches a misplaced method is intact for zero-method markers.
   Only `host_inert` accepts-any.
5. **Recorded as an accepted divergence** (AD-style): cljw recognises java.util.*
   host interfaces for load-compat but does not dispatch them (ADR-0059). The G4
   gate's route-soundness skips `host_inert` rows (their methods are inert, not
   `wired`).

## Alternatives considered

Devil's-advocate subagent output (verbatim, fresh context, F-NNN envelope):

> Verified: `protocol_remap` rows carry `wires_to_protocol`/`wires_to_method`, the `marker` kind raises `feature_not_supported` on declared methods, and G4 gate (ii) checks every wired method targets a real protocol. The collision facts (count/size, valAt/get) are documented in-file. I have enough to write the analysis.
>
> ---
>
> The proposed shape adds a 4th recognition kind `host_inert`: java.util.Map / java.lang.Iterable become closed-set rows whose declared methods are accepted and registered under a dedicated inert protocol (gate-exempt), never dispatched. Three alternatives within the F-NNN envelope follow. None of the three below violates an F-NNN; the smallest-diff one comes closest to grazing F-013 and is flagged.
>
> ### Alt A — smallest-diff: reuse `marker`, relax it to swallow declared methods
>
> Make the existing `marker` kind tolerate (and discard) any methods declared under a marker interface, instead of raising `feature_not_supported`. Add java.util.Map + java.lang.Iterable as `marker` rows. The deftype's java-section methods are parsed, recognized-as-belonging-to-a-marker, and dropped — no method_table entry, no inert protocol, no new kind.
>
> - **Better than proposed**: zero new recognition kind, zero new gate carve-out, zero inert protocol Var. The G4 route-soundness gate stays exactly as-is for the three existing kinds; markers already have no `wires_to`, so nothing new to exempt. Smallest possible surface.
> - **What it breaks**: it silently overloads the *meaning* of `marker`. Today `marker` means "zero-method supertype" (MapEquivalence, Serializable) and the `feature_not_supported`-on-method behaviour is a real guardrail — it catches a typo'd/misplaced method under a marker. Relaxing it to "discard any methods" deletes that guardrail for *all* markers, not just java.util.Map, so a genuine mistake (a method declared under Serializable) now passes silently. This is the **F-013 ad-hoc-pass risk made worse**: the discard is invisible at the row level (a `marker` row gives no signal that it carries dropped methods), so the ledger can't tell "intentionally inert java.util.Map" from "accidentally swallowed nonsense". It also conflates two genuinely different finished-form facts (zero-method-marker vs has-methods-but-inert) into one kind, which F-009's "thin, honest surfaces" disfavours.
>
> ### Alt B — finished-form-clean: `host_inert` as a first-class kind, but methods register under their *own* method names on a single shared `HostInert` protocol, with an explicit per-row method enumeration
>
> Essentially the proposed shape, hardened: keep `host_inert` as a distinct 4th kind, but require each row to **enumerate every inert method by name** (size/isEmpty/get/put/... for Map; iterator for Iterable) with `status: inert`, register them under one canonical `HostInert` protocol so the method_table stays uniform, and teach G4 gate (ii) a *third* clause: an `inert` method must target the `HostInert` protocol and must NOT collide with any `wired` method's (protocol, method) — making the count/size and valAt/get collisions a **gate error**, not a silent last-wins.
>
> - **Better than proposed**: the proposed shape hand-waves "under a dedicated inert protocol OR under the canonical name with the gate exempting it" — that ambiguity is itself a smell. Alt B picks the inert-protocol arm decisively and makes inertness *enumerated and gate-checked*, so F-013's "definition-derived comprehensive coverage" is satisfied mechanically: the row lists exactly what java.util.Map declares, the gate proves none of it shadows a real dispatch. The collision worry (size vs count) is impossible-by-construction because inert methods live on `HostInert`, never on IPersistentCollection — and the new gate clause asserts that separation rather than trusting it. This is the honest ADR-0059 reading: "cljw recognizes java.util.Map for load-compat; its methods are inert because there is no java-interop dispatch." An AD-NNN row documents the divergence; the enumeration is the corpus.
> - **What it breaks**: it requires per-interface method enumeration, which looks like the "per-library shim" F-013 warns against — except it isn't, because the rows are definition-derived from the *interface* (java.util.Map has a fixed method set), not from priority-map. The real cost: every future host interface that a library declares-with-methods now needs its full method list enumerated in the SSOT before it loads, which is more upfront work than a blanket tolerance. It also bakes a permanent `HostInert` protocol into the runtime that exists purely to host dead entries — a small but real "dead weight" the moving-GC / startup audits will keep tripping over.
>
> ### Alt C — wildcard: no java.util.Map row at all; a general analyzer policy that tolerates unknown host supertypes inertly
>
> Drop java.util.Map/Iterable from the closed set entirely. Instead, give the deftype/reify analyzer a **general no-JVM tolerance**: any supertype head that is (a) not a resolvable cljw protocol Var, (b) not a `host_interfaces.yaml` row, and (c) syntactically a host-class name (qualified, or a known-host bare spelling), has its method section accepted-and-discarded inertly with a one-time warning. No per-interface allowlist; the policy is "cljw has no JVM, so unknown host supertypes and their methods are inert by definition."
>
> - **Better than proposed**: maximally general and zero-maintenance — priority-map loads, and so does the *next* library declaring java.util.List / java.util.Comparator / java.lang.Comparable, with no SSOT edit. It is arguably the most honest expression of ADR-0059: "we don't have a JVM, so we don't model java.* — we tolerate it." It eliminates the closed-set-enumeration burden Alt B carries.
> - **What it breaks**: this is where the tension bites hardest, and it **loses on F-013**. F-013's whole thrust is *closed-set SSOT + a gate requiring every recognized name to route somewhere* — a blanket "tolerate anything host-shaped" policy is the structural opposite: it recognizes an *open* set, so the gate has nothing to check and the ledger has no row to read. Worse, **clj itself rejects unknown interface names** (`ClassNotFoundException` at compile) — so general tolerance is a *behavioural divergence from clj that masks real errors*: a typo'd `clojure.lang.IPersistentMpa` or a genuinely-needed-but-unmodeled interface (one cljw *should* wire) both slide through as "inert", and the gap never surfaces. That directly defeats F-013's "library-driven discovery surfaces gaps" — the gaps stop surfacing. It also collides with F-011's parity intent for the cases cljw *does* support: an interface cljw genuinely models would, if mis-spelled, be silently inerted instead of dispatched. The "syntactically a host-class name" predicate is itself fuzzy (is bare `Map` a host class or a typo'd protocol?), reintroducing the heuristic the closed set was built to remove.
>
> ### Recommendation
>
> Take **Alt B** (the hardened `host_inert`), not the proposed shape as loosely drafted and not Alt C. The proposed shape's "inert protocol OR gate-exempt canonical name" optionality is the part to kill: pick the inert-protocol arm, enumerate the methods per row, and add the G4 gate clause that makes a `(protocol, method)` collision between an `inert` and a `wired` method a hard error. That converts the project's central worry — that `host_inert` is an "ad-hoc pass disguise" — into the opposite: an enumerated, gate-verified, definition-derived row that satisfies F-013's closed-set-plus-routing discipline (it routes to a real, if inert, surface, and the gate proves no shadowing of real dispatch). Alt C is the seductive one because it reads as the purest ADR-0059 statement, but it inverts F-013's open-vs-closed posture and *removes* the discovery mechanism that surfaced this very gap — it would let the next typo'd or genuinely-missing interface rot silently, which is exactly the failure F-013 was declared to prevent; I do not recommend it despite its smaller long-run maintenance. Alt A is rejected outright: relaxing `marker` to swallow methods deletes a live guardrail for unrelated markers and leaves inertness unrecorded at the row level. The collision between `count`/`size` and `valAt`/`get` argues *against* any "map read-only methods onto the real collection protocols and drop duplicates" variant (raised in the brief): last-wins/first-wins dropping is a silent correctness hazard — whichever impl loses is the one priority-map's author wrote intending it to run on a JVM, and dropping it without a gate signal is precisely the unreviewable behaviour F-009/F-013 push against. Inert-on-a-separate-protocol makes the collision structurally impossible and gate-asserted, which is why Alt B dominates.

### Main-loop disposition (within the F-NNN envelope; the DA is advisory)

**Adopted: `host_inert` as a distinct 4th kind (the DA's core), with the
INTERFACE set closed/gated but METHODS accepted-any-inert — NOT the DA's
per-method enumeration.** Rationale for the one divergence from Alt B:

- The DA's distinct-kind decision is adopted (rejects Alt A — `marker` keeps its
  stray-method guardrail; rejects Alt C — the interface set stays closed, gate-
  bounded, so discovery still surfaces unknown interfaces).
- The DA's per-method ENUMERATION is NOT adopted. Alt B's guardrail (gate every
  inert method's name + assert no collision) protects against a typo'd/misplaced
  method — but under a `host_inert` interface EVERY method is inert (dead in a
  no-JVM runtime), so a typo is harmless (still dead). Enumerating ~20 dead
  java.util.Map methods is noise the moving-GC/startup audits trip over (the DA's
  own "dead weight" caveat), not signal. The collision the DA gates against is
  made impossible-by-construction here by registering inert methods under the
  interface's OWN canonical name (`java.util.Map`), never a real protocol — so no
  `HostInert` protocol Var and no new gate clause are needed.
- This is NOT a cycle-budget shortcut (F-002 / Cycle-budget-defer smell): the
  interface-level closed set + the distinct kind is the finished-form that closes
  F-013's actual concern (the recognised INTERFACE set can't grow per-library)
  while avoiding the dead-method enumeration that adds no correctness for a fully-
  inert interface. If a future host interface MIXES inert + functional methods,
  it is NOT `host_inert` — it is `protocol_remap` (functional methods routed) and
  the route-soundness gate applies; `host_inert` is reserved for fully-inert
  java interfaces.

## Consequences

- priority-map's `Map` + `Iterable` declarations load (its java methods inert);
  combined with D-282 (IKVReduce) the next `(require)` advances past line 374/391
  to whatever body-level blocker follows (MapEntry type / subseq — separate rows).
- `host_inert` is reserved for FULLY-inert java host interfaces. A host interface
  with functional methods routes via `protocol_remap` (gate-enforced real target).
- The recognised INTERFACE set stays closed (G4 gate): a new java interface needs
  a `host_interfaces.yaml` row — discovery still surfaces unknowns (F-013).
- An accepted-divergence note (java.util.* recognised-but-inert, derives_from
  ADR-0059) records the stance so a user who expects `.size()` java-interop on a
  cljw value sees it is by-design absent, not broken.
- Future-facing: the moving-GC / startup audits should treat `host_inert` method
  entries as inert leaves (no dispatch reachability) — recorded here so they are
  not mistaken for live dispatch surface.
