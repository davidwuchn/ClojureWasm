# ADR-0114 — hiccup enablement: protocol-dispatch + host-interop extensions

- **Status**: Proposed → Accepted
- **Date**: 2026-06-07
- **Discharges**: unblocks **weavejester/hiccup** (Stage 1.3 verified_projects,
  10th proof — `hiccup.core` / `hiccup2.core` / `compiler` / `util` / `page`).
- **Cross-refs**: ADR-0106 (host_instance container — amended here with
  `host_finalise` / `host_trace`), ADR-0103 (host_inert), ADR-0102/host_interface
  (host-supertype markers), ADR-0059 (no-JVM class hierarchy), F-002
  (finished-form), F-006 (GC strategy), F-011 (behavioural equivalence), F-013
  (definition-derived). AD-023 (java.util.Map extend-target inert). Debt D-317
  (ISeq tag table), D-318 (host_instance moving-GC), D-319 (Object-as-chain-root).

## Context

hiccup 2.0 (`hiccup.core` delegates to `hiccup2.core`) renders a Clojure data
tree to HTML through a `HtmlRenderer` protocol + Java-interop string building. A
naive "add java.net.URI" (the handover's expectation) was the first of a
**seven-blocker chain**, each a general F-013 coverage gap — not a hiccup
special-case. Grouped into three ADR-level decisions, plus routine host surfaces
and three bug fixes.

## Decision A — Object extension is a universal protocol-dispatch fallback

`(extend-protocol P Object …)` registers the impl on the Object class
descriptor. cljw protocol dispatch (`runtime/dispatch.zig`) previously raised
`protocol_no_satisfies` on a per-receiver-type miss without consulting Object.
**Now**: after a per-type miss, consult the Object descriptor's method_table and
call that impl if present. **nil is EXCLUDED** — clj nil is not an Object, so a
type extends nil separately (verified: `(extend-protocol P nil …)` resolves via
the per-type path on the nil descriptor, dispatched before this fallback). This
is the clj-faithful "Object is the universal default" rule; hiccup's HtmlRenderer
`Object` branch renders String / number content this way. Lookup is uncached
(correct — `lookupWithCache` never caches a null miss; the perf cliff is D-319,
within the deferred-optimization envelope).

## Decision B — host_instance gains optional finalise + trace hooks (amends ADR-0106)

Two optional fn-pointer fields on `TypeDescriptor`, dispatched by a single shared
`.host_instance` tag finaliser / tracer:

- `host_finalise(infra, *[4]u64)` — URI / StringBuilder free their gc.infra heap
  state (a duped string / an `ArrayList(u8)`) when the instance is swept.
- `host_trace(gc, *[4]u64)` — java.util.Iterator marks its cursor seq Value (the
  **first** host type to store a live Value in `state`, closing the ADR-0106
  D-294 note). Decode goes through `heapHeader()` (the G1 membrane).

Leaf host types (Random) leave both null → no cost. **Moving-GC caveat**: the
Value lives in a raw `u64` slot the typed field-walker can't see, so a future
moving GC must RELOCATE via `host_trace` (mark-only suffices for the current
non-moving GC, F-006). Documented in `gc_rooting.md` §H + a `GC-ROOT:` marker;
the closed-`host_state_shape`-enum finished form is D-318.

## Decision C — clojure.lang / java interfaces as extend-protocol TARGETS

Three target classes, resolved at the macro / analyzer layer:

1. **host_inert java interface** (`java.util.Map`) as TARGET → **load-only
   no-op** (`expandExtendType` emits nil). No cljw value is a java.util.Map, so
   the impl could never dispatch — AD-023, matching the `host_interfaces.yaml`
   inert contract (ADR-0103). As a bare VALUE (`(not-hint? x java.util.Map)`) it
   resolves to a named class descriptor (analyzeSymbol).
2. **native-implemented clj interface** — a new closed table
   `host_interface.NATIVE_EXTEND_TARGETS` maps `IPersistentVector`→`[vector]`,
   `ISeq`→`[list lazy_seq cons chunked_cons range string_seq array_seq]`,
   `Named`→`[keyword symbol]`; `expandExtendType` distributes the impl over
   `(rt/__native-type :tag)` per tag, so a native value dispatches the protocol.
   This is the core `(html [:p …])` path. (Hand-maintained table; D-317 tracks the
   derive-from-markers finished form + the silent-omission risk for a future tag.)
3. **registered host-surface class** (`java.net.URI`) as VALUE → its `rt.types`
   descriptor (analyzeSymbol; the surface analogue of the ADR-0109 opaque arm).

## Routine surfaces (compat_tiers rows, not ADR-level)

`java.net.URI` (keyword `uri`) + `java.net.URLEncoder` (`url_encode`) +
`java.lang.StringBuilder` (`string_builder`) + `java.util.Iterator` (`iterator`)
+ `java.lang.String/valueOf` (static surface alongside the installNativeMethods
instances). `.iterator` is wired into `object_method`'s universal fallback, so
every cljw seqable is a java.util.Iterable.

## Bug fixes (commit notes, not ADR-level)

- **syntax-quote alias resolution** (`qualifySym`): an `ns`-qualified symbol whose
  `ns` is an alias resolves to the alias target's full name — clj hygiene
  (`` `str/join `` → `clojure.string/join`). Without it a macro template calling
  an aliased ns breaks wherever expanded (hiccup.core `html` →
  `hiccup2.core/html`).
- **syntax-quote `%N` anon-fn param** stays bare (`#()` lowers to `(fn* [%1 %2]
  …)` at read time; was over-qualified to an invalid `user/%1` fn* parameter).
- **exception_descriptor method_table leak** at `Runtime.deinit` (freed only the
  fqcn; a `(extend-protocol P Object …)` adds a method_table that leaked —
  hiccup's Object branch first surfaced it).

## Alternatives considered

The following is the verbatim output of a Devil's-advocate subagent forked with
fresh context against the active F-NNN constraints (the mandatory depth-≥2
review). Its recommendations are advisory; the main loop's choices + rationale
follow each.

> ### Decision A — Object extension as universal protocol-dispatch fallback
> **Threshold correctness findings:** (1) The cache does NOT skip the Object
> fallback — `lookupWithCache` does `td.lookupMethod(...) orelse return null;`
> before the refill, so a miss is never cached as present; no correctness hole,
> but a latent perf cliff (a defaults-only hot site re-walks lookupMethod every
> call, never caches the Object entry). (2) nil exclusion matches clj (a
> protocol with only an Object impl, called on nil, throws — nil does not fall to
> Object), but correctness depends on nil having a real resolvable descriptor in
> the per-type path; must be verified, not assumed.
>
> **A-smallest-diff** — cache the resolved-to-Object result too (sentinel
> MethodEntry). Better: removes the re-walk cliff, confined to method_table.zig.
> Breaks: a third cache state the global generation guard must invalidate (it
> already bumps on extend, low risk) + complicates the hit-site read.
>
> **A-finished-form-clean** — Object is the reserved ROOT of the descriptor
> lookup chain; lookupMethod walks receiver_td→…→Object_td; the dispatch-site
> special case disappears; the CallSite cache caches the resolved entry
> uniformly (cliff dissolves structurally). Better: zero extra fast-path code,
> the cljw-native expression of "Object is the universal target" (one reserved
> descriptor, not a JVM hierarchy — ADR-0059-safe), the seam future
> host-supertype precedence needs. Breaks: nil-exclusion must move into chain
> construction (Object NOT appended to nil's chain); ordering (most-specific
> first, Object last) encoded in chain order. More design, but the design the
> finished form needs. Cite F-002 — recommend anyway despite larger diff.
>
> **A-wildcard** — eager copy of Object impls into every descriptor's table at
> extend time. Better: pure per-type lookup, fastest hit path. Breaks: violates
> the finished form badly — override-ordering minefield, open descriptor set
> (re-sweep on every deftype birth), table bloat. Rejected on F-002, recorded as
> wildcard only.
>
> **Recommendation A: switch-to-A-finished-form-clean.** The dispatch-site
> special case is a smallest-diff convenience; Object-as-chain-root dissolves the
> cache cliff for free, gives nil-exclusion an honest home, and is the seam
> host-supertype precedence will need. F-002 says the larger diff is not a reason
> to prefer the draft.
>
> ### Decision C — clojure.lang / java interfaces as extend-protocol targets
> **Threshold findings:** (3) The 7-tag ISeq list is almost certainly incomplete
> and incompleteness is SILENT (map/set seqs, rseq, iterate/repeat/cycle, empty
> list, MapSeq — any distinct tag omitted → `(extend-protocol P ISeq …)` silently
> fails to dispatch on it, the F-013 failure mode but invisible). A hardcoded
> list is a denylist-by-omission. (4) F-013 tension: a hand-maintained table that
> drifts from where tags declare seq-ness is the per-tag special-casing F-013
> forbids — the question is derived-vs-hand-maintained, not table-vs-no-table.
>
> **C2-smallest-diff** — keep the table but back it with an exhaustive
> `Value.Tag` switch the compiler forces total, so a new tag breaks the build
> until classified (the zig_tips.md idiom). Better: kills silent omission
> minimally. Breaks: still hand-classification, two places know "this tag is a
> seq".
>
> **C2-finished-form-clean** — derive the interface→tag mapping from the native
> types' declared interface markers (extend the existing `host_interfaces.yaml`
> closed-set SSOT to the native ISeq/IPersistentVector/Named set). Better:
> F-013-clean (cannot drift, a new seq tag that declares ISeq is auto-included),
> unifies with Decision B's iterator + any future native seq, converges with
> A-finished-form-clean on "descriptors are the SSOT". Breaks: requires native
> descriptors to carry a queryable native-interface set (real upfront work).
> Cite F-002 — recommend anyway; avoids a second parallel interface registry.
>
> **C2-wildcard** — one synthetic `__native_ISeq` supertype descriptor every seq
> tag's chain includes; extend writes once; dispatch finds it by chain walk.
> Better: O(1) extend, no enumeration, composes with A-finished-form-clean.
> Breaks: depends on A's chain walk; precedence + multi-interface (small DAG)
> subtleties. The endgame once A lands.
>
> **Recommendation C-2: switch-to-C2-finished-form-clean** (derive from markers,
> extend host_interfaces.yaml), with C2-wildcard as the endgame once A's chain
> walk lands; if A stays as-drafted, the minimum bar is the compiler-forced
> exhaustive switch — never a silent-omission denylist. **C-1 and C-3
> keep-as-drafted** (C-1's load-only no-op is exactly ADR-0103's inert contract;
> C-3 is finished-form-clean).
>
> ### Decision B — host_instance optional finalise + trace hooks
> **Threshold findings:** (5) GC-safety: the container was declared a LEAF with a
> "no write barrier" comment; storing a live Value makes that invariant false —
> (a) the write-barrier/generational trap for a future GC (F-006), the leaf
> assertion must flip to conditional-non-leaf; (b) a moving GC must RELOCATE the
> Value (tracing marks liveness, not relocation) — this new root site must be in
> gc_rooting.md with a GC-ROOT marker or the moving-GC migration silently misses
> it. (6) "raw u64 = @intFromEnum of a Value" — a Value is NaN-boxed; the trace
> hook must decode through the canonical heapHeader/isGcManaged membrane, not
> treat state[0] as an opaque pointer (else mark garbage or miss pointers).
>
> **B-smallest-diff** — the fn-pointer hooks as drafted + the leaf→conditional
> doc correction + a GC-ROOT marker registered in gc_rooting.md + the hook
> decodes via the canonical membrane. Better: closes #5/#6 with no structural
> change; the per-descriptor fn-pointer is genuinely flexible. Breaks: nothing
> structural; this is the FLOOR the draft must reach.
>
> **B-finished-form-clean** — a closed `host_state_shape` enum on the descriptor
> (leaf / owns_heap_buffer@idx / holds_value@idx), dispatched by the shared
> finaliser/tracer; fn-pointer escape hatch for the irregular case. Better:
> moving-GC relocation centralised in ONE arm (not N hooks), the rooting membrane
> stays queryable (an enum value, not grep-the-fn-pointers), bounds ad-hoc state
> shapes, matches the project's closed-set-SSOT preference. The current three
> types (Random=leaf, URI/StringBuilder=owns_buffer, Iterator=holds_value) are
> 100% covered by three members. Cite F-002 — recommend anyway; the shape the
> moving-GC future demands.
>
> **B-wildcard** — promote Value-holding state out of `[4]u64` into a real
> GC-managed `?Value` field; `[4]u64` reverts to honest "non-Value words only".
> Better: eliminates the NaN-box-bits hazard at the root (typed Value, decoded by
> the type system), leaf assertion stays true, moving GC handles a real field
> uniformly. Breaks: changes ADR-0106's "[4]u64 state" container shape — a
> depth-3/4 revision (the project spirit welcomes it). Worth it if several host
> types will hold live Values; overkill if Iterator is a one-off.
>
> **Recommendation B: switch-to-B-finished-form-clean** (enum + escape hatch) and
> unconditionally adopt B-smallest-diff's three corrections regardless. The one
> thing that must NOT ship is the draft without the gc_rooting registration (an
> unrooted-for-moving-GC site, F-006 hazard).
>
> ### One-line recommendations
> - A — switch-to-A-finished-form-clean (Object as descriptor-chain root).
> - C-2 — switch-to-C2-finished-form-clean (derive from markers); C-1/C-3 keep.
> - B — switch-to-B-finished-form-clean (host_state_shape enum) + unconditionally
>   add the leaf-fix + GC-ROOT/gc_rooting registration + canonical-membrane decode.

### Main-loop disposition (within the F-NNN envelope)

- **Decision A** — KEEP as-drafted (uncached dispatch-site fallback); the DA
  confirms it is CORRECT. A-finished-form-clean's only win is the perf cliff +
  future host-supertype precedence — both governed by the explicit
  optimization-deferral invariant (memory `optimization-deferred-until-15-libs`,
  at 10 libs) and the structural-imagination "defer to the owning point" rule.
  Recorded as **D-319** (perf + chain-root finished form), scheduled at
  optimization-resumption / host-supertype-precedence. This is NOT a
  Cycle-budget-defer smell: the deferral is the optimization invariant, not diff
  budget. nil-exclusion VERIFIED correct (`(m nil)` dispatches the nil impl).
- **Decision B** — KEEP the fn-pointer hooks (B-smallest-diff is the accepted
  floor) AND adopt all three mandatory corrections NOW: leaf→conditional comment,
  `GC-ROOT:` marker + `gc_rooting.md` §H, canonical `heapHeader()` decode (the
  draft already used it). The `host_state_shape` enum (B-finished-form-clean) is
  **D-318**, scheduled at the moving-GC migration / a 4th irregular host type —
  the F-006 non-moving invariant makes the current mark-only trace correct, so
  the enum is genuine moving-GC-future work, not a deferred cleanup.
- **Decision C** — C-1/C-3 keep (DA concurs). C-2 KEEP the hand table, VERIFIED
  complete vs the live Value.Tag seq family (no current omission). The
  derive-from-markers finished form + the future-omission risk are **D-317**,
  scheduled at a new-seq-tag landing / host_interfaces.yaml-as-native-SSOT.

All three deferrals record the finished form as a scheduled debt row (F-002
honoured: the clean shape is captured, not lost), and none requires violating an
F-NNN. The DA found no F-NNN-blocking issue.

## Consequences

- Protocol dispatch honours Object + native-interface extension targets → a large
  class of real libs (anything extending a protocol to Object / IPersistentVector
  / ISeq / Named) now loads + dispatches correctly.
- `.host_instance` can carry heap-owning + Value-holding state, GC-correct under
  the current non-moving GC; the moving-GC relocation path is documented + D-318.
- Divergence AD-023: extending a protocol to `java.util.Map` is inert in cljw.
- Perf (D-319) + tag-table drift (D-317) + host-state enum (D-318) are scheduled
  finished-form work, not silent gaps.
