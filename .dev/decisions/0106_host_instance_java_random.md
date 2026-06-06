# ADR-0106 — `host_instance` as a general stateful-host-object container; java.util.Random first user

- Status: Proposed → Accepted (2026-06-07)
- Drives: D-289 (java.util.Random stateful native object); campaign Stage 1.3
  ladder rung 5 (clojure.data.generators → test.check).
- Related: ADR-0104 (TypedInstance mutable slice), ADR-0050 (InteropCall),
  ADR-0059/AD-003 (no-JVM class), D-048 (host_instance catch-class markers),
  F-002 / F-003 / F-004 / F-005 / F-009 / F-011 / F-012 / F-013.

## Context

`(java.util.Random. 42)` fails (`arity_error … expected 0`) — the surface
(`runtime/java/util/Random.zig`) is reservation-only. clojure.data.generators
(rung 5) needs it with **Java-LCG parity** (F-011: a seed must reproduce the
JVM sequence). Java's 48-bit LCG (`0x5DEECE66D`) is confirmed bit-for-bit vs
the clj oracle + a Zig prototype; seed-42 first values: `.nextInt`
`-1170105035`, `.nextLong` `-5025562857975149833`, `.nextDouble`
`0.047939305137387644`, `.nextFloat` `0.9420735`, `.nextBoolean` `false`,
`(.nextInt r 100)` `30`, `.nextGaussian` `1.1419053154730547`.

Random is the first **stateful native object** (a Value carrying mutable
state), distinct from deftype instances + the (landed) JavaArray.

**Load-bearing constraint:** there is NO free Value tag — all 64 NaN-box heap
slots are assigned (F-004 64-slot ceiling; `encodeHeapPtr` guards `else =>
unreachable`). The only reusable slot is `host_instance` (tag 29), which is
DEAD: no value is ever constructed with it; it is referenced only by PROVISIONAL
D-048 catch-class markers (`class_name.zig:246`, `host_class.zig:222`) that
reserved it for exactly this "host object" purpose.

## Decision

Repurpose `host_instance` (tag 29) as a **general stateful-host-object
container** (NOT Random-specific) — because it is the LAST generic-host slot, so
consuming it Random-only would corner every future stateful host object
(SecureRandom, a stateful Matcher, …) with no tag and no shared shape (the
no-free-tags reality makes "solve it later" a guaranteed future layout-ADR).

```zig
pub const HostInstance = extern struct {
    header: HeapHeader,            // .host_instance tag, offset 0
    descriptor: *const TypeDescriptor,  // the rt.types SURFACE descriptor
    state: [4]u64,                 // inline fixed payload (no alloc, no finaliser)
};
```

1. **`descriptor` is the surface descriptor** registered by `installAll` into
   `rt.types` (FQCN `cljw.java.util.Random`) — the SAME descriptor
   `resolveJavaSurface` hands the constructor — so the `<init>` path and the
   instance-method path share one method_table (no desync). It carries the
   instance method_table (`.nextInt`/`.nextLong`/…).

2. **Dispatch reads the descriptor FROM THE INSTANCE** (mirroring TypedInstance,
   NOT the tag-keyed `rt.nativeDescriptor`, which would force all host types to
   share one method_table). Add a `.host_instance => decodePtr(*HostInstance)
   .descriptor` arm to `receiverDescriptor` (tree_walk.zig) + the VM
   `op_method_call` receiver resolution (vm.zig).

3. **`state` is inline-fixed `[4]u64`** (Random uses seed:u64 +
   gaussian-cache:f64 bit-cast + a have-gaussian flag; the 4th word is a free
   spare). NOT a `gc.infra` pointer — that would tax every host object with a
   finaliser + alloc + indirection for a rare unbounded-state need. A future
   big-state host type stores a `gc.infra` pointer in `state[0]` and registers
   its own finaliser.

4. **`(java.util.Random. seed)` / `(java.util.Random.)`** flow through
   `constructInstance`'s `<init>` path (special_forms.zig:124-129): the surface
   descriptor carries an `<init>` BuiltinFn that allocs a HostInstance with the
   descriptor + Java-LCG-seeded state (0-arg seeds from entropy via
   `runtime/random.zig`'s existing kernel-seed). Instance methods are BuiltinFns
   in the descriptor's method_table, installed at `installAll`. **Java's exact
   LCG** for the java.util.Random surface; `clojure.core/rand` keeps DefaultPrng
   (no parity need) — the two coexist in `runtime/random.zig`.

5. **`nextLong` returns a full 64-bit value (~5e18, past i48)** — it MUST box
   via `big_int.allocFromI64(rt, v, .long)` (origin `.long` so `integer?` /
   `(instance? Long …)` hold), NOT `initInteger` (which lossily floats anything
   past i48 — an F-005/F-011 bug the draft's first wiring had). `nextInt` /
   `nextInt(bound)` (i32) + `nextFloat` / `nextDouble` (f64) + `nextBoolean` are
   range-safe through `initInteger` / `initFloat` / `initBoolean`.

6. **Dual-backend free** (F-012): the constructor + instance members are
   existing InteropCallNode paths — no new analyzer Node. Only the two
   receiver-descriptor arms (point 2) are new, and the VM compile path is
   unchanged.

### GC trace hook DEFERRED per F-003

Random is a **leaf** (`state` holds only a u64 seed + f64 — no Value heap
refs), so tag 29 ships with **no trace registered** (leaf default), which is
correct for Random. The DA fork recommended adding a per-descriptor
`trace`/`finalise` hook on TypeDescriptor NOW so a future Value-holding
host_instance type cannot silently miss its trace. That hook is a **structural
change for a host type that does not exist yet** — F-003 (decision-deferral on
structural plans) defers it to its owning need. The deferral is made LOUD: (a) a
prominent comment on `HostInstance.state` ("leaf-only; a host type storing a
Value here MUST add a per-descriptor trace hook + register a tag-29 trace
dispatcher — see D-294"), and (b) debt row D-294. This is the F-003-correct
shape: ship Random's correct leaf, defer the future-type structural hook with a
loud guard, not a silent leaf-default on a shared tag.

### Accepted divergence

- **AD-020**: a `java.util.Random` (and any host_instance) prints opaquely as
  `#<java.util.Random>` — clj prints `#object[java.util.Random 0x… …]` with a
  non-reproducible identity hash. `derives_from` AD-002 (opaque-ref print) +
  ADR-0059. `(class (java.util.Random.))` → simple `java.util.Random` is the
  existing AD-003 surface (array/class-name), not a new AD.
- `nextGaussian` ships full parity (polar-method cache in `state`), so it is NOT
  a divergence.

## Alternatives considered (Devil's-advocate, fresh context)

> Verbatim from a fresh-context `general-purpose` DA fork. F-NNN envelope:
> F-002 / F-004 / F-005 / F-009 / F-011 / F-012 / F-013.

**LEADING FINDING (F-005 bug, applied to the Decision, not alternative-specific):**
`nextLong`'s ~5e18 result must use `big_int.allocFromI64(rt, v, .long)` —
`initInteger` (value.zig:198) lossily floats anything past i48, failing F-005 +
F-011. Only `nextLong` needs the boxed-Long path; pin the oracle long in a corpus.

**Alt 1 — Smallest-diff: Random-specific struct on tag 29, dispatch via the
tag-keyed `nativeDescriptor(.host_instance)`.** Better: smallest diff; no
per-instance-descriptor arm; 8 fewer bytes/instance. Breaks: consumes the LAST
generic host slot for Random alone — the next stateful host object has no tag
(F-004 forbids a 65th) and must retrofit this exact generic surgery with a live
tag-29 consumer to migrate. "Solve it later" is not viable with zero spare tags;
it guarantees the corner. Rejected on F-002.

**Alt 2 — Finished-form-clean (RECOMMENDED): general `HostInstance{header,
descriptor, state}` on tag 29, per-instance-descriptor dispatch.** Three
corrections the draft under-stated: (i) `descriptor` MUST be the rt.types
surface descriptor (else `<init>` FQCN-keyed and `.nextInt` instance-keyed read
two tables and desync); (ii) `state` inline-fixed `[4]u64`, NOT a gc.infra
pointer (a pointer forces a finaliser + alloc + indirection on every host
object); (iii) a per-descriptor trace/finalise hook to make leaf-ness explicit
per host type and close the silent-missing-trace hazard when a Value-holding
host type arrives. Better: only shape that leaves the next stateful host object
a home, keeps Random a finaliser-free in-place leaf, and (with iii) structurally
closes the trace hazard. Breaks: larger diff (not an F-002 constraint).

> **Main-loop adjustments (recorded):** Adopt Alt 2 with corrections (i) + (ii).
> Correction (iii)'s per-descriptor trace/finalise hook is **deferred per F-003**
> (structural change for a not-yet-existing Value-holding host type) — Random is
> a correct leaf today; the hook + a tag-29 trace dispatcher land with the first
> Value-holding host type (D-294 + a loud `HostInstance.state` comment as the
> guard). The DA rated (iii) "mandatory now"; F-003 (a user-declared invariant,
> higher than the DA recommendation) governs: defer the future-type structural
> hook with a loud marker rather than seize it now. The LEADING FINDING
> (nextLong boxed-Long) is applied — a present correctness fix, not deferred.

**Alt 3 — Wildcard: ride `typed_instance` (tag 30) with a mutable field, no new
tag.** Better: consumes no tag; reuses ADR-0104 setField's GC-safe in-place
mutation + the already-traced field array (solves the Value-holding case for
free). Breaks: the seed round-trips through a heap Value every draw (per-draw
alloc churn vs a bare `u64`); gaussian needs extra fields → a record
masquerading as a Random; semantically lies ("a Random IS a record", but records
are immutable). The finished form of a stateful native leaf is a bare struct,
not a secretly-mutated record. Rejected — but it is the genuine wildcard
(questions whether tag 29 should be spent at all).

**Probe answers:** general-over-specific (no spare tags → general-now is the only
non-cornering move); state inline N=4 (pointer taxes every host object); D-048 no
collision (Random isn't throwable; markers stay dormant, NOT discharged);
nextLong boxed-Long (leading finding); nextInt(bound)/gaussian/setSeed need
wrapping signed arith (`*%`/`+%`, `bits:u6`) per the prototype; GC leaf hazard
real but deferred per F-003 with the loud guard above.

## Consequences

- `(java.util.Random. seed)` + the instance method surface work with JVM-LCG
  parity → clojure.data.generators (rung 5) → test.check unblocked (LIVE).
- `host_instance` (tag 29) becomes the general stateful-host-object container;
  the next such object reuses it (descriptor-discriminated) — no tag exhaustion.
- New: HostInstance struct + 2 receiver-descriptor arms (both backends) + the
  Random surface (`<init>` + 8 methods, Java LCG). No new analyzer Node/opcode.
- `nextLong` boxed as a `.long`-origin BigInt (F-005). AD-020 (opaque print).
- D-294 opened: per-descriptor trace/finalise hook for a future Value-holding
  host_instance type (F-003 deferral; Random is leaf, guarded by a loud comment).
- D-048 markers stay dormant (a Random is not throwable) — NOT discharged.

## Affected files

- `src/runtime/value/value.zig` + `heap_tag.zig` — `host_instance` (tag 29)
  HostInstance struct + initHostInstance/asHostInstance glue.
- `src/runtime/random.zig` — Java-LCG `Random` (seed/next(bits)/nextInt/Long/
  Double/Float/Boolean/Int(bound)/Gaussian/setSeed), alongside DefaultPrng.
- `src/runtime/java/util/Random.zig` — fill the reservation: `<init>` + instance
  method_table (BuiltinFns over the LCG impl), via installNativeMethods-style.
- `src/eval/backend/tree_walk.zig` (receiverDescriptor) + `vm.zig`
  (op_method_call receiver) — `.host_instance` arm.
- `src/runtime/class_name.zig` / `print.zig` — host_instance simple class name
  (AD-003) + opaque print (AD-020).
- `compat_tiers.yaml` — refresh the java.util.Random `methods:` (add nextFloat/
  nextBoolean/nextGaussian).
- `.dev/accepted_divergences.yaml` — AD-020 + pin.
- `.dev/debt.yaml` — D-289 discharge + D-294 (deferred trace hook).
- `test/e2e/` + `test/diff/clj_corpus/` — parity corpus (the oracle seed-42
  values) + e2e.
