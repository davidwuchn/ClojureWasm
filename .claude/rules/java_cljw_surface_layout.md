---
paths:
  - src/runtime/java/**
  - src/runtime/cljw/**
---

# Java + cljw surface directory layout

> Codifies ADR-0029 (D1 directory layout, D2 dependency direction)
> and F-009 (feature-implementation neutrality). Supersedes the prior
> `host_extension_layout.md` rule.

## Rule

cw v1 has two surface families, both living **under `src/runtime/`**:

### Java-compat surface

```
src/runtime/java/<pkg>/<Class>.zig

src/runtime/java/
├── _host_api.zig    ___HOST_EXTENSION marker aggregator
├── lang/            Object, String, Long, Integer, Double, Boolean,
│                    Character, Math, System, Throwable, Exception,
│                    RuntimeException, Thread
├── io/              File, PrintWriter, InputStream, OutputStream,
│                    Reader, Writer, ByteArrayInputStream,
│                    ByteArrayOutputStream
├── util/            UUID, Date, Random, Locale,
│                    regex/{Pattern, Matcher},
│                    concurrent/{Future, atomic/AtomicLong}
├── time/            Instant, LocalDate, LocalDateTime, Duration,
│                    ZonedDateTime, ZoneId
├── net/             URL, URI                                  (Phase 14+)
├── nio/             file/{Path, Files}, charset/Charset
├── math/            BigInteger, BigDecimal
├── security/        MessageDigest, SecureRandom               (Phase 14+)
└── reflect/         Method, Field (thin, via TypeDescriptor)  (Phase 7+ Tier C)
```

Each `<Class>.zig` is a **thin wrapper** — it calls the neutral
implementation layer under `src/runtime/` (flat or sub-directory)
and registers itself via `___HOST_EXTENSION` marker.

User code reaches each entry as `(:require [cljw.java.util :refer
[UUID]])` (the `cljw.host.*` prefix is retired by ADR-0029).

### cljw-original surface

```
src/runtime/cljw/<area>/<Item>.zig

src/runtime/cljw/
├── _host_api.zig    optional aggregator (mirrors java/_host_api.zig)
├── build/           Compiler                                     (Phase 12)
├── wasm/            Engine, Module, Instance, Component          (Phase 16+)
├── edge/            Server, Request                              (Phase 14+)
├── pod/             Pod (bb-style pod 互換)                       (Phase 16+)
└── repl/            NReplServer                                  (Phase 10+)
```

Symmetric thin-wrapper structure. cw-original value-add features
(Wasm component invoke, edge runtime, build command, pod invocation)
that are **Zig extensions, not Clojure libraries**. Anything that
ships as a Clojure library belongs in `lang/clj/` (in-source) or
`modules/` (peer to src/, Phase 9+).

## Dependency direction (ADR-0029 D2)

> No file under `runtime/` other than those in `runtime/java/**` and
> `runtime/cljw/**` may import from `runtime/java/**` or
> `runtime/cljw/**`.

Surface layers (`java/`, `cljw/`) call the **neutral impl layer**
(everything else in `runtime/`). The reverse is forbidden.

Cross-surface horizontal calls are also forbidden:

- `runtime/java/<X>.zig` must not import `runtime/cljw/<Y>.zig`
- `runtime/cljw/<X>.zig` must not import `runtime/java/<Y>.zig`
- `lang/primitive/<X>.zig` must not import `runtime/java/` or
  `runtime/cljw/`

All three surface families share the **same neutral impl**.

`scripts/zone_check.sh` (extended per ADR-0029 D4) gates these
constraints in CI.

## Backend marker docstring (ADR-0029 D4, gate G2)

Every `runtime/java/**/*.zig` and `runtime/cljw/**/*.zig` file
opens with a three-line marker header after the module docstring:

```zig
// SPDX-License-Identifier: EPL-2.0
//! <one-line summary of the Java/cljw surface this file exposes>
//!
//! Backend: <impl-only | collection-only | impl+collection | surface-only>
//! Impl deps: <comma-separated feature keywords>
//! Clojure peer: <ns/var or "none">
```

- **`Backend:`** — what category of implementation this surface calls:
  - `impl-only` — calls only `runtime/<feature>.zig` (neutral impl)
  - `collection-only` — calls only `runtime/collection/` or
    `runtime/numeric/` (re-wraps existing cw values)
  - `impl+collection` — uses both
  - `surface-only` — no body yet (Tier C reflective fallback waiting,
    or `_host_api.zig`-style marker file)
- **`Impl deps:`** — feature keywords this file uses, comma-separated
  (e.g., `uuid, secure_random`). Cross-referenced against
  `compat_tiers.yaml` `keyword:` + `impl_extras:`.
- **`Clojure peer:`** — the Clojure-ns Var(s) that share the same
  neutral impl (e.g., `clojure.core/random-uuid`), or `none`.

`scripts/check_surface_marker.sh` (ADR-0029 D4 / G2) enforces this.

## Why

- **Predictability.** Looking at `compat_tiers.yaml` + the `java/`
  tree tells the reader exactly what Java surface cw v1 provides.
- **Implementation sharing.** Both `(random-uuid)` (Clojure peer)
  and `(java.util.UUID/randomUUID)` (Java surface) reach the same
  16-byte random generator in `runtime/uuid.zig`. F-009 codifies
  this neutrality.
- **Symmetry between Java and cljw-original surfaces.** Same
  marker / structure / dependency rules so the loop can reason
  about both with one mental model.
- **Documentation as code.** The directory itself records the
  compatibility surface; no separate registry.

## How to apply (adding a new surface)

1. Identify (or create) the **neutral impl** file under `runtime/`
   (e.g., `runtime/uuid.zig`). If multiple files are needed, use a
   sub-directory (`runtime/regex/{compile, match}.zig`).
2. Add the surface file under `runtime/java/<pkg>/<Class>.zig`
   (Java) or `runtime/cljw/<area>/<Item>.zig` (cljw-original).
3. Open the surface file with the **Backend marker docstring**
   (see above).
4. Export the `___HOST_EXTENSION` declaration so
   `_host_api.zig` picks it up.
5. Update `compat_tiers.yaml` with the new entry's `keyword:` +
   `files:` map (per ADR-0029 D5 schema).
6. If there is a Clojure peer (e.g., `clojure.core/random-uuid`),
   add the primitive under `lang/primitive/<feature>.zig` and
   register it in `lang/primitive.zig::registerAll`.
7. Run the gate: `bash test/run_all.sh`. G1 (zone_check), G2
   (surface_marker), G3 (feature_keyword) must all pass.

## Counter-examples

- **Do NOT** write the implementation body inside the surface file.
  Surface is a thin wrapper; impl lives in `runtime/<feature>.zig`.
  (This was the cw v0 pattern; F-009 forbids it.)
- **Do NOT** call `runtime/java/` from `runtime/cljw/` or vice
  versa. Both reach the shared neutral impl.
- **Do NOT** use the `cljw.host.*` namespace prefix; it was
  retired by ADR-0029. Use `cljw.java.*` for Java compat ns and
  `cljw.*` for cljw-original ns.

## Related

- ADR-0029 (D1-D6) — structural decision.
- F-009 — feature-implementation neutrality invariant.
- ADR-0011 — superseded by ADR-0029 (the `___HOST_EXTENSION`
  marker pattern carries forward).
- `.claude/rules/feature_name_consistency.md` — keyword consistency
  + Backend marker contract details.
- `compat_tiers.yaml` — extended schema per ADR-0029 D5.
