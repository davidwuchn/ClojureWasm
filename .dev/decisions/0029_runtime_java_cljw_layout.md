# 0029 — Runtime java/ + cljw/ layout, feature-implementation neutrality, ADR-0011 supersede

- **Status**: Accepted
- **Date**: 2026-05-24
- **Author**: Shota Kudo (drafted with Claude during user-directed structural session)
- **Tags**: phase-5-late, structure, host, interop, java, cljw, supersedes-0011
- **Supersedes**: ADR-0011

## Context

ClojureWasm v1 is mid-Phase-5. Phase 6 entry will start landing Java
stdlib equivalents (`java.util.UUID`, `java.io.File`, `java.time.Instant`,
…), and the current ADR-0011 has reserved `src/runtime/host/{lang, io,
util, time, net, nio, math, security, sql, text, reflect, concurrent}/
<Class>.zig` with 13 `_placeholder.zig` files.

Before any of those host classes land, a user-directed structural
session (2026-05-24) surfaced six concerns:

1. **Implementation sharing is required.** `(random-uuid)` (Clojure
   core) and `(java.util.UUID/randomUUID)` (Java surface) must share
   the same 16-byte random-bytes generator. The cw-v0 pattern (impl
   written directly inside `src/lang/interop/classes/uuid.zig`) cannot
   achieve this.
2. **File fan-out is structurally unavoidable.** One feature needs at
   minimum three files (impl body / surface wrapper / Clojure-ns
   registration). This is a structural lower bound; mitigation must
   come from discoverability (feature-name consistency + index
   integrity), not from collapsing files together.
3. **The `runtime/host/` name and layer are misleading.** `host` is
   double-charged with both OS / syscall meaning and Java-compat-surface
   meaning. A direct Java-namespace mirror `runtime/java/<pkg>/<Class>.zig`
   reads more naturally.
4. **cljw-only features** (wasm component invoke, edge runtime, build
   command, etc.) deserve the same thin-wrapper structure. A symmetric
   `runtime/cljw/<area>/<Item>.zig` layout pays for itself once Phase
   12+ work begins.
5. **Smallest-diff bias of the "let's collapse 18 host classes into
   their wrappers" shape** is almost certain to surface at Phase 12+
   when host-class count grows. A structural device that prevents the
   AI loop from doing this autonomously is needed.
6. **Internal dependency direction inside `runtime/` is undocumented**,
   but a 5-sub-zone scheme (an earlier draft) was judged excessive.
   A single rule — "surface layer calls neutral impl, never the
   reverse" — is sufficient.

In addition, the zwasm-v2 Java-InterOp premise (recorded in user
context this session):

> For what is supported, no error surfaces; the internal implementation
> need not mirror Java; equivalent inputs and outputs (with side
> effects where applicable) are achieved via Zig-idiomatic means.

This premise means Java surfaces are *not obligated* to reproduce JVM
internal representations exactly, which is what justifies sharing
implementations between Clojure and Java entry paths.

## Decision

### D1. Directory layout

Retire `runtime/host/`. Replace with:

- **Neutral implementation layer**: flat under `src/runtime/`.
  Examples: `runtime/uuid.zig`, `runtime/clock.zig`, `runtime/random.zig`,
  `runtime/uri_parse.zig`, `runtime/path.zig`, `runtime/file_io.zig`,
  `runtime/charset.zig`. Multi-file features land in sub-directories:
  `runtime/regex/{compile, match}.zig`,
  `runtime/crypto/{secure_random, message_digest}.zig`,
  `runtime/time/{instant, local_date, …}.zig`.
  These are **namespace-neutral** — they wrap OS / Zig std and depend
  on neither the Clojure nor the Java namespace.

- **Java-compat surface**: `src/runtime/java/<pkg>/<Class>.zig`.
  Examples: `runtime/java/util/UUID.zig`, `runtime/java/io/File.zig`,
  `runtime/java/time/Instant.zig`. Structure is 1:1 with the Java FQCN
  (`java.util.UUID` → `java/util/UUID.zig`). Each file is a **thin
  wrapper** that calls the neutral impl layer.

- **cljw-native surface**: `src/runtime/cljw/<area>/<Item>.zig`.
  Examples: `runtime/cljw/wasm/Engine.zig`,
  `runtime/cljw/build/Compiler.zig`, `runtime/cljw/edge/Server.zig`.
  cw-original value-add features (Zig extensions, not Clojure
  libraries). Each file is a thin wrapper symmetric with the Java
  surface.

- **Disposition of the 13 existing placeholders**:
  - `runtime/host/_host_api.zig` → moved to `runtime/java/_host_api.zig`
  - `runtime/host/{lang, io, util, ...}/_placeholder.zig` → removed
  - `runtime/host/` directory removed

### D2. Dependency direction (single rule)

> No file under `runtime/` other than those in `runtime/java/**` and
> `runtime/cljw/**` may import from `runtime/java/**` or
> `runtime/cljw/**`.

That is: surface layers (java/, cljw/) call the neutral impl layer;
the reverse direction is forbidden. Cross-references inside the
neutral impl layer (`runtime/value/`, `runtime/collection/`,
`runtime/uuid.zig`, …) are left to natural import discipline and are
not codified in an ADR. If real friction emerges later, an additional
gate can be added at that point.

### D3. Feature-implementation neutrality (promoted to F-009)

A new user-declared invariant is added to `.dev/project_facts.md`:

> Feature-implementation bodies (the place where OS / Zig std is
> invoked, or where cw-original compute logic lives) reside in
> **namespace-neutral locations** — `src/runtime/` (flat) or
> `src/runtime/<feature>/` (when multiple files). Clojure-ns paths
> (`src/lang/primitive/<feature>.zig` or
> `src/lang/clj/clojure/<…>.clj`), Java-ns paths
> (`src/runtime/java/<pkg>/<Class>.zig`), and cljw-ns paths
> (`src/runtime/cljw/<area>/<Item>.zig`) all connect to the neutral
> impl **as thin wrappers from above**. Cross-surface calls
> (a Clojure-ns wrapper calling into a Java-ns wrapper, or vice versa)
> are forbidden — both share the neutral impl.

F-009 status grants the Devil's-advocate subagent (CLAUDE.md § Smell
triggers are interrupts, not stops) the authority to automatically
reject "let's inline the impl into the surface file" alternatives as
out-of-envelope, with user-direction-only amendment.

### D4. Guardrails (three scripts)

| #      | Script                             | Purpose                                                                                                                                                                                                                                         |
|--------|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **G1** | `scripts/zone_check.sh` (extended) | Detects D2 violations: any non-`runtime/java/**` / non-`runtime/cljw/**` file importing from `runtime/java/**` or `runtime/cljw/**`                                                                                                             |
| **G2** | `scripts/check_surface_marker.sh`  | Requires each `runtime/java/**/*.zig` and `runtime/cljw/**/*.zig` to declare a Backend marker docstring header: `//! Backend: <impl-only \| collection-only \| impl+collection \| surface-only>` + `//! Impl deps: …` + `//! Clojure peer: …` |
| **G3** | `scripts/check_feature_keyword.sh` | Verifies that `compat_tiers.yaml` `keyword:` values appear in every file path listed under that entry's `files:` map (guarantees 100% grep-hit on the feature keyword)                                                                          |

All three are wired into `test/run_all.sh` and gate both Mac and
Linux (OrbStack x86_64) runs.

### D5. `compat_tiers.yaml` schema extension

The existing entry shape `{ fqn, native_ns, phase }` is extended to:

```yaml
- fqn: java.util.UUID
  cljw_ns: cljw.java.util.UUID       # was: native_ns: cljw.host.* (host. prefix dropped)
  keyword: uuid                       # validated by G3
  tier: A
  phase: 5
  files:
    surface: runtime/java/util/UUID.zig
    impl: runtime/uuid.zig            # neutral implementation body
    impl_extras: [...]                # additional sub-impls the impl calls
    wrap: runtime/collection/string.zig
    clojure_peer: lang/primitive/uuid.zig
  methods: [randomUUID, fromString, toString, ...]
  clojure_peer_vars: [clojure.core/random-uuid, clojure.core/parse-uuid]
```

A runtime command `cljw --list-host-classes` (planned by Phase 14)
reads this same YAML, giving development-time (static yaml grep) and
runtime (`cljw` command) two-axis coverage visibility.

### D6. ADR-0011 disposition

ADR-0011's `Status` field is changed from `Accepted` to `Superseded
by ADR-0029`. The `___HOST_EXTENSION` marker pattern itself
(distributed registration replacing a central registry) is carried
forward by this ADR; only the registration root changes from
`host/_host_api.zig` to `java/_host_api.zig`.

## Alternatives considered

Because this ADR was drafted during a user-directed structural session
with multiple rounds of alternative exploration in chat, the
Devil's-advocate fork pass has been replaced by recording each
considered shape here in full.

### Alt 1: Five sub-zones inside `runtime/` (earlier draft, rejected)

Split `runtime/` into core / clj-core / capability / extension / host,
fix a cross-reference table in the ADR, and gate the table.

- **Pros**: structurally strict, every sub-zone responsibility named.
- **Cons**: five-layer naming (especially `capability`) feels abstract;
  the relationship with the existing flat layout
  (`runtime/io_interface.zig`, `runtime/hash.zig`, etc.) becomes
  hand-wavy; seven guardrail scripts are excessive.
- **Rejected because**: user feedback was "we don't even need a `sys/`
  partition; flat under `runtime/` reads better; the layer emphasis is
  overdone."

### Alt 2: `runtime/host/java/` + `runtime/host/cljw/` (mid-draft, rejected)

Keep `host/` and place `java/` and `cljw/` beneath it.

- **Pros**: aligns with the `host_classes` concept in
  `compat_tiers.yaml`.
- **Cons**: double-meaning of `host` (OS / Java surface); one extra
  directory level.
- **Rejected because**: user judged "`runtime/java/` is more
  intuitive than `runtime/host/java/`."

### Alt 3: `runtime/interop/java/` + `runtime/interop/cljw/` (exploratory, rejected)

Rename `host` to `interop`, inheriting cw-v0's `src/lang/interop/`
naming.

- **Pros**: continuity with cw v0.
- **Cons**: `interop` is vague (interop with what?); reads
  particularly thin once Java-compat and cljw-original are listed
  side by side.
- **Rejected because**: user judged "just inherit the Java namespace
  directly."

### Alt 4: Pull host out of `runtime/` and make `src/host/` a peer zone (late draft, rejected)

Six-zone shape: `src/{runtime, capability, host, eval, lang, app}`.

- **Pros**: purifies `runtime/`; host gains independence.
- **Cons**: directory tree grows from 4 to 6 top zones;
  `___HOST_EXTENSION` registry discovery becomes "borrow types from
  outside" rather than co-located.
- **Rejected because**: user judged "if we want runtime-internal
  conveniences, host-ish and capability-ish things belong under the
  runtime directory."

### Alt 5: Keep neutrality as ADR-only, do not promote to F-009 (exploratory, rejected)

Write the neutrality principle into ADR-0029 only; do not register
it as F-NNN.

- **Pros**: lightweight; future flexibility for the AI loop to
  amend.
- **Cons**: at Phase 12+ with many host classes the AI loop is likely
  to propose "inline impl into the surface for fewer files," with the
  Devil's-advocate subagent generating three plausible alternatives.
  F-009 lets the Devil's-advocate subagent reject envelope-violating
  alternatives automatically.
- **Rejected because**: user chose "promote to F-009."

## Consequences

### Positive

- **Structural answer to fan-out.** F-009 + three guardrails +
  keyword-consistent naming + `compat_tiers.yaml` index guarantee
  that, even with fanned-out files, "grep by feature keyword
  yields 100% hit" is maintained.
- **Symmetry.** Java surfaces and cljw-native surfaces use the same
  shape (thin wrapper + Backend marker + cljw_ns registration).
- **No misreadings.** `runtime/java/<pkg>/<Class>.zig` is 1:1 with
  Java FQCN; the double-meaning of `host/` disappears.
- **Smallest-diff bias prevention.** F-009 lets the Devil's-advocate
  subagent automatically defend against future AI-driven design
  erosion.
- **Dependency rule fits on one line.** The earlier draft's
  five-layer cross-reference table compresses to "surfaces call
  neutral, never the reverse."

### Negative

- **Large amendment fan-out among existing documents.** ADR-0011
  supersede / ROADMAP §5 §6.0 / structure_plan.md /
  host_extension_layout.md (renamed) / compat_tiers.yaml (schema
  extension) / project_facts.md (F-009 added) / handover.md. All
  manageable in one user-directed sweep but non-trivial.
- **Existing 13 placeholders are deleted.** ADR-0011's reserved
  directories are wiped. If any of them are needed later, they
  re-emerge under `runtime/java/` or `runtime/cljw/`. The 40
  entries in `compat_tiers.yaml host_classes` all migrate cleanly
  under `runtime/java/` via the schema extension.

### Neutral / follow-ups

- **`runtime/error/` and `runtime/io/` consolidation.** The old
  `error.zig` / `error_catalog.zig` / `error_print.zig` files become
  `runtime/error/{info, catalog, print}.zig`; the old
  `io_interface.zig` becomes `runtime/io/interface.zig`, and Tier 2
  = `runtime/io/default.zig` lands later in Phase 5+ as a
  continuation of the ADR-0015 setup. This is delivered as Commit 3
  alongside the other ADR-0029 mechanics and serves as the first
  consolidation case study for follow-up moves (`hash/`, `keyword/`,
  …). `runtime/io/` will briefly hold a single file; a `_README.md`
  inside the directory explains the intent so the half-populated
  state does not read as accidental.
- **`runtime/hash/` split** waits for a real need (e.g., when a
  separate identity-hash variant becomes useful at Phase 6+) and
  ships as a separate small ADR.
- **`cljw_ns` rename (`cljw.host.*` → `cljw.*`).** Docs that
  reference the old prefix (`compat_tiers.yaml` body + related rule
  files) get a single batch update.
- **`cljw --list-host-classes`** runtime command, planned by Phase 14
  to read `compat_tiers.yaml` and emit the index at startup.

## References

- **Supersedes**: ADR-0011 (host extension mechanism).
- **Related ADRs**: ADR-0013 (Tier classification), ADR-0007
  (TypeDescriptor / Option β), ADR-0017 (Allocator strategy),
  ADR-0018 (error catalog SSOT), ADR-0023 (comptime stub).
- **New F-NNN**: F-009 (feature-implementation neutrality), landed
  alongside this ADR.
- **Amended docs**: ROADMAP §5 / §6.0; `.dev/structure_plan.md`;
  `.claude/rules/host_extension_layout.md` (renamed to
  `.claude/rules/java_cljw_surface_layout.md`); `compat_tiers.yaml`
  (schema extension).
- **New rule**: `.claude/rules/feature_name_consistency.md`
  (keyword consistency + Backend marker contract).
- **Proposal draft trail**: `.dev/proposals/host_layer_design.md`
  (v2 design memo) and `.dev/proposals/0029_runtime_java_cljw_layout_draft.md`
  (Japanese ADR draft) — both lived under `.dev/proposals/` (a
  scratch directory, never git-tracked) and were removed in
  Commit 6 of the cluster (772e16c, 2026-05-24).
- **Frequency data**: `private/clojure_frequent_java_interop/00a_frequency_overview.md`
  (host-class landing priority basis).

## Revision history

- 2026-05-24: Status: Proposed → Accepted (initial landing). Drafted
  during a user-directed structural session; replaces ADR-0011.
  F-009 added to `project_facts.md` in the same commit.
