# `src/runtime/error/`

Consolidated error-handling subsystem. ADR-0018 (error catalog SSOT)
+ ADR-0029 § Consequences > Neutral / follow-ups (consolidation as
the first cw-v1 case study).

| File          | Role                                                                                         |
|---------------|----------------------------------------------------------------------------------------------|
| `info.zig`    | threadlocal `Info` + `setErrorFmt` (was `runtime/error.zig`)                                 |
| `catalog.zig` | `Code` enum + `entry()` table + `raise()` + `checkArity()` (was `runtime/error_catalog.zig`) |
| `print.zig`   | `formatErrorWithContext` (file:line:col + caret + message) (was `runtime/error_print.zig`)   |

Imports from outside `runtime/error/` use call-site-relative paths.
Examples from real call sites in this repo:

```zig
// from src/main.zig:
const error_mod = @import("runtime/error/info.zig");
const error_print = @import("runtime/error/print.zig");

// from src/eval/<X>.zig:
const error_mod = @import("../runtime/error/info.zig");
const error_catalog = @import("../runtime/error/catalog.zig");

// from src/lang/primitive/<X>.zig:
const error_mod = @import("../../runtime/error/info.zig");
const error_catalog = @import("../../runtime/error/catalog.zig");
```

Imports inside `runtime/error/` use same-directory bare paths
(e.g., `@import("info.zig")`).

The consolidation does not change the catalog SSOT contract: user-
facing messages flow exclusively through `catalog.raise(.code, loc,
args)`. See `.claude/rules/error_catalog_only.md`.
