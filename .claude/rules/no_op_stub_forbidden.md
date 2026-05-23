---
paths:
  - src/**/*.zig
  - src/lang/clj/**
  - src/runtime/host/**
---

# Permanent no-op forbidden — transient stubs OK

## Rule

The cw v1 codebase commits to the principle:

> **No Tier A / B / C feature may ship in a form where the user sees
> success while the runtime silently drops the intended semantics.**

The verb is "ship": the rule is about what lands in the **final shape**
of the feature. It is not about the development trajectory. Two things
that look superficially similar but are governed by opposite rules:

| Shape                                                     | Rule   | Why                                                                     |
|-----------------------------------------------------------|--------|-------------------------------------------------------------------------|
| Skeleton struct that Phase N+ rewrites into a real impl   | **OK** | Reservation lowers later surface ripple. ADR-0004 day-1 enum principle. |
| Function body that raises `feature_not_supported`         | **OK** | Explicit user signal. Transient — disappears when the real impl lands. |
| Function body that returns the input unchanged            | **NG** | Pretends to work, drops semantics silently. The user builds on a lie.   |
| Macro that expands to `nil` or to its body without effect | **NG** | Same shape — user code compiles and runs, semantics are gone.          |

**Skeleton-then-rewrite is fully endorsed.** Day-1 reservation (per
ADR-0004 / ADR-0012 / ADR-0023) explicitly expects a Phase-N skeleton
to be replaced by Phase-N+ real implementation. The writer's job at
skeleton time is judgement quality at *that* moment — picking the
struct shape so that the eventual rewrite is the smallest possible
change. Whether the file is rewritten later is not itself a smell.

## What "permanent no-op" looks like

- `pub fn dosync(rt, body) !Value { return eval(rt, body); }` —
  evaluates body without snapshot isolation. The shape claims to
  implement `dosync`; the runtime ships without STM. Forbidden.
- `pub fn locking(rt, lock, body) !Value { return eval(rt, body); }` —
  same. Forbidden.
- `(defn foo [x] x)` macro that should compute but echoes. Forbidden.

## What "transient stub" looks like

These are all fine — and expected during development:

```zig
// Skeleton: only the struct declared, no operations yet.
pub const BigInt = struct {
    header: HeapHeader,
    m: std.math.big.int.Managed,
};

// Skeleton: function declared with explicit unsupported_feature raise.
// Phase 15 replaces the body with the real MVCC implementation.
pub fn dosync(rt: *Runtime, loc: SourceLocation, body: Value) !Value {
    _ = rt;
    _ = body;
    return error_catalog.raise(.unsupported_feature, loc, .{ .name = "dosync" });
}

// Skeleton: dev-only internal path raises error.NotImplemented with
// a comment naming the future task that fills it in.
.op_invoke_builtin => {
    // Phase 7 wires analyzer-pre-resolved direct builtin calls.
    return error_catalog.raise(.unsupported_feature, .{}, .{ .name = "op_invoke_builtin" });
},
```

The user-facing renderings are
`"<feature> is not supported in ClojureWasm"` and
`"<form> is not part of ClojureWasm"`. Development concepts (Phase
numbers, ADR identifiers, internal file paths) stay internal.

## Skeleton vs permanent no-op (boundary)

A "skeleton" is permitted when **any** of:

- Only the struct type definition exists (no function declared yet).
- A function is declared but its body is exactly
  `return error_catalog.raise(.unsupported_feature, loc, .{ .name = "<form>" });`
  (per ADR-0018), or for genuinely internal-only paths
  `return error.NotImplemented;` / `@panic("...")` with a developer-
  visible comment naming the task that will fill it in.

A "permanent no-op" is forbidden when:

- A function is declared and executes the argument without the intended
  semantics (e.g., `dosync` body executed without snapshot isolation).
- A function returns a default value that masks the missing feature.

The boundary is **what the user observes**. Skeletons that raise are
honest about not working; permanent no-ops are dishonest.

## Why (Shota's directive)

- A stub that "works" misleads users into building code that breaks
  later.
- STM (`dosync` body executed without snapshot isolation) and locking
  (`locking` body executed without lock) are common offenders in
  JVM-non-equivalent runtimes.
- cw v1 commits to either a real implementation or an explicit error.
- Skeleton-then-rewrite **is** how the codebase grows; the only thing
  forbidden is shipping a lie.

## How to apply

- New feature: implement the real semantics, or fail clearly.
- Day-1 reserved skeleton: pick the struct shape with judgement at
  that moment; rewrite at the activation phase is expected and not a
  smell.
- Pre-commit gate: `scripts/check_no_op_stub.sh` (heuristic, becomes
  hard at Phase 5+). The heuristic targets the "executes body without
  intended semantics" shape, not the "raises unsupported_feature"
  shape.
- ADR for any deliberate exception (Phase 4 entry has none).

## Examples

Don't: `pub fn dosync(rt: *Runtime, body: Value) !Value { return eval(rt, body); }`

Do at Phase 4:

```zig
pub fn dosync(rt: *Runtime, loc: SourceLocation, body: Value) !Value {
    _ = rt;
    _ = body;
    return error_catalog.raise(.unsupported_feature, loc, .{ .name = "dosync" });
}
```

Renders to the user as: `dosync is not supported in ClojureWasm`.

Do at Phase 15: real MVCC implementation per ADR-0010.

## Revision history

- 2026-05-23: Rename "No-op stub forbidden" →
  "Permanent no-op forbidden — transient stubs OK". The original
  wording suggested all stubs are forbidden, which collides with the
  day-1 reservation principle (ADR-0004 / ADR-0012 / ADR-0023). Made
  the time-axis explicit ("final shape" vs "development trajectory")
  and endorsed skeleton-then-rewrite per the writer's judgement.
