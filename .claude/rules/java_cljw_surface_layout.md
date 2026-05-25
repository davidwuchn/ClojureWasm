---
paths:
  - src/runtime/java/**
  - src/runtime/cljw/**
---

# Java + cljw surface directory layout

> Folded into [`feature_name_consistency.md`](feature_name_consistency.md)
> at Wave 16, W16-5 (2026-05-26), per D-050 (a). This file remains as
> a path-frontmatter pointer so editors of `runtime/java/**` /
> `runtime/cljw/**` keep auto-loading the layout context.

## See

For directory tree + Backend marker docstring contract + dependency
direction + the "how to add a new surface" recipe:

[`feature_name_consistency.md`](feature_name_consistency.md) §R3
(directory shape), §R4 (dependency direction), §R2 (Backend marker),
"How to apply" + "Counter-examples".

The keyword discipline (§R1) + Why section + ADR cross-references
also live there.

## ADR cross-references

- **ADR-0029** D1-D6 — directory layout, dependency direction,
  G1/G2/G3 guardrails, compat_tiers schema.
- **F-009** — feature-implementation neutrality invariant.
- **ADR-0011** — superseded by ADR-0029 (the `___HOST_EXTENSION`
  marker pattern carries forward).
