# ADR-0050 — Unify Java/host interop dispatch under a single `InteropCallNode`

Status: Accepted (2026-05-28, inline per CLAUDE.md § ADR-level designs
are handled inline)

Supersedes: none. Amends — D-073 parity cluster row in `.dev/debt.md`
collapses 3 existing VM-DEFER markers (`method_call_node`,
`field_access_node`, `ctor_call_node`) into one consolidated
`interop_call_node` VM-DEFER. ADR-0007 (TypeDescriptor) +
ADR-0008 (CallSite cache) + ADR-0029 D5 (cljw-prefixed surface ns)
all stay in force; the dispatch primitive they describe is now
addressed by a single Node variant rather than four parallel ones.

## Context

D-121 in `.dev/debt.md` is the v0.1.0 release blocker for Java
static method dispatch (`(java.util.UUID/randomUUID)`,
`(java.lang.System/currentTimeMillis)`, etc.). The Step 0 survey
at `private/notes/phase14-d121-survey.md` proposed adding a new
sibling Node variant `StaticMethodCallNode` next to the existing
`MethodCallNode` for instance dispatch, plus a parallel one-line
fix to `evalCtorCall` for the cljw-prefix mismatch that breaks
`(java.io.File. "x")`.

The Devil's-advocate fork
(`private/notes/phase14-d121-da-fork.md` — output captured
verbatim under "Alternatives considered" below) enumerated three
shapes within the F-NNN envelope. Its Alt 3 (a unified
`InteropCallNode { kind, ... }` that retires `MethodCallNode`,
`FieldAccessNode`, and `CtorCallNode` together) was rated
**finished-form-clean** by the DA itself, with the explicit
caveat that "the v0.5.0 maintainer would land this if given
infinite time" but that the cycle budget for D-121 made Alt 2
(the survey path) the practical choice.

The main loop initially picked Alt 2 on that "cycle budget"
reasoning. The user immediately surfaced the meta-smell: deferring
a finished-form-clean structural decision **because the current
cycle is too small** is the canonical **Progress-pressure smell**
+ **Smallest-diff bias smell** doubled. CLAUDE.md § Project
spirit makes "shipping fast and avoiding rework are second-tier"
explicit, and F-002 makes "finished-form wins" project law. The
correct response when a depth-3 surgery is exposed in mid-cycle
is to take the surgery, not to file it as deferred debt that
"rarely comes back" (the Progress-pressure smell's exact
warning).

This ADR records the correction and the unified shape.

## Decision

cw v1 introduces `InteropCallNode` as the single Node variant
that drives every form of Java- or cljw-surface interop call:
static methods, instance methods, instance field reads, and
constructors. The previously-separate `MethodCallNode`,
`FieldAccessNode`, and `CtorCallNode` are retired in the same
commit.

```zig
// src/eval/node.zig (new variant; replaces 3 existing variants)
pub const InteropCallNode = struct {
    /// Dispatch shape selector. Determines whether the eval arm
    /// expects a receiver, an analyze-time descriptor, or both.
    kind: enum {
        static_method,    // (Class/method args...) — descriptor known at analyze
        instance_method,  // (.method recv args...) — descriptor resolved at eval
        instance_field,   // (.field obj)           — descriptor resolved at eval
        constructor,      // (Class. args...)       — descriptor known at analyze
    },
    /// Analyze-time descriptor for static_method + constructor.
    /// `null` for instance_method + instance_field (resolved from
    /// the target's runtime tag at eval).
    descriptor: ?*const TypeDescriptor = null,
    /// Receiver expression for instance_method + instance_field.
    /// `null` for static_method + constructor.
    target: ?*const Node = null,
    /// Method or field name. For `constructor`, the convention is
    /// the literal string `"<init>"` — matches the JVM method
    /// table key for class constructors.
    name: []const u8,
    /// Argument expressions. Empty slice for `instance_field`.
    args: []const Node = &.{},
    loc: SourceLocation = .{},
};
```

### Dispatch logic in `evalInteropCall` (single TreeWalk arm)

```zig
fn evalInteropCall(rt, env, locals, n) !Value {
    return switch (n.kind) {
        .static_method  => evalStaticMethod(rt, env, locals, n),
        .instance_method => evalInstanceMethod(rt, env, locals, n),
        .instance_field  => evalInstanceField(rt, env, locals, n),
        .constructor     => evalConstructor(rt, env, locals, n),
    };
}
```

- `.static_method`: `n.descriptor.lookupMethod(null, n.name)` →
  `BuiltinFn`; call with `args` only (no receiver).
- `.instance_method`: eval `n.target`, resolve descriptor from
  the receiver's runtime tag, `lookupMethod(null, n.name)`, call
  with `[receiver, ...args]`.
- `.instance_field`: eval `n.target`, must be `typed_instance`,
  look up via `field_layout`.
- `.constructor`: if `n.descriptor.kind == .deftype` or
  `.defrecord`, use `type_descriptor.allocInstance(rt, td,
  args)`; if `.native` (Java surface), look up
  `"<init>"` in `method_table` and call as a `BuiltinFn`.

### Class-name resolution

A new `resolveJavaSurface(rt, env, ns_head) ?*const TypeDescriptor`
helper handles the cljw-prefix translation: descriptors are
keyed by `"cljw.java.util.UUID"` per ADR-0029 D5, but user
source writes `"java.util.UUID"`. The helper tries:
1. Literal `rt.types.get(ns_head)`.
2. `rt.types.get("cljw." ++ ns_head)`.
3. Short-name lookup via current-ns aliases (Phase 14+ ergonomic;
   may return `null` at v0.1.0).

The helper is used by both the analyzer's `(Class/method)` arm
and the constructor arm — closing the long-standing
`evalCtorCall` cljw-prefix gap that the survey called out.

### VM compile arm

```zig
.interop_call_node => {
    // VM-DEFER: interop dispatch bytecode shape pending row 7.6.b family lowering [refs: D-073, feature_deps.yaml#runtime/vm/interop_call_node]
    return error.NotImplemented;
},
```

One VM-DEFER row covers all four kinds. The bytecode lowering
decision (single `op_interop_call` with a kind tag in the operand,
or four separate opcodes) lands at row 7.6.b under D-073's
existing VM parity cluster — the same row that was already going
to choose the shape for the previous 3 separate Nodes. Net
effect: the VM-DEFER marker count drops from 3 to 1.

## Consequences

### Positive

- **Single dispatch abstraction for the entire Java/host interop
  surface.** A future reader sees one Node variant carrying every
  call shape; the kind tag picks the args layout. No "why does
  instance_method look so similar to static_method" reading
  burden.
- **VM-DEFER count drops 3 → 1.** D-073's parity cluster shrinks
  on landing. The bytecode shape decision becomes one decision
  instead of four parallel ones.
- **CallSite cache (ADR-0008) integration is unified.** Each call
  site caches `(descriptor, name) → MethodEntry` once for both
  instance and static; no parallel cache infrastructure.
- **The `evalCtorCall` cljw-prefix gap closes structurally.** The
  same `resolveJavaSurface` helper that handles static dispatch
  also fixes ctor lookup; `(java.io.File. "x")` works after this
  ADR's commit without a separate one-line patch.
- **F-002 honored.** Finished-form wins over smallest-diff
  convenience. The "defer fusion to Phase 7 mid" framing — which
  the survey + DA-Alt-2 path implied — is removed.
- **F-009 honored.** The unified Node carries kind information
  because cw's internal model needs it (args layout differs), not
  because the JVM AST has parallel `StaticMethodExpr` /
  `MethodExpr` nodes to mirror. The internal abstraction is "Java
  surface dispatch with optional receiver", which is a cw v1
  shape choice.

### Negative

- **Migration scope expands.** This ADR's commit touches
  `eval/node.zig` (replaces 3 variants), `eval/analyzer/analyzer.zig`
  + `eval/analyzer/special_forms.zig` (4 analyzer arms now build
  `InteropCallNode`), `eval/backend/tree_walk.zig` (one
  unified eval arm), `eval/backend/vm/compiler.zig` (3 arms →
  1), `src/lang/diff_test.zig` (test descriptors renamed; cases
  unchanged in semantics), and the Java surface files
  (UUID/System/File method_table population). ~+450 LOC net
  including ADR + e2e + per-task note.
- **Kind enum is a flat tag, not a tagged union.** A
  `static_field` kind with non-empty `args` is meaningless but
  the type system does not prevent it. Mitigated by a debug
  assert in `evalInteropCall`'s entry; promoted to a tagged
  union if a Phase-7-mid review surfaces real misuse.
- **Existing diff-case test names reference the retired Node
  names** (`"diff: ctor_call_node second field"`). These get
  renamed to `"diff: interop_call_node .constructor + field"`-
  style in the same commit. Test bodies don't change.

### Neutral

- The `D-121` debt row closes on this commit's SHA. A new
  `D-130` row opens to track the **VM lowering** of
  `interop_call_node` (the remaining VM-DEFER) — this row inherits
  D-073's cluster scope for the interop subset.
- ADR-0007 / ADR-0008 / ADR-0029 stay in force. The Node-level
  unification is purely an analyzer-layer consolidation; the
  TypeDescriptor + method_table + cljw-prefix conventions they
  set continue to be the dispatch primitive.

## Alternatives considered

The Devil's-advocate subagent's output is reproduced verbatim
below (the alternatives the loop's accumulated momentum would not
have considered without an isolated context fork). The DA's
recommendation was Alt 2; the user's intervention surfaced that
this recommendation itself was Progress-pressure-smell-driven,
and that Alt 3 is the F-002-aligned choice.

### Alt 1 — Reuse `MethodCallNode` with a sentinel receiver

Synthesise a `type_ref_node` leaf and pass the class handle as
`args[0]`; each static `method_table` entry remembers "first arg
is the class". −110 LOC.

**Rejected** on `silent-default-shift smell` grounds
(`.dev/principle.md`): every static `BuiltinFn` body has to
slice `args[1..]` and a forgotten slice silently passes the
class handle as user arg 0. The smell sensor catches it
specifically; not a candidate.

### Alt 2 — Two-Node split: `StaticMethodCallNode` sibling to `MethodCallNode`

The survey's recommendation. New variant for statics; existing
`MethodCallNode` / `FieldAccessNode` / `CtorCallNode` stay; +3
VM-DEFER rows persist; +0 LOC vs survey estimate (290).

**Rejected** on F-002 grounds. The DA itself flagged this as
"borderline F-009 friction (mirrors JVM AST shape)"; the user's
intervention crystallised that the "defer fusion to Phase 7 mid"
rationale is itself the Progress-pressure smell. Fusion is the
finished-form; landing it now closes 2 existing VM-DEFER rows
while solving D-121, and removes a debt row that would otherwise
sit deferred for indefinite time.

### Alt 3 — Unified `InteropCallNode` with `kind` tag (this ADR)

Single Node variant parameterised by a 4-way kind enum. Retires
`MethodCallNode` + `FieldAccessNode` + `CtorCallNode` in the same
commit; 3 VM-DEFER markers consolidate into 1; v0.5.0 maintainer's
shape per the DA's framing. +60 to +90 LOC vs Alt 2 (350-380
total including the existing-Node migration).

**Accepted.** The cycle-budget objection is itself the smell the
user surfaced; the structural benefit is exactly what F-002
demands.

## Implementation order

1. Add `InteropCallNode` to `src/eval/node.zig` (alongside the
   retiring variants for one transitional commit step — see
   below).
2. Build `InteropCallNode` from each analyzer arm
   (`analyzeStaticMethodCall` new; `analyzeCtorCall` /
   `analyzeFieldAccess` / `analyzeMethodCall` retargeted).
3. Add `evalInteropCall` to `tree_walk.zig` with the 4-way
   switch.
4. Replace 3 VM compile arms with 1 `.interop_call_node` arm +
   VM-DEFER marker.
5. Remove the retired Node variants from `node.zig` (and the
   matching arms from analyzer + tree_walk + vm/compiler) — the
   compiler-enforced exhaustive switch verifies completeness.
6. Populate `method_table` for UUID/randomUUID,
   System/currentTimeMillis, System/nanoTime, File/<init>.
7. Add `resolveJavaSurface` helper; wire into static + ctor
   analyzer arms.
8. Add Layer 2 e2e test `test/e2e/d121_java_static.sh` (4 cases).
9. Add Layer 3 diff_test case for static dispatch; rename the 3
   existing diff_test descriptors to reference `interop_call_node`.
10. Update `feature_deps.yaml`: consolidate the 3 existing
    parity-defer entries into one `runtime/vm/interop_call_node`
    entry; close D-121, open D-130.

Steps 1-5 may land as one Node-level commit; step 6-9 as a second
commit if the diff stays focused. Step 10 lands with the source
commits (provisional-marker hook + dual-backend-parity hook
verify the bookkeeping is in sync).

## Discharge condition

This ADR's Decision is fully implemented when:

- `grep -nE '\\.(method_call|field_access|ctor_call)_node\\b' src/`
  returns 0 lines (all retired).
- `grep -nE '\\.interop_call_node\\b' src/eval/{node,backend/tree_walk,backend/vm/compiler}.zig`
  returns exactly one analyzer + one TreeWalk + one VM-DEFER arm.
- `bash test/run_all.sh` passes on Mac with the new e2e + diff
  cases; ubuntunote re-verified at Phase boundary.
- D-121 row in `.dev/debt.md` flips to `Discharged (<sha>)`.
- D-130 (VM lowering of `interop_call_node`) opens with the
  expected barrier predicate (Phase 7 mid VM lowering row).

## References

- `.dev/debt.md` D-121, D-073, (new) D-130.
- `.claude/rules/dual_backend_parity.md` (the VM-DEFER discipline
  this ADR consolidates 3 sites of).
- `.dev/principle.md` (Progress-pressure smell, Smallest-diff
  bias smell — the user's intervention names both).
- `.dev/project_facts.md` F-002, F-009.
- `private/notes/phase14-d121-survey.md` (Step 0 output).
- `private/notes/phase14-d121-da-fork.md` (Devil's-advocate
  output, verbatim above under Alternatives considered).
- ADR-0007, ADR-0008, ADR-0029 D5 (TypeDescriptor + method_table
  + cljw-prefix; in force).
- ADR-0036 (dual-backend parity contract; the consolidation
  honors this).

## Amendment 1 (2026-05-29) — instance member-vs-field dispatch + native-type method coverage

> Status: **Accepted** (design phase: survey + Step 0.6 + mandatory
> Devil's-advocate fork landed 2026-05-29). Source implementation is the
> next cycle's first commit (this amendment is the depth-2 doc commit that
> precedes it per CLAUDE.md Step 6). Supersedes the row-7.6 "Option A"
> arity-1-`.name`-is-a-field decision.

### Context (amendment 1)

Verified 2026-05-29: interop instance-method calls + native-type methods
are broken even in TreeWalk (the production-default backend):

- **Q1 — `(Math/abs -5)` → "No namespace: 'Math'"**: the qualified-head
  arm (`analyzer.zig` ~505) calls `resolveJavaSurface("Math")`, which only
  tries `"Math"` / `"cljw.Math"`; `java.lang.Math` is unregistered
  (`runtime/java/lang/` ships only `System.zig`) and there is no short-name
  (`java.lang.` prefix) resolution path (deferred at ADR-0050 R3). Only the
  FQCN form `(java.lang.System/...)` works today.
- **Q2 — `(.toUpperCase "hi")` → "field access: expected number, got
  string"**: `analyzer.zig:484` routes arity-1 `.name` (`items.len == 2`)
  UNCONDITIONALLY to the `.instance_field` kind (the row-7.6 "Option A"
  decision, made when only deftype/record FIELD reads existed);
  `.instance_method` needs `items.len >= 3`. So a no-arg instance method
  becomes a field read, and `evalInstanceFieldRead`/`op_field_access`
  hard-require a `.typed_instance` receiver — a String is not. Secondarily,
  the `.string` native TypeDescriptor's `method_table` (`runtime.zig`
  ~162-180) is EMPTY: no native String methods are wired anywhere.

Two premises were corrected during Step 0.6 + the DA fork: (1) `(.-name)`
does NOT currently route to field — there is no dash-stripping arm, so
`(.-x p)` reads a field literally named `-x` and fails; `.-` support is
NEW work, not a preserved invariant. (2) The eval layer is ALREADY
receiver-polymorphic (`evalInstanceMethodCall` + VM `op_method_call`
resolve native receivers via `nativeDescriptor`); the bug is purely the
analyzer arity gate + the empty String `method_table`.

### Decision (amendment 1) — Alt 2: single `.instance_member` kind

Collapse `.instance_field` + `.instance_method` into ONE kind; resolve
member-vs-field at eval from the receiver's descriptor shape.
`InteropCallNode.Kind` → `{ static_method, instance_member, constructor }`
(3, down from 4). `.instance_member` carries `target` / `name` / `args`
(empty args legal) + a `field_only: bool = false` flag (set for `.-name`).

- **Analyzer**: arity-≥1 `.name` → `.instance_member{field_only=false}`
  (the arity-1-vs-≥3 split disappears); `.-name` → `field_only=true` (NEW
  arm). `Name.` ctor + `Class/method` static arms unchanged.
- **Both backends — ONE shared receiver-keyed resolver**:
  ```
  if recv is typed_instance/reified:     // ONLY these have field_layout
      if field_layout has name: field-read     // FIELD-FIRST
      if field_only: raise no-such-field
  if not field_only:
      if td.lookupMethod(name): call(recv, ...args)
  raise (field_only ? no-field : no-member)
  ```
  TreeWalk: one `evalInstanceMember` (converges the method + field arms).
  VM: reuse `op_method_call`'s call-site machinery; **retire
  `op_field_access`** (its typed-instance-only logic folds into the
  resolver). ≥1 differential case each: native-method / native-field /
  deftype-field (ADR-0036).
- **String surface**: `runtime/java/lang/String.zig` (the `System.zig`
  pattern, F-009 thin over `runtime/collection/string.zig`) populating the
  `.string` descriptor's `method_table`.

**Three caveats (load-bearing — fold into the implementation):**

1. **FIELD-FIRST, keyed on `field_layout` presence** (the typed_instance/
   reified branch), NOT method-then-field. `field_layout` is non-null ONLY
   for deftype/record; native types have `field_layout == null` so go
   straight to `method_table`. method-then-field would let a protocol
   method named like a field silently shadow the field (Silent-default-
   shift smell). This is the clean deftype `(.field rec)` regression
   guarantee. JVM's method-wins precedence is moot here — cw has no JVM
   reflection (ROADMAP §13); deftype fields are first-class named slots and
   field-first is the cw-native precedence.
2. **`.-name` is NEW work** (no dash-stripping arm today). No corpus/test
   uses `(.-` (confirmed). Alt 2 adds it via `field_only`; deferring is
   defensible ONLY if the current `-x` mis-read becomes an explicit error.
3. **String `method_table` wiring is ORTHOGONAL + was under-scoped**:
   `nativeDescriptor` LAZILY allocates per-Runtime with an empty
   `method_table`; `System.zig` installs into a STATIC descriptor, but
   native-tag descriptors are per-Runtime, so String needs an
   `installNativeMethods(rt)` at runtime init populating
   `rt.native_descriptors[@intFromEnum(.string)]`.

`Math/abs` (Q1) — registering `java.lang.Math` + short-name resolution —
is the immediate follow-on, not in the minimal Alt 2 dispatch fix. D-130
(the `.static_method` VM bytecode arm) rides this or stays its own cycle.

### Alternatives considered (amendment 1)

(Devil's-advocate subagent, fresh context, F-NNN envelope — verbatim. It
corrected the two premise errors above.)

> **Alt 1 — Smallest-diff: flip the analyzer arity gate, keep two kinds.**
> Route arity-1 `.name` → `.instance_method` with method-then-field
> fallback at eval; add a `.-` arm → `.instance_field`; wire String
> method_table. *Better:* minimal blast radius, no Node-kind retirement,
> fastest to green. *Breaks:* method-then-field is the fragile ordering
> (field/method name-collision silently shadows the field — Silent-
> default-shift); fallback must be added to BOTH backends across two
> DIFFERENT opcodes → ADR-0036 drift; the kind tag no longer means what it
> says (decided at eval, not analyze); nativeDescriptor lazy-alloc wiring
> under-scoped. *F-NNN:* clears F-009/R4/Tier; FAILS F-002 (smallest-diff
> convenience the finished-form owner unwinds).
>
> **Alt 2 — Finished-form-clean: single `.instance_member` kind + one
> shared receiver-keyed resolver per backend.** [As decided above.]
> *Better:* kind tag stops lying; field-first keying eliminates the
> collision smell structurally; backends CONVERGE (one resolver + one
> opcode, down from two) → ADR-0036 parity is a SINGLE decision; retiring
> op_field_access removes the latent native-field rejection; mirrors
> ADR-0050's own original collapse-4-into-1 logic. *Breaks:* largest diff
> (retires a Node kind + an opcode; parity hook forces all arms in one
> commit); `field_only` is a 2nd discriminant (set in one analyzer arm);
> retiring op_field_access needs the field-read diff cases re-encoded onto
> the unified opcode (arg_count=1 receiver-only path is new); String
> method_table wiring still required + orthogonal. *F-NNN:* clears F-002/
> F-009/ADR-0036/R4/Tier/§13 (precedence is a cw-native descriptor-shape
> choice; `.-` is the one observable-Clojure JVM nod, not a JVM-internal
> assumption). NO F-NNN amendment required.
>
> **Alt 3 — Wildcard: analyze-time resolution for statically-known native
> receivers.** Bake the resolved method/field into the node when the
> receiver is a literal of known native type; else Alt 2's runtime
> resolver. *Better:* zero runtime dispatch for literal receivers;
> analyze-time "no such method" diagnostic. *Breaks:* TWO code paths for
> the same form (re-introduces the reading burden ADR-0050 killed); a new
> static-type mini-analysis with edge cases; diverges from Clojure's
> runtime-reflective `.name` dynamism (`(def s "x")` then `(.toUpperCase
> s)` is not statically resolvable — inconsistent); baked nodes go stale if
> `extend-type` adds a method (re-implements the CallSite-cache
> invalidation at the wrong layer). *F-NNN:* clears F-002/F-009/Tier/R4 in
> principle but mismatches §13 / the ADR-0008 CallSite-cache finished form.
>
> **Recommendation (non-binding): Alt 2.** Only alternative that does not
> lie about the kind tag or split backends asymmetrically; it is the SAME
> structural move ADR-0050 itself made. Cycle/diff size is not a project
> constraint (F-002) — Alt 2's larger diff is the cost to pay. Caveats:
> (1) field-first keyed on field_layout, NOT method-then-field; (2) `.-`
> is new work (defer only with an explicit error for the `-x` mis-read);
> (3) String method_table needs `installNativeMethods(rt)` at init.

### Affected files (amendment 1)

- `src/eval/node.zig` (`InteropCallNode.Kind` → 3 variants + `field_only`)
- `src/eval/analyzer/analyzer.zig` (~478-491 dot arms: collapse field/
  method, add `.-` arm)
- `src/eval/backend/tree_walk.zig` (`evalInstanceMember` converges
  `evalInstanceMethodCall` + `evalInstanceFieldRead`)
- `src/eval/backend/vm/compiler.zig` + `vm.zig` (converge onto
  `op_method_call`; retire `op_field_access`)
- `src/runtime/runtime.zig` (`installNativeMethods` + `.string`
  method_table population) + `src/runtime/java/lang/String.zig` (new)
- `src/lang/diff_test.zig` (native-method / native-field / deftype-field)
- `test/e2e/` (new: `(.toUpperCase "hi")` / `(.x deftype)` / `(.-x …)`)
- `.dev/debt.md` (D-130 rides-or-follows)

### Consequences (amendment 1)

- Instance methods on native types (String, …) work in BOTH backends;
  `(.x rec)` deftype field reads preserved via field-first keying.
- One member-access kind + one opcode (down from two) — ADR-0036 parity is
  a single decision; `op_field_access` retired.
- `Math/abs` short-name static resolution (Q1) is the immediate follow-on.
- D-130's `.static_method` VM arm is the remaining VM-DEFER; rides or
  follows this cycle (its bytecode-shape decision is separate).

### Implementation order (amendment 1)

(1) This ADR commit (doc, depth-2) lands first. (2) node.zig Kind + analyzer
2 arms + TreeWalk `evalInstanceMember` + VM converge/retire + runtime
`installNativeMethods` + String surface + diff cases + e2e — one atomic
source commit (the parity hook + exhaustive switch force it). (3) Verify NO
deftype `(.field rec)` regression (gate + targeted deftype field e2e).

### References (amendment 1)

- `private/notes/interop-coverage-survey.md` (Step 0 output — root causes).
- `private/notes/interop-DA-alt2.md` (Step 0.6 + the DA output verbatim
  above; locked design).
- `.dev/debt.md` D-130 (`.static_method` VM arm).
- `.dev/principle.md` (Silent-default-shift, Smallest-diff bias, Cycle-
  budget defer — the smells this amendment's field-first + Alt-2 choices
  answer).
- ADR-0007 / ADR-0008 (TypeDescriptor + method_table + CallSite cache);
  ADR-0036 (dual-backend parity); ROADMAP §13 (no JVM class hierarchy).
