# 0035 — `(ns ...)` analyzer special form + `require` runtime fn + alias storage + cross-ns `^:private` × `:refer` filter + circular-require detection + bootstrap loader topo-sort + per-file `SourceContext` registry + swappable resolver slot

**Status**: Accepted (Devil's-advocate fork landed 2026-05-26)
**Date**: 2026-05-26
**Author**: Shota Kudo (drafted with Claude autonomous loop)
**Tags**: phase-6-late, namespace, require, bootstrap, multi-file,
F-001, F-002, F-009

## Context

cw v1 が Phase 6.16.b-3 で landed させた multi-file `.clj`
bootstrap (`core.clj` + `set.clj` + `string.clj` + `walk.clj`) は
provisional behaviour を 3 cluster (11 marker sites + 3
`feature_deps.yaml` entries) 抱える: (i) `evalInNs` / `op_in_ns`
が `rt` と `clojure.core` を auto-refer する (ADR-0032 era 妥協)、
(ii) `bootstrap.zig` 末尾と `primitive.zig::registerAll` と
`macro_transforms.zig::registerInto` の 3 ヶ所が hardcoded
`referAll` を fire する (= 妥当な fan-out 設計が確定するまでの placeholder)、
(iii) 4 `.clj` 先頭が `(in-ns 'foo)` 裸書き (= `(ns ...)` macro
未着地)。 全 3 cluster は ADR-0035 (= D-063 起票) が `(ns ...)`
macro + `require` semantics + bootstrap loader 仕様確定で discharge
することが予定されていた。

加えて D-058 (bootstrap loader per-file `SourceContext`)
が同じ "loader が `.clj` file identity を意識する" 設計面に属するため、
ADR-0035 で同時解消するよう v5 §19.3 D6 で予定されていた。

cw v1 の finished form は JVM Clojure の `(ns foo
(:refer-clojure :exclude [...]) (:require [x :as y :refer [z]]))`
macro 形を提供する必要があるが、 cw v1 distribution model
(F-001 = zwasm v2 統合不可避、 = embedded + AOT-style) は JVM
classpath-based file resolution と整合しない。 v5 §19.3 D3
(`cljw_path` env var) と D5 (lazy vs eager load) は Phase 12+
留保。 本 ADR は Phase 6.16.b-4 で着地する scope に限定し、
Phase 12+ の swap-in 余地を残す形で `Runtime.requireResolver`
slot を導入する。

詳細な v5 plan は
`private/notes/clj_vs_zig_split_proposal_v5.md` §19.3 + §21.1 SSOT、
本 cycle survey は `private/notes/phase6-6.16.b-4-survey.md` SSOT。

## Decision

### D1: `(ns foo ...)` は analyzer special form (= macro でない)

`src/eval/analyzer/special_forms.zig` に `analyzeNs` を追加。
`(ns foo & references)` を IR 上で explicit op-sequence に
展開する: `in-ns 'foo` → (`:refer-clojure` 指定 unless explicit
override) `refer 'clojure.core` (with `:exclude` / `:only` filter) →
各 `(:require [x :as y :refer [...]])` 引数を `require` fn 呼出
sequence 化。

実装は単一 `NsNode { name: []const u8, refer_clojure: ?ReferClojureSpec, requires: []RequireSpec }` を analyzer pass で
合成し、 backend (tree_walk + VM) が順次 in-ns → refer → require
を実行する。 `(:use ...)` は本 cycle で `feature_not_supported`
raise、 `(:import ...)` は no-op (cw v1 は Java Class import を
Var-ref qualified name 経由でカバー)、 `(:gen-class ...)` は
silent-ignore (JVM compile-only feature)。

**選定理由 (Devil's advocate Alt 2)**: analyzer special form
は (a) `(ns)` `(ns foo :bad-kw)` `(ns foo (:require))` 等の
malformed input に対し precise location-tagged error を analyze
時に出せる、 (b) user `(def ns ...)` で shadowing できない、
(c) ADR-0032 の `in-ns` special form precedent
(`analyzer.zig:368-382`) と pattern 整合的。 macro path は
smallest-diff bias smell (F-002)。

### D2: `clojure.core/require` は runtime fn (varargs)

`src/lang/primitive/require.zig` に `clojure.core/require`
builtin fn を実装。 varargs 受理: `(require 'sym ...)` または
`(require '[sym & opts] ...)`。 opts 認識: `:as <alias>`、
`:as-alias <alias>` (load なし alias 化)、 `:refer [a b c]`、
`:refer :all`、 `:reload`、 `:reload-all`、 `:verbose` (no-op
本 cycle)。

per-libspec 処理: (a) resolver で source 取得、 (b) 未 load
なら load + intern (`:reload` 強制再 load)、 (c) `:as` /
`:as-alias` で alias 設定、 (d) `:refer` で refer 設定
(D4 の private filter 適用)。

### D3: alias storage = env-table (Namespace.aliases)

`Namespace.aliases: StringHashMapUnmanaged(*Namespace)` は
既存 (`src/runtime/env.zig:116, 128`)。 `Namespace.setAlias(env,
alias_name, target_ns)` public API を追加 (key を `env.alloc`
で duplicate、 既存 entry あれば silent overwrite)。

analyzer の `analyzeSymbol` で qualified `s/foo` を解析する
際: `env.current_ns.aliases.get("s")` を最初に試行、 hit したら
そこの ns で `foo` を resolve。 miss なら従来通り `env.findNs("s")`。
REPL-time `(alias 's 'clojure.string)` で動的変更可能。

### D4: `:refer` × `^:private` = silent skip (implicit) + hard error (explicit)

`env.referAll(from, to)` は private (= `Var.flags.private`) を
**silent skip** (JVM 互換、 `:refer :all` 経路)。 一方
`env.referOne(from, to, name)` で explicit に名前指定された Var
が `^:private` の場合は `private_access_error` を raise
(= JVM より厳しい、 cw v1 は require call 時点で fail-fast に
する: ADR-0035 cycle の Bad Smell sensor "don't ship a lie" 適用)。

### D5: 循環 require 検出 = error (新 catalog Code `circular_require`)

`Runtime.require_in_progress: std.StringHashMapUnmanaged(void)` 追加。
`requireOne(env, ns_name)` は (a) `require_in_progress` に
`ns_name` がいたら `circular_require` を raise (message
template: `"Cyclic load dependency: {[chain]s}"`、 `chain` は
現在の require call stack を newline-join で render)、 (b)
そうでなければ set に add、 load 実行、 (c) errdefer で
return 時 remove。

`circular_require` Code を `src/runtime/error/catalog.zig` に
追加 (kind = `name_error`, phase = `analysis`)。

### D6: bootstrap topology = hybrid (boot list + 同じ require path)

`bootstrap.loadCore` は `BOOT_NAMESPACES: []const []const u8 =
&.{ "clojure.core", "clojure.set", "clojure.string", "clojure.walk" }`
の固定 list を持つ (= 順序 explicit、 hidden dependency walking
なし)。 各 entry を `requireOne(env, ns_name)` 経由で load —
bootstrap と user code が同じ load path を共有する。 既存
hardcoded `FILES` table は削除、 source 取得は D8 resolver 経由。

これにより (a) bootstrap fan-out の `referAll` 3 ヶ所は不要
(`(ns ...)` macro 展開が `:refer-clojure` を発火するため)、
(b) circular detection は bootstrap 内 require にも自動適用、
(c) `evalInNs` の rt + clojure.core auto-refer も削除可能 (=
ns macro 展開が refer を担う)。

### D7: per-file `SourceContext` = Runtime registry (D-058 closure)

`Runtime.source_registry: std.StringHashMapUnmanaged(SourceContext)`
追加 (key = file label like `<clojure.core>`、 value = SourceContext
struct)。 `requireOne` が source load 時に entry を populate、
`bootstrap.loadCore` が boot ns 列を iterate する際にも populate
する。

`src/runtime/error/print.zig` の renderer は
`info.location.file` を registry で lookup し、 hit したらその
`SourceContext.text` を source-line preview に使用、 miss なら
fallback として `bootstrap_ctx` を使用 (= synthetic location
safe default)。 D-058 closure。

### D8: resolver = single swappable fn slot (`Runtime.requireResolver`)

`Runtime.requireResolver: *const fn(*Runtime, ns_name:
[]const u8) anyerror!?SourceText` (SourceText = `?[]const u8`、
`null` = lib_not_found)。 boot 時に `embeddedResolver` を default
として install — 4 ns (`clojure.core` / `clojure.set` /
`clojure.string` / `clojure.walk`) 名 → `@embedFile` で取得した
source text を返す。 Phase 12+ で `cljw_path` / build artifact /
Wasm pod 用 resolver に swap される (= slot 1 個、 chain 抽象
なし)。

`lib_not_found` Code を `src/runtime/error/catalog.zig` に追加
(kind = `name_error`, template: `"Could not locate {[ns]s}.clj on
the require resolver"`)。

**選定理由 (Devil's advocate Alt 2)**: Phase 12+ classpath +
Phase 16+ Wasm pod の存在は F-001 で確定だが、 「2 つ以上の
resolver を同時に持つ chain」 は今この cycle に存在せず、
chain 抽象を先取りするのは Reservation-as-bias smell (F-002)。
slot swappable で F-001 future-proof を確保し、 chain は
2 ndaresolver が現れる cycle に判断を譲る。

### D9: 同 sub-cycle d で discharge する provisional cluster

`feature_deps.yaml` 更新:

- `runtime/eval/in_ns_auto_refer`: `provisional → landed`、
  4 PROVISIONAL marker lines 削除 (tree_walk.zig × 2 + vm.zig × 2)。
  `evalInNs` / `op_in_ns` を pure ns-switch (auto-refer なし) に
  簡略化。
- `runtime/bootstrap/refer_table`: `provisional → landed`、
  3 PROVISIONAL marker lines 削除 (bootstrap.zig + primitive.zig
  + macro_transforms.zig)。 該当 `referAll` 呼出を `(ns ...)`
  macro 展開が代替するため削除。
- `runtime/eval/bare_in_ns_decl`: `provisional → landed`、
  4 `.clj` heads を `(in-ns 'foo)` → `(ns foo (:refer-clojure))`
  に書換、 4 PROVISIONAL marker lines 削除。
- `special_form/ns_macro`: `planned → landed`。

`.dev/debt.md`:
- D-058 → Discharged (sub-cycle c で per-file SourceContext registry
  着地)。
- D-063 → Discharged (ADR-0035 全体着地)。

11 marker sites + 3 yaml entries (status flip) + 2 debt rows
(close) = atomic commit in sub-cycle d (`check_provisional_sync.sh`
hook が三者同期 enforce)。

## Alternatives considered

Devil's-advocate fork (depth-3、 mandatory)、 fresh-context
`general-purpose` subagent、 F-001 / F-002 / F-007 / F-009 envelope
内で 3 alternatives 取得。 output verbatim:

> ## Devil's-advocate review of ADR-0035
>
> ### Alt 1 — smallest-diff: "runtime `require` fn only, defer the
> `(ns ...)` macro one cycle"
>
> **Shape (1 sentence)**: ship D2/D3/D5/D7/D8 this cycle as a
> runtime `clojure.core/require` fn + env-aliases + circular-detect
> + per-file SourceContext registry + embedded resolver; punt D1
> (`(ns ...)` macro), D4 (`:refer × private`) and D6's full hybrid
> into Phase 6.16.b-5.
>
> **Per-D deltas**:
> - **D1**: defer. `.clj` heads stay `(in-ns 'foo)` + manual
>   `(require ...)` (legal Clojure — the JVM REPL works this way
>   too). No macro_transforms.zig change.
> - **D4**: defer. `:refer` only takes explicit name lists this
>   cycle; `:refer :all` raises `not_implemented`; no `^:private`
>   filtering path because no `:refer :all` consumers.
> - **D6**: keep the `FILES` table; bootstrap still hardcodes order,
>   but each entry's body is `(in-ns 'foo) (require ...)` — i.e.
>   bootstrap and user code share the runtime fn from D2, just
>   bootstrap is allowed to also `in-ns` directly. No "hybrid
>   loader" rewrite.
> - **D9**: only `runtime/eval/in_ns_auto_refer` flips (the 4
>   vm/tree_walk sites — once user code uses explicit `(require
>   'clojure.core)`, auto-refer can die). `refer_table` and
>   `bare_in_ns_decl` stay PROVISIONAL → ADR-0035 part 2 next cycle.
>
> **Better than proposal**:
> - One-cycle blast radius is roughly half (no macro expansion table
>   change, no JVM-shape `(ns ...)` edge cases like `:gen-class`
>   silent-ignore semantics, no `(:refer-clojure :exclude ...)`
>   filter logic). Lower regression surface in 6.16.b-4.
> - Keeps `(ns ...)` as a known-unknown for one more survey cycle.
>   JVM `(ns ...)` is genuinely fiddly (`:refer-clojure :rename`,
>   `:load`, AOT interactions); a one-cycle delay buys a Step-0
>   survey that focuses just on it.
> - Hardcoded FILES table is honest about what it is: a 4-line
>   bootstrap manifest. Replacing it with "same `require` path as
>   user code" creates a chicken-and-egg moment where loading
>   `clojure.core` requires `clojure.core/require` to be defined —
>   which means a hand-rolled `requireOne` Zig fn ends up underneath
>   anyway. Alt 1 doesn't pretend that's gone.
>
> **Breaks / worsens**:
> - **F-002 violation risk**: leaves 7 of 11 PROVISIONAL markers
>   in place after the cycle. The next cycle has to re-enter this
>   whole design — that's the Smallest-diff bias smell from
>   `.dev/principle.md`. The whole point of ADR-0035 per D-063 is
>   that 3 provisional behaviours converge here.
> - Bare `(in-ns 'foo)` at file heads is not idiomatic Clojure; it
>   ships JVM-divergent surface. Future readers (and any chapter-
>   cadence resumption per F-007) have to explain why.
> - `bare_in_ns_decl` PROVISIONAL stays — meaning the `.clj` files
>   are still self-documented as "not done".
>
> ### Alt 2 — finished-form-clean: "match proposal on
> D1/D2/D3/D5/D7/D9, but make `(ns ...)` an analyzer special form
> and split the resolver from D8"
>
> **Shape (1 sentence)**: D1 becomes an analyzer special form (not
> a macro); D6/D8 are conceptually split — the loader topology (D6)
> is hybrid as proposed, but the resolver (D8) is a tiny `*const
> fn` slot today with no "resolver chain" abstraction; everything
> else matches the proposal.
>
> **Per-D deltas vs proposal**:
> - **D1**: `(ns ...)` is an analyzer special form in
>   `src/lang/analyzer.zig` alongside `in-ns`, not a macro in
>   `macro_transforms.zig`. The analyzer reads the references list,
>   emits an explicit op-sequence (in-ns + refer-clojure +
>   require-per-arg) into the IR. No round-trip through
>   reader/macro-expander.
> - **D8**: just `Runtime.requireResolver: *const fn(*Runtime,
>   []const u8) anyerror!?SourceText` — no "stackable resolvers"
>   framing. Phase 12+ swaps the slot when `cljw_path` lands;
>   Phase 16+ swaps again for Wasm pods. F-001 (zwasm v2
>   unavoidable) is satisfied by "the slot is swappable", not by
>   "we built a chain today".
>
> **Better than proposal**:
> - **Analyzer special form (D1) beats macro on error quality**:
>   `(ns)` with no name, `(ns foo :bad-keyword [x])`, `(ns foo
>   (:require))` all produce precise location-tagged errors at
>   analyze time, not macro-expansion stage where positional info
>   is harder to reconstruct. Compare ADR-0032's `in-ns` analyzer
>   path at `analyzer.zig:368-382` — it already establishes the
>   pattern.
> - Analyzer-form `(ns ...)` cannot be accidentally shadowed by a
>   user `(def ns ...)` — Clojure JVM's macro can be, and people
>   hit this. Cleaner finished form.
> - **Resolver as a single fn slot (vs resolver chain abstraction)**:
>   F-002 says smallest-diff is tiebreaker when finished-forms
>   match. A "chain of resolvers" is a Reservation-as-bias smell
>   from `.dev/principle.md` — we don't have classpath, build
>   artifact, OR pod loading today; one swappable slot is the
>   finished form for "embedded source", and the next two are
>   separate decisions for their respective ADRs (12+, 16+) without
>   prejudging their composition.
>
> **Breaks / worsens**:
> - Analyzer special form means `(ns foo ...)` cannot be `apply`'d
>   or programmatically constructed — though neither can JVM's
>   `(ns ...)` macro be in practice (it must appear at top level).
>   Mostly equivalent.
> - Loses the "any user can write a similar macro for their own
>   DSL" angle. Probably irrelevant for cw v1 audience.
> - Adding a special form is a wider Zig diff than a
>   macro_transforms entry; main-loop's "macro-table entry" was the
>   smaller surgery. Within F-002, finished-form wins anyway.
>
> ### Alt 3 — wildcard: "defer D7 (per-file SourceContext) out of
> this ADR; keep D-058 open; ship D1–D6 + D8 + partial D9"
>
> **Shape (1 sentence)**: per-file SourceContext threading is a
> renderer-side concern that doesn't block the require/ns design
> surface — split it into a follow-up ADR-0036 and let ADR-0035
> stay focused on `require`/`ns` semantics.
>
> **Per-D deltas**:
> - **D7**: dropped from ADR-0035. The renderer keeps using the
>   single-`bootstrap_ctx` fallback. Multi-file bootstrap errors
>   continue to point at the wrong source line (the current bug).
>   D-058 stays open with `Last reviewed` reset.
> - **D8**: shipped as proposed — resolver is needed to make
>   `require` work at all.
> - **D9**: discharge plan loses the D-058 closure but flips all
>   the same yaml entries + 11 marker sites.
>
> **Better than proposal**:
> - **Tighter ADR scope = clearer Devil's-advocate framing for
>   future amendments**. D7 is genuinely orthogonal: it's about
>   which `SourceContext` the renderer pulls when an error fires,
>   not about `require` semantics. Conflating them means future
>   revisions of "how do we render multi-file errors" have to amend
>   an ADR that also governs `(ns ...)` macro shape.
> - Lower commit-size risk in sub-cycle d. The proposed
>   single-commit "11 marker sites + 3 yaml entries + 2 debt rows"
>   is at the upper bound of what's reviewable. Dropping D7 trims
>   to ~3 source files modified.
> - D-058's `Barrier: Phase 7 entry — require lands` was written
>   before this cycle existed; the barrier is met by ADR-0035 D8
>   (the resolver) regardless of whether D7 ships in the same ADR.
>
> **Breaks / worsens**:
> - **Bad Smell — "I'll fix it later"**. D-058 has been open since
>   2026-05-25 with a known wrong-source-line bug. Once `require`
>   lands and bootstrap loads 4+ files via a real loader path, the
>   bug's blast radius widens (more files = more chances the wrong
>   source line shows up). Deferring is exactly the
>   Progress-pressure smell.
> - Two ADRs cycle through where one suffices. F-002 prefers
>   consolidation when the finished-form is coherent — and
>   `require` + per-file source context ARE one finished-form
>   concern (both are "bootstrap loader knows about per-file
>   identity").
> - D-058's Barrier text in `.dev/debt.md:83` explicitly names
>   Phase 7 entry as the fix moment; deferring requires editing
>   that row to push out, which is a Reservation-as-bias adjacent
>   move.
>
> ### Recommendation: **Alt 2** (finished-form-clean) with one
> carry-over from proposal
>
> Land Alt 2's analyzer-special-form `(ns ...)` (D1) and single-slot
> resolver (D8); take everything else from the proposal as-is.
> Specifically:
>
> - **D1 → Alt 2**: analyzer special form, not macro. F-002 wins
>   on error quality + non-shadowability; ADR-0032's `in-ns`
>   precedent at `analyzer.zig:368-382` makes the surgery shape
>   known. The "macro table" path is smallest-diff bias.
> - **D2–D7, D9 → proposal**.
> - **D8 → Alt 2's single-slot framing**: `Runtime.requireResolver:
>   *const fn(...)`, no chain abstraction. F-001 satisfied by
>   swappability (Phase 12+ classpath swaps it, Phase 16+ Wasm pod
>   swaps it). Building the chain today is a Reservation-as-bias
>   smell — there is no second resolver in the room.
>
> **Reasoning**: F-002 (finished-form wins) dominates the D1
> decision. F-001 + F-002 jointly dominate D8 — a swappable slot
> satisfies F-001 without the Reservation-as-bias of a pre-built
> chain. Alt 1 fails F-002 hard (7 of 11 PROVISIONALs stay →
> re-entry next cycle). Alt 3 fails the smell sensor on D-058
> deferral.
>
> ### "Violates F-NNN" findings
>
> None of the three alternatives requires violating F-001 / F-002
> / F-007 / F-009. The envelope is comfortably wide for this ADR.
>
> One adjacent observation (not a finding, just context for the
> main loop): Alt 2's "eliminate the `rt` namespace entirely"
> candidate from the brief's prompt would be a finished-form-clean
> shape but expands the cycle scope well past Phase 6.16.b-4; that
> is a depth-3 ADR of its own and is correctly excluded from this
> cycle's envelope, not a violation.

## Selection rationale

Devil's-advocate Alt 2 を採択 (D1 + D8 部分)、 残 D2-D7 + D9 は
proposal そのまま。 理由:

- **D1 analyzer special form 採択**: F-002 finished-form 評価で
  Alt 2 が proposal を上回る (error precision + shadow 不可)。
  smallest-diff (= macro table 1 entry) は本来の cleanness を
  smallest-diff bias smell として却下。
- **D8 single fn slot 採択**: F-001 future-proof (zwasm v2 +
  Phase 12+ classpath) は slot swappable で十分成立。 chain
  abstraction は今 cycle に複数 resolver が存在しない (=
  Reservation-as-bias smell)。
- **Alt 1 全体却下**: 7/11 PROVISIONAL markers が次 cycle に
  繰り越し = Smallest-diff bias の本丸。 D-063 が ADR-0035 を
  "convergence point" と定めた前提が崩れる。
- **Alt 3 部分却下**: D7 を分離する argument は理論的に正しいが、
  D-058 の barrier が「require lands」 で本 cycle が require
  cycle そのもの、 deferral は Progress-pressure smell。 同 ADR
  内吸収を選択。
- **Adjacent observation 留保**: rt ns elimination は本 cycle
  scope 外で正しく除外。 sub-cycle a per-task note (D-NEW-A) に
  evaluate 候補として残置済。

violates-F-NNN finding: なし。

## Consequences

### Positive

- 11 PROVISIONAL marker sites + 3 yaml entries + 2 debt rows
  が単一 sub-cycle (d) で discharge、 ns-machinery cluster が
  finished form に到達。
- bootstrap と user code が同じ `requireOne` path を共有、
  load logic の 2-tier 分裂解消。
- `Namespace.aliases` の REPL-time 変更 path が API として確立、
  Phase 12+ tooling 拡張に向けた seam が clean。
- D-058 が closure、 multi-file bootstrap error の source-line
  preview bug が解消。

### Negative / costs

- analyzer special form 追加 (D1) は macro 化より surgery scope
  が広い (analyzer.zig + node.zig + 2 backend 追加)。 cycle 内で
  完結するが review surface 増。
- bootstrap.zig は hardcoded FILES table を失い `requireOne` 経由
  に統一されるため、 boot 初期化失敗時の trace が require chain
  経由になる (debug 経路が間接化、 ただし error message は
  circular_require + lib_not_found で十分 explicit)。
- `(:gen-class ...)` silent-ignore は user に「無視された」
  signal を出さない (compat tier 上 Tier D だが本 cycle で warn
  channel 整備せず)。

### Deferred to Phase 12+

- `cljw_path` env var / `-cp` flag 経由の file resolution
  (v5 §19.3 D3、 D-067 候補)。
- lazy load on first-reference vs eager-on-require (v5 §19.3 D5)。
- `:refer-clojure :rename` / `(:use ...)` / `(:load ...)` (JVM
  feature parity の残り)。

### Deferred to Phase 16+

- Wasm pod / Component model 経由の require (F-001 + D-067)。

## Affected files

### New

- `.dev/decisions/0035_require_spec.md` (this file).
- `src/eval/analyzer/special_forms.zig` 内 `analyzeNs` (or 新
  `analyzer/ns_form.zig`、 D-030 split 状況次第)。
- `src/eval/node.zig` 内 `NsNode` + `RequireNode` (or 個別 file)。
- `src/lang/primitive/require.zig` (`clojure.core/require` builtin
  fn)。
- `test/e2e/phase6_16_b_4_ns_require.sh` (Layer 2 e2e)。

### Modified

- `src/runtime/runtime.zig` — `requireResolver` slot + `require_in_progress`
  set + `source_registry` registry を追加。
- `src/runtime/env.zig` — `Namespace.setAlias` public API + 既存
  `referAll` の private filter 適用 + 新 `referOne`。
- `src/runtime/error/catalog.zig` — `circular_require` + `lib_not_found`
  Code 追加。
- `src/runtime/error/print.zig` — `source_registry` lookup 追加、
  fallback path 維持。
- `src/lang/bootstrap.zig` — `loadCore` を `BOOT_NAMESPACES` list
  + `requireOne` 呼出に書換、 hardcoded `FILES` table 削除、
  `CORE_SOURCE` / `SOURCE_LABEL` compat exports 削除。
- `src/lang/primitive.zig` — `referAll(rt_ns, user_ns)` 削除
  (PROVISIONAL discharge)。
- `src/lang/macro_transforms.zig` — `referAll(rt_ns, user_ns)`
  削除 (PROVISIONAL discharge)。
- `src/eval/backend/tree_walk.zig` — `evalInNs` の rt + clojure.core
  auto-refer 削除 (2 PROVISIONAL marker 解消)、 pure ns-switch 化。
- `src/eval/backend/vm.zig` — `op_in_ns` の rt + clojure.core
  auto-refer 削除 (2 PROVISIONAL marker 解消)、 pure ns-switch 化。
- `src/main.zig` — `bootstrap_ctx` 単一 SourceContext を撤廃、
  registry-backed lookup に切替。
- `src/lang/clj/clojure/core.clj` — 先頭を `(ns clojure.core
  (:refer-clojure))` (or 等価形) に書換。
- `src/lang/clj/clojure/set.clj` — 同様、 `(ns clojure.set
  (:require [clojure.core :as cc])` 等の正規形。
- `src/lang/clj/clojure/string.clj` — 同様。
- `src/lang/clj/clojure/walk.clj` — 同様。
- `feature_deps.yaml` — 3 ns-machinery entries flip `provisional
  → landed` + `special_form/ns_macro` flip `planned → landed` +
  11 PROVISIONAL marker line 削除。
- `.dev/debt.md` — D-058 + D-063 を Discharged。
- `test/run_all.sh` — 新 e2e 登録。

## Sub-cycle decomposition

- **Sub-cycle b** (本 commit): ADR-0035 draft + Devil's-advocate
  output verbatim 取込み + Accepted stamp。 source 変更なし。
- **Sub-cycle c**: D1-D8 source 実装 (analyzer special form +
  require fn + alias API + circular detect + per-file SourceContext
  + resolver slot)。 TDD red→green→refactor で複数 commit に
  分割可。 既存 bootstrap path を一旦 backwards-compat に保ちつつ
  新 path を導入、 まだ `.clj` heads は `(in-ns ...)` のまま。
- **Sub-cycle d**: D9 discharge atomic commit — `.clj` heads
  書換 (4) + PROVISIONAL marker 削除 (11) + yaml flip (3 → landed
  + 1 planned → landed) + debt close (D-058 + D-063) + evalInNs
  / op_in_ns simplification + bootstrap.zig finalization。
  `check_provisional_sync.sh` hook が三者同期 enforce。

## Revision history

- 2026-05-26 issued + accepted with Devil's-advocate fork
  (general-purpose subagent、 fresh context、 F-001 / F-002 /
  F-007 / F-009 envelope 内 3 alternatives 取得 verbatim、 Alt 2
  D1 + D8 部分採択、 残 D2-D7 + D9 proposal そのまま)。 v5 plan
  §19.3 + §21.1 SSOT、 survey
  `private/notes/phase6-6.16.b-4-survey.md` SSOT、 sub-cycle a
  per-task note `private/notes/phase6-6.16.b-4-sub-a.md` 参照。
  ADR-0032 (in-ns special form) + ADR-0033 D4 (D-071 Part 3
  closure) を依存先決定として参照。 D-063 + D-058 起票内、
  実装は sub-cycle c/d で着地。
