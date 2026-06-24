# ADR-0161 — General host-enum mechanism: one `.host_instance` registry for the four JVM host enums

- **Status**: Proposed → Accepted (2026-06-24; D-510 discharge; DA-fork incorporated)
- **Driven by**: D-510. ADR-0160 (RoundingMode) was the second one-off host-enum
  singleton after ChronoUnit; the DA-fork there explicitly recorded that the
  finished form is a first-class mechanism and deferred it to D-510. The barrier
  (a 2nd/3rd host enum actually needed) has dissolved — there are now FOUR host
  enums across TWO representations, which is the duplication D-510 exists to retire.
- **Relates to**: ADR-0160 (RoundingMode host-enum singleton — the immediate
  predecessor this generalises), ADR-0106 (`.host_instance` container), ADR-0115
  (Locale singleton pattern), ADR-0061/0087 (static-field resolve at analyze time),
  ADR-0059 / AD-003 (no-JVM simple class name), AD-002 (opaque-ref `#<tag>` print),
  D-462 (DayOfWeek/Month typed_instance values). F-002 (finished-form wins), F-004
  (NaN-box 64-slot — no new tag), F-009 (impl/surface/peer split), F-011
  (behavioural equivalence), F-013 (closed-set host SSOT).

## Context

cljw modelled four JVM host enums with **two different representations**:

**Group A — `.host_instance` static-field singletons** (`java.math.RoundingMode`,
`java.time.temporal.ChronoUnit`): each constant a per-Runtime cached `.host_instance`
(`state[0]` = ordinal), reached via a `StaticFieldValue.rounding_mode: u8` /
`.chrono_unit: u8` union arm. `RoundingMode/HALF_UP` works today.

**Group B — `.typed_instance` getter-minted values** (`java.time.DayOfWeek`,
`java.time.Month`): each a `.typed_instance` (`fields()[0]` = ISO value) with ONE
per-Runtime descriptor, `temporal_print = .day_of_week`/`.month`, minted **fresh**
on every getter call (`(.getDayOfWeek ld)`). NO static-field constants —
`DayOfWeek/MONDAY` raises a Name error.

The clj oracle (the finished form to match), verified 2026-06-24:

- All four enums **have** static-field constants (`DayOfWeek/MONDAY`, `Month/JANUARY`,
  `RoundingMode/HALF_UP`, `ChronoUnit/DAYS`).
- `(str X)`: DayOfWeek/Month/RoundingMode → enum NAME; ChronoUnit → DISPLAY name
  ("Days", not "DAYS"). `.name` → always enum name. `.ordinal` → 0-based.
  `.getValue` (DayOfWeek/Month only) → 1-based ISO value.
- **Getters return the SAME singleton as the constant**:
  `(identical? (.getDayOfWeek some-monday) DayOfWeek/MONDAY)` → **true**. cljw's
  fresh-mint Group B makes this impossible today (and there is no constant to compare).
- clj's print form `#object[java.time.DayOfWeek 0x<hash> "MONDAY"]` embeds an
  unmirrorable identity hash — the AD-002 opaque-ref class.

So cljw's two groups even diverge from **each other**: Group A prints `#<fqcn>`
(opaque, no enum name); Group B prints bare `MONDAY` (name, no wrapper). Neither
matches clj. And Group B lacks the static-field constants AND the getter-singleton
identity that clj has. The two-representation split is a maintenance trap: a fifth
host enum has no single mechanism to copy, and `getValue` / `ordinal` / display-name
are scattered across four files.

## Decision

Introduce ONE host-enum mechanism, all four enums on `.host_instance`, with a
**comptime registry** + a **single flat registry-indexed cache + single interning
entry point** (the draft + DA Alt-3, adopted in full):

1. **`src/runtime/host_enum.zig`** (neutral) — a comptime registry. Each row =
   `{ fqcn, count, cache_base, name table, to_string table, value table (optional) }`.
   The four rows: RoundingMode (8), ChronoUnit (16), DayOfWeek (7), Month (12).
   Folds `rounding_mode.zig` + `chrono_unit.zig` + `time/day_of_week_value.zig` +
   `time/month_value.zig` into it. Exposes `singleton(rt, enum_idx, ordinal)`,
   `name`, `toString`, `value`, `ordinalCount`.
2. **One flat cache** `rt.host_enum_consts[43]` (8+16+7+12) indexed by
   `registry[enum_idx].cache_base + ordinal`, replacing `rt.rounding_modes[8]`,
   `rt.chrono_units[16]`, `rt.day_of_week_descriptor`, `rt.month_descriptor`.
   `singleton` is the **sole** minting point — every path (static-field read,
   getter return, method dispatch) routes through it, so `identical?` parity is
   structural: no getter can re-mint a fresh value.
3. **One `StaticFieldValue.host_enum { enum_idx: u8, ordinal: u8 }`** arm replacing
   `.rounding_mode` + `.chrono_unit`. The analyzer's `staticFieldValue` resolves it
   via `host_enum.singleton`.
4. **`TypeDescriptor.host_enum_idx: ?u8`** identifies a descriptor as a host enum
   (which one), replacing the `TemporalPrint.day_of_week`/`.month` arms. The
   print / equal / compare paths branch on it.
5. **DayOfWeek/Month GAIN static-field constants** via new surface files
   (`runtime/java/time/DayOfWeek.zig`, `Month.zig`) with `static_fields` tables
   registered in `rt.types` — so `DayOfWeek/MONDAY` resolves (clj-parity win).
   Their getters return the cached singleton (closes the `identical?` gap).
6. **One print path**: the `.host_instance` printer emits the enum's `toString`
   (name, or display name for ChronoUnit) keyed by `host_enum_idx`, dropping both
   the Group-A `#<fqcn>` opaque form and the Group-B `temporal_print` arms.
   `equal` (by descriptor + ordinal — interned, so pointer-identical) and `compare`
   (by ordinal — all four are Comparable in JVM) migrate to `.host_instance`.

`java.math.MathContext` is **not** a member: it is not a Java enum (value class with
a public constructor + standard constants, `state = {precision, mode}`). It stays a
`.host_instance` value class and remains a *consumer* of the mechanism (its
`:rounding` arg is now a typed RoundingMode enum). Its `.math_context: u8` arm is
unchanged.

Print divergence from clj (`#<DayOfWeek>` form vs `#object[… 0x… "MONDAY"]`) is the
pre-existing AD-002 opaque-ref class (unmirrorable identity hash) — no new AD.

## Alternatives considered

A `general-purpose` Devil's-advocate subagent (fresh context) was forked with the
active F-NNN constraints + the draft, and produced the following (reflected verbatim):

> ## Grounding (verified against source, 2026-06-24)
>
> - **Group A** (`rounding_mode.zig`, `chrono_unit.zig`): `.host_instance`,
>   `state[0]=ordinal`, reached via `StaticFieldValue.rounding_mode: u8` /
>   `.chrono_unit: u8` arms in `type_descriptor.zig` (L216/L219). Per-Runtime
>   fixed-array caches give `=`/`identical?` parity. `MathContext` is a
>   `.math_context: u8` arm consumer.
> - **Group B** (`time/day_of_week_value.zig`, `time/month_value.zig`):
>   `.typed_instance`, `fields()[0]=ISO value`, ONE per-Runtime descriptor each,
>   `temporal_print = .day_of_week`/`.month`. Getters mint **fresh** via
>   `day_of_week_value.make(rt, …)` (`local_date_value.zig:66`,
>   `local_date_time_value.zig:72`). Participate in `equal.zig:1119-1129`
>   (`isDayOfWeek`/`valueOf` by value field) and `compare.zig:203` (`temporalOrder`
>   typed_instance arm). NO static-field constants — `DayOfWeek/MONDAY` raises.
> - Both representations are F-004-legal (reuse existing tags 29 `.host_instance`
>   and the `.typed_instance` tag). The draft picks `.host_instance` as the single
>   home.
>
> The draft is sound and finished-form-clean. Below are three alternatives inside
> the F-NNN envelope, then a recommendation.
>
> ## Alternative 1 — Smallest-diff: leave representation split, add the four missing static-field constants only
>
> **Shape.** Do NOT unify representations. Keep Group A on `.host_instance` and
> Group B on `.typed_instance` exactly as today. Close only the *observable* parity
> gaps: add `DayOfWeek/MONDAY` … and `Month/JANUARY` … static-field constants by
> giving `type_descriptor.zig` two new `StaticFieldValue` arms
> (`.day_of_week_const: u8`, `.month_const: u8`) that resolve to a per-Runtime
> cached singleton (a `rt.days_of_week[7]` / `rt.months[12]` fixed-array cache
> mirroring `rt.rounding_modes`). Repoint `getDayOfWeekFn`/`getMonthFn` from
> `day_of_week_value.make` (fresh mint) to that cache so
> `(identical? (.getDayOfWeek monday) DayOfWeek/MONDAY)` holds. Add `name`/`ordinal`/
> `getValue` methods to each of the four descriptors individually.
>
> **Better than the draft.** Surgically minimal — touches no
> `equal.zig`/`compare.zig`/`print.zig` arms (they keep working as-is on
> typed_instance). Zero risk of regressing the temporal `=`/compare/print paths
> that are already green and corpus-locked. The `identical?` parity (the one
> genuinely impossible-today behaviour) is closed with the least moving parts. No
> new neutral module, no fold, no cache-shape migration.
>
> **What it breaks / costs.** It is the **Smallest-diff bias smell** crystallised,
> and it explicitly **violates the project's own forward reservation**:
> `chrono_unit.zig:11` already records "the eventual general host-enum mechanism
> (D-510) folds both", and the draft's whole reason for existing is that four
> near-identical enums with two representations, two cache shapes, two print paths,
> two equality paths, and (now) **four** static-field-arm pairs is exactly the
> duplication D-510 was opened to retire. This alternative *adds* a fifth and sixth
> `StaticFieldValue` arm and a third and fourth fixed-array cache, growing the very
> surface the registry was meant to collapse. Per F-002 (finished-form wins;
> cycle/diff size is not a constraint), shipping this because it is smaller is the
> disposition CLAUDE.md names forbidden. It also leaves the two-representation split
> as a permanent trap: the next person adding a host enum must guess which of two
> mechanisms to copy, and `getValue` (DayOfWeek/Month only) vs `ordinal` (all four)
> vs display-name (ChronoUnit only) stays scattered across four files instead of one
> registry table.
>
> ## Alternative 2 — Finished-form-clean (rival to the draft): unify on `.typed_instance` with a registry, NOT `.host_instance`
>
> **Shape.** One host-enum mechanism, but consolidate the **other** direction — fold
> all four onto `.typed_instance` (one integer field = the enum's distinguishing
> value), with a comptime registry `host_enum.zig` keyed by a per-Runtime descriptor
> pointer: Registry row = `{ fqcn, count, value_kind: .ordinal | .iso_value, name_fn,
> to_string_fn }`. RoundingMode/ChronoUnit migrate from `.host_instance` *to*
> `.typed_instance` (field[0]=ordinal); DayOfWeek/Month stay `.typed_instance`
> (field[0]=ISO value). Static-field constants resolve via ONE
> `StaticFieldValue.host_enum { enum_idx, ordinal }` arm to a per-Runtime cached
> singleton typed_instance. Print stays on the existing `temporal_print`-style
> descriptor flag, generalised to a `host_enum_print` enum that all four share
> (`name` vs `display` selectable per registry row) — extends the path
> `print.zig:1143` already has rather than introducing a `host_instance`-keyed print
> path. `equal.zig`/`compare.zig` keep their existing typed_instance arms (already
> present for DayOfWeek/Month at `equal.zig:1119` / `compare.zig:203`);
> RoundingMode/ChronoUnit *gain* a typed_instance equality arm (by descriptor +
> field), which is the same shape already proven for the temporal types.
>
> **Better than the draft.** Two concrete advantages. (1) **DayOfWeek/Month/ChronoUnit
> already have live, corpus-locked `equal`/`compare`/`print` machinery on
> `.typed_instance`** — this alternative *extends* proven paths and migrates only the
> two `.host_instance` enums *into* that fold, whereas the draft does the reverse: it
> rips DayOfWeek/Month *out* of their working typed_instance arms (the
> `equal.zig:1119-1129` `isDayOfWeek`/`valueOf` arms, the `compare.zig` `temporalOrder`
> arm, the `print.zig` `.day_of_week`/`.month` arms) and re-implements all of them
> host_instance-keyed — a larger, riskier touch on the more heavily-exercised half.
> (2) `.typed_instance` carries a real `field_layout` and participates in the standard
> field-walker, so a future moving GC sees the value field natively;
> `.host_instance.state[]` is a raw `[4]u64` that `host_instance.zig:50-56` explicitly
> flags as **invisible to the field-walker** (needs a `host_trace` hook for moving GC,
> debt D-318). Enum singletons are immutable scalars so this is academic today, but the
> typed_instance home is the one that does not owe the moving-GC migration a hook.
>
> **What it breaks / costs.** RoundingMode/ChronoUnit currently *justify*
> `.host_instance` in their own docstrings ("same discipline as the Locale
> singletons"), and `.host_instance` is the canonical home for FQCN-keyed host objects
> with a shared method_table — moving them to `.typed_instance` means each enum needs
> its own per-Runtime descriptor (four descriptors instead of leaning on the shared
> host_instance tag dispatch), and method dispatch (`name`/`ordinal`/`toString`) moves
> from the host_instance descriptor's method_table to typed_instance method tables. It
> also makes the four enums structurally indistinguishable from user `deftype` values
> at the tag level (both `.typed_instance`), so any code that branches "is this a host
> value vs a user record" must go through the descriptor, not the tag — a subtle
> invariant the `.host_instance` tag currently makes free. Net: it is finished-form-clean
> and arguably *cleaner on the GC and print axes*, but it pays with four descriptors and
> a tag that no longer self-identifies "host".
>
> ## Alternative 3 — Wildcard: enum constants as **interned keyword-like scalars**, not heap instances at all
>
> **Shape.** Observe that an enum constant is a pure `(enum_idx, ordinal)` pair with no
> per-instance state — it is closer to a keyword than to a `java.util.Random`. Instead
> of a heap `.host_instance`/`.typed_instance`, give each constant a single canonical
> heap value **interned once per (enum, ordinal)** and handed out by identity, the way
> `type_descriptor.zig:111-119`'s `ref_cache` already interns a descriptor's boxed
> identity. Concretely: keep them as `.host_instance` (F-004: no new tag) but make
> `host_enum.singleton` the *sole* minting point for every path — static-field read,
> getter return, and `name`/`ordinal`/`getValue` all route through one interner so the
> per-(enum,ordinal) value is bit-identical everywhere. The wildcard twist is to drop
> the per-enum *fixed array* caches (`rt.rounding_modes[8]`, `rt.chrono_units[16]`) in
> favour of ONE flat `rt.host_enum_consts` array sized at the comptime sum of all
> registry counts (8+16+7+12 = 43), indexed by `registry[enum_idx].cache_base + ordinal`.
> One cache, one interner, one deinit loop.
>
> **Better than the draft.** Collapses *four* per-Runtime cache slots
> (`rt.rounding_modes`, `rt.chrono_units`, + the two the draft/Alt-1 would add for
> DayOfWeek/Month) into **one** flat array with a comptime base-offset table — the
> registry literally owns the cache layout, so adding a fifth host enum is one registry
> row and the cache auto-resizes at comptime with zero new `rt` fields and zero new
> deinit loop. This is *more* finished-form-clean than the draft on the Runtime-struct
> axis (the draft still implies a per-enum cache or a single cache; making it explicitly
> one flat registry-indexed array is the cleaner end state). It also makes `identical?`
> parity structural rather than per-call-site: there is exactly one interning entry
> point, so no getter can accidentally mint a fresh value (the bug Group B has today at
> `make(rt, …)`).
>
> **What it breaks / costs.** The base-offset indexing (`cache_base + ordinal`) is a
> small piece of comptime cleverness that the per-enum fixed arrays avoid — a future
> enum with a *sparse* or *non-zero-based* ordinal set would need care (none of the four
> have this; JVM enum ordinals are always dense 0-based, so the risk is theoretical). It
> does not, on its own, resolve the `.host_instance` vs `.typed_instance` print/equal/
> compare question — it still has to pick one tag (it picks `.host_instance` like the
> draft), so it inherits the draft's work of migrating DayOfWeek/Month's typed_instance
> `equal`/`compare`/`print` arms to host_instance. So Alt-3 is best read as **a refinement
> layered on top of the draft (or Alt-2)**, not a standalone rival: "whichever tag wins,
> make the cache one flat registry-indexed array with a single interning entry point" —
> that is the genuinely novel, finished-form-improving idea here.
>
> ## No F-NNN forces a violation
>
> All three alternatives and the draft stay inside F-004 (reuse `.host_instance` or
> `.typed_instance`; no new tag), F-009 (impl `host_enum.zig` neutral, surfaces under
> `runtime/java/**` import it, never the reverse — the zone rule holds for every option),
> and F-002 (none is recommended on size grounds). There is **no** clean option that would
> require violating an F-NNN, so there is no leading "would-violate-F-NNN" finding to record.
>
> ## RECOMMENDATION
>
> **Adopt the draft (unify on `.host_instance` via a comptime registry), but fold in
> Alternative 3's single flat registry-indexed cache + single interning entry point.** The
> draft is correctly finished-form-clean and the registry is the right answer to the
> two-representation duplication that `chrono_unit.zig` itself flags as D-510's target;
> Alternative 1 is the Smallest-diff smell (it adds two more static-field arms and two more
> caches to the very surface D-510 exists to collapse) and should be rejected on F-002
> grounds even though it is the smallest diff. Between the two finished-form rivals, the
> draft's choice of `.host_instance` is the better *tag* choice because `.host_instance`
> self-identifies "host value" at the tag level (Alt-2's all-typed_instance world makes host
> enums indistinguishable from user `deftype` records without a descriptor probe) and because
> `.host_instance` is the established home for FQCN-keyed host objects with a shared
> method_table — exactly what `name`/`ordinal`/`toString`/`getValue` dispatch wants.
> Alternative 2's one real edge — that it *extends* the already-green DayOfWeek/Month
> typed_instance `equal`/`compare`/`print` arms instead of re-homing them — is a
> transition-cost argument, not a finished-form argument, so under F-002 it does not outrank
> the draft; but the migration of those arms is the draft's highest-risk step and must land
> with the DayOfWeek/Month corpus cases re-run to lock parity. Alternative 3 is the one idea
> worth absorbing wholesale: make the registry own a single flat cache (`cache_base + ordinal`,
> comptime-sized to 43) with one interning entry point, so `identical?` parity is structural
> (no getter can re-mint) and adding the fifth host enum is a one-row registry edit with zero
> new `rt` fields. Advisory only — the main loop chooses.

The main loop adopted the recommendation **in full**: the draft's `.host_instance`
registry + Alt-3's single flat `rt.host_enum_consts[43]` cache and sole interning
entry point. Alt-1 rejected (Smallest-diff smell, F-002). Alt-2's flagged risk
(migrating DayOfWeek/Month's `equal`/`compare`/`print` arms) is honoured as a hard
gate: the DayOfWeek/Month corpus + e2e cases are re-run to lock parity in the same
cycle the arms move.

## Consequences

- `DayOfWeek/<NAME>` and `Month/<NAME>` now resolve (clj-parity gap closed); their
  getters return the cached singleton, so `(identical? (.getDayOfWeek monday)
  DayOfWeek/MONDAY)` is **true** (was impossible).
- `RoundingMode` / `ChronoUnit` behaviour is preserved (regression-locked by the
  existing corpus); they move onto the shared mechanism with no observable change.
- One print path for all four host enums: the enum `toString` (name, or display name
  for ChronoUnit). Opaque print divergence stays under AD-002 (no new AD).
- Adding a fifth host enum (e.g. `TimeUnit`) is a one-row registry edit + one surface
  file — zero new `rt` fields, zero new `StaticFieldValue` arms, zero new cache.
- The two-representation split + four scattered name/ordinal/value definitions
  collapse into one `host_enum.zig` table. `MathContext` stays a consumer (typed
  RoundingMode arg), not a member.
- Staged across two TDD cycles: cycle 1 builds the mechanism + migrates Group A
  (behaviour-preserving); cycle 2 folds Group B (the parity wins + the arm migration).

## Affected files

- `src/runtime/host_enum.zig` (new — neutral: registry + flat cache + singleton/name/
  toString/value/deinit; folds rounding_mode.zig + chrono_unit.zig + day_of_week_value.zig
  + month_value.zig)
- `src/runtime/rounding_mode.zig`, `src/runtime/chrono_unit.zig`,
  `src/runtime/time/day_of_week_value.zig`, `src/runtime/time/month_value.zig` (deleted — folded)
- `src/runtime/type_descriptor.zig` (`StaticFieldValue.host_enum` arm replaces
  `.rounding_mode`/`.chrono_unit`; `host_enum_idx` field; TemporalPrint loses
  `.day_of_week`/`.month`)
- `src/eval/analyzer/analyzer.zig` (`staticFieldValue` resolves `.host_enum`)
- `src/runtime/runtime.zig` (`host_enum_consts[43]` replaces `rounding_modes`/
  `chrono_units`/`day_of_week_descriptor`/`month_descriptor`; deinit)
- `src/runtime/print.zig`, `src/runtime/equal.zig`, `src/runtime/compare.zig`
  (host-enum arms keyed by `host_enum_idx`; remove the Group-B typed_instance arms)
- `src/runtime/java/math/RoundingMode.zig`, `src/runtime/java/time/ChronoUnit.zig`
  (regenerate static_fields via the registry; set `host_enum_idx`)
- `src/runtime/java/time/DayOfWeek.zig`, `Month.zig` (new — surface with static_fields
  + getValue), registered in `runtime/java/_host_api.zig`
- `src/runtime/time/local_date_value.zig`, `local_date_time_value.zig` (getters return
  the cached singleton)
- `src/main.zig` (test aggregator imports), `compat_tiers.yaml`
- `test/e2e/phase14_*.sh` + `test/diff/clj_corpus/` (DayOfWeek/Month static-field +
  identical? cases; RoundingMode/ChronoUnit regression cases)
- `.dev/debt.yaml` (D-510 discharged)
