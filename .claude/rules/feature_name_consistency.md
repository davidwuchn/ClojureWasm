---
paths:
  - src/runtime/**
  - src/lang/primitive/**
  - compat_tiers.yaml
---

# Feature-name consistency (keyword + Backend marker)

> Codifies ADR-0029 D4 (guardrails G2/G3) and the discoverability
> mechanism that compensates for the unavoidable file fan-out
> declared by F-009.

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

## Counter-examples

- **Bad keyword choice**: `keyword: m` (too generic, grep hits
  thousands of unrelated lines). Pick a 4-12 char distinctive
  word.
- **Forgetting the marker docstring** on a new
  `runtime/java/<X>.zig`: G2 will block the commit.
- **Listing a file in `files:` that lacks the keyword in its
  path**: G3 will block. If the file is legitimately reusable
  across features (like `collection/string.zig`), put it under
  the `wrap:` slot (which is exempt from G3).

## Related

- ADR-0029 D4 (G1/G2/G3 guardrails) + D5 (`compat_tiers.yaml`
  schema).
- F-009 — feature-implementation neutrality (the invariant this
  rule operationalises).
- `.claude/rules/java_cljw_surface_layout.md` — surface
  directory layout + Backend marker reference.
- `scripts/check_surface_marker.sh` (G2 implementation).
- `scripts/check_feature_keyword.sh` (G3 implementation).
