---
paths:
  - src/runtime/**
  - src/lang/primitive/**
  - compat_tiers.yaml
---

# Feature-name consistency + Java/cljw surface layout

> Codifies ADR-0029 D1-D6 (directory layout, dependency direction,
> keyword discipline, Backend marker docstring, compat_tiers schema)
> + F-009 (feature-implementation neutrality). Supersedes the prior
> standalone `host_extension_layout.md` and `java_cljw_surface_layout.md`
> rules (the latter folded into this file at Wave 16, W16-5,
> 2026-05-26 per D-050(a)).

## Background

F-009 mandates that a feature's implementation, surface wrappers
(Java + cljw + Clojure-ns), and value-wrap utilities live in
**different files** for namespace-neutral implementation sharing.
A single feature like `java.util.UUID` therefore involves at
minimum 3 files (impl / surface / Clojure peer) — often 4-5 when
sub-impls and value-wrap helpers join.

This is structurally unavoidable. The mitigation is **discoverability
by feature keyword**: every related file has the keyword in its
path so `rg <keyword> src/` returns 100% of the relevant files.

## Rule

### R1. Each feature owns one keyword

A keyword is a short lower-snake-case identifier (e.g., `uuid`,
`file_io`, `clock`, `regex`, `digest`) declared once in
`compat_tiers.yaml`:

```yaml
- fqn: java.util.UUID
  keyword: uuid
  files:
    surface: runtime/java/util/UUID.zig
    impl: runtime/uuid.zig
    impl_extras: [runtime/crypto/secure_random.zig]
    wrap: runtime/collection/string.zig
    clojure_peer: lang/primitive/uuid.zig
```

The keyword **must** appear as a path component or filename stem
in every file path listed under `files:`. Exceptions:

- `wrap:` (value-wrap helpers like `collection/string.zig`) may
  legitimately not contain the keyword — they are reused across
  features. This slot is exempt from G3.
- `surface:` (Java-surface paths under `runtime/java/<pkg>/<Class>.zig`)
  uses the Java class name (PascalCase) which rarely matches the
  lower_snake_case impl keyword. Grep by Java class name is the
  canonical way to find a surface; G3 enforces the keyword link
  only on impl / impl_extras / clojure_peer slots.

### R2. Backend marker docstring on every surface file

Every `runtime/java/**/*.zig` and `runtime/cljw/**/*.zig` file
must open with:

```zig
// SPDX-License-Identifier: EPL-2.0
//! <one-line summary>
//!
//! Backend: <impl-only | collection-only | impl+collection | surface-only>
//! Impl deps: <comma-separated keywords or "none">
//! Clojure peer: <ns/var or "none">
```

- `Backend:` documents what category of impl this surface calls.
- `Impl deps:` lists feature keywords (matching
  `compat_tiers.yaml`) that this surface depends on.
- `Clojure peer:` names the Clojure-ns Var(s) that share the
  same neutral impl, or `none`.

Exceptions:

- `_host_api.zig` and `_README.md` are markers / docs, not
  surfaces; exempt from R2.

## Why

- **Grep 100%.** `rg uuid src/` returns every UUID-related file
  in one shot — impl, surface, Clojure peer.
- **Reading 5 lines tells the reader the wiring.** Backend
  marker says where the impl lives, what other features it
  depends on, and which Clojure Var shares the same impl.
- **F-009 stays enforceable.** Without the keyword consistency
  + marker discipline, fan-out becomes "where is the UUID code?"
  navigation pain, and the loop drifts toward inlining impl into
  the surface to make navigation easier (= smallest-diff bias).
- **Index integrity.** `compat_tiers.yaml` `files:` is the
  authoritative cross-reference; G3 ensures it stays honest.

## How to apply (when adding a new feature)

1. Pick a short, distinctive keyword (e.g., `digest` for
   `java.security.MessageDigest`).
2. Verify no existing entry already claims that keyword
   (`rg "keyword: <kw>" compat_tiers.yaml`).
3. Write the neutral impl file with the keyword in its path
   (`runtime/crypto/message_digest.zig` — keyword `digest`
   appears as `message_digest`).
4. Write the surface file under `runtime/java/security/MessageDigest.zig`
   (keyword `digest` appears in `MessageDigest`).
5. Add the surface file's Backend marker docstring.
6. If there is a Clojure peer, add `lang/primitive/digest.zig`
   (keyword `digest` in filename).
7. Add the `compat_tiers.yaml` entry with `keyword: digest` +
   `files:` map listing all the above paths.
8. Run `bash test/run_all.sh`. G2 (`check_surface_marker.sh`)
   and G3 (`check_feature_keyword.sh`) must pass.

### R3. Java + cljw surface directory layout (ADR-0029 D1)

Surface files live under two parallel trees:

```
src/runtime/java/                          (Java-compat surface)
├── _host_api.zig    ___HOST_EXTENSION marker aggregator
├── lang/            Object/String/Long/Integer/Double/Boolean/
│                    Character/Math/System/Throwable/Exception/
│                    RuntimeException/Thread
├── io/              File/PrintWriter/InputStream/OutputStream/
│                    Reader/Writer/ByteArrayInputStream/ByteArrayOutputStream
├── util/            UUID/Date/Random/Locale/regex/{Pattern,Matcher}/
│                    concurrent/{Future, atomic/AtomicLong}
├── time/            Instant/LocalDate/LocalDateTime/Duration/
│                    ZonedDateTime/ZoneId
├── net/             URL/URI                            (Phase 14+)
├── nio/             file/{Path,Files}/charset/Charset
├── math/            BigInteger/BigDecimal
├── security/        MessageDigest/SecureRandom         (Phase 14+)
└── reflect/         Method/Field via TypeDescriptor    (Phase 7+ Tier C)

src/runtime/cljw/                          (cljw-original surface)
├── _host_api.zig    optional aggregator
├── build/           Compiler                            (Phase 12)
├── wasm/            Engine/Module/Instance/Component    (Phase 16+)
├── edge/            Server/Request                      (Phase 14+)
├── pod/             Pod (bb-style pod 互換)              (Phase 16+)
└── repl/            NReplServer                         (Phase 10+)
```

User code reaches Java entries as `(:require [cljw.java.util :refer
[UUID]])` — `cljw.host.*` is retired per ADR-0029. cljw-original
surfaces ship Zig extensions (Wasm component invoke / edge runtime /
build command / pod invocation); anything that is a Clojure library
belongs in `lang/clj/` (in-source) or `modules/` (peer to src/,
Phase 9+).

### R4. Dependency direction (ADR-0029 D2, gate G1)

> No file under `runtime/` other than those in `runtime/java/**`
> and `runtime/cljw/**` may import from `runtime/java/**` or
> `runtime/cljw/**`.

Surface layers (`java/`, `cljw/`) call the **neutral impl layer**
(everything else in `runtime/`). The reverse is forbidden. Cross-
surface horizontal calls are also forbidden:

- `runtime/java/<X>.zig` must not import `runtime/cljw/<Y>.zig`
- `runtime/cljw/<X>.zig` must not import `runtime/java/<Y>.zig`
- `lang/primitive/<X>.zig` must not import `runtime/java/` or
  `runtime/cljw/`

All three surface families (Java, cljw, Clojure-ns) share the
**same neutral impl**. `scripts/zone_check.sh` (extended per
ADR-0029 D4) gates these constraints in CI.

## Counter-examples

- **Bad keyword choice**: `keyword: m` (too generic). Pick a
  4-12 char distinctive word.
- **Forgetting the marker docstring** on a new
  `runtime/java/<X>.zig`: G2 blocks.
- **Listing a file in `files:` that lacks the keyword**: G3 blocks
  (use the `wrap:` slot for legitimately-reusable helpers).
- **Body inline in surface file**: forbidden per F-009; surface is
  a thin wrapper over the neutral impl in `runtime/<feature>.zig`.
- **Cross-surface import** (`runtime/java/` → `runtime/cljw/` or
  vice versa): forbidden per R4; both reach the shared impl.
- **`cljw.host.*` ns prefix**: retired by ADR-0029; use
  `cljw.java.*` for Java compat ns and `cljw.*` for cljw-original.

## Related

- ADR-0029 D1-D6 (directory layout, dependency direction, G1/G2/G3
  guardrails, compat_tiers schema).
- F-009 — feature-implementation neutrality (the invariant this
  rule operationalises).
- ADR-0011 — superseded by ADR-0029 (the `___HOST_EXTENSION` marker
  pattern carries forward).
- `scripts/zone_check.sh` (G1).
- `scripts/check_surface_marker.sh` (G2).
- `scripts/check_feature_keyword.sh` (G3).
- `compat_tiers.yaml` — extended schema per ADR-0029 D5.
