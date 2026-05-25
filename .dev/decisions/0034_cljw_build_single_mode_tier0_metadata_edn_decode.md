# 0034 — cljw build single mode + Tier 0 metadata + structured EDN error event + post-mortem decode

**Status**: Accepted (Devil's-advocate fork landed 2026-05-25)
**Date**: 2026-05-25
**Author**: Shota Kudo (drafted with Claude autonomous loop)
**Tags**: phase-12-prep, build-pipeline, error-observability,
edge-target, F-001, F-006, F-009

## Context

cw v1 のメインターゲットは **エッジ実行** (Cloudflare Workers /
WASM Component / serverless cold-start)、 起動 < 5ms 要件。 `cljw
build` の output 形式 + error observability spec を本 ADR で確定する。
v5 §11-§14 + §19.2 SSOT。

cw v0 履歴 (Phase 28 source bundle → Phase 31 bytecode embed →
Phase 32 source bundle default + 32.2-32.3 bootstrap cache →
Phase 37.4 narrow JIT 着地) の 4 段階を再評価:

- Phase 32 で source bundle に統一したのは UI 整理 + multi-file
  require chain の bytecode dependency order 解決コスト回避が動機、
  **技術的判断ではない**
- Phase 31.5 短期間の bytecode embed user app 体験 + Phase 32.2-32.3
  bootstrap cache (12ms → 3-4ms 起動高速化) が user の 「bytecode 方が
  優れていた気がする」 直感の合成記憶根拠
- Phase 37.4 (ARM64 JIT PoC、 arith_loop 10.3x speedup) が source bundle
  形態の **後** に問題なく着地、 **JIT は embed 方式と完全直交** evidence

エッジ用途で source bundle (cold start +20-50ms) は許容不可。
**bytecode embed default** が技術的に正解。 ただし cw v0 が source
bundle を選んだ複雑さ (multi-file require chain の bytecode dependency
order) は本 ADR では ADR-0035 (require spec) に委譲し、 ADR-0034 は
build pipeline + error observability に focus する。

Phase 6.16.a-1 cycle (commit d35dc3b) terminus で Tier 0 metadata size
baseline 計測完了 (`bench/quick_baseline.txt` の `binary_size_bytes`
row、 release build = 820,568 bytes 近辺)、 これが本 ADR の Tier 0
overhead measurement の reference baseline。

## Decision

### D1: cljw build single mode、 flag ゼロ

```sh
cljw build app.clj -o app
  → app  (single binary、 source 含めない)
```

`--debug` / `--source` / `--aot` / `--no-symbols` 等の flag を **全廃止**。
default 動作のみ。 user は何も意識しない。 dev / REPL は別 command:

```sh
cljw file.clj             # direct source eval
cljw repl                 # interactive REPL
cljw render-error err.edn # post-mortem decode (D11)
```

build mode と dev mode を完全独立に運用、 dev 体験は source 直 eval で
snippet 描画含めて完全。

### D2: bytecode embed default、 source 含めない、 sidecar なし

binary 内容:

| 項目                       | 必須?    | 備考                                               |
|----------------------------|----------|----------------------------------------------------|
| cljw runtime               | 必須     | Reader + Compiler + VM + GC 同梱                   |
| Bootstrap cache (bytecode) | 必須     | core lib build-time bytecode 化                    |
| User code bytecode         | 必須     | source の 0.8-1.2x                                 |
| Tier 0 metadata            | 必須     | bytecode の 5-10% (D3)                             |
| build-id                   | 必須     | git SHA + cljw version (D5)                        |
| Source (full)              | 含めない | dev 時の手元 git source + cljw render-error で復元 |

**cljw runtime には Reader + Compiler が常時同梱** (= bytecode embed
default でも runtime の `(eval ...)` / `(load-string ...)` / `defmacro`
の macroexpand のため必須)、 bootstrap cache restore path で Reader +
Compiler を bypass。

### D3: Tier 0 metadata (var/file/line/col interned tables) 常時 ON

各 bytecode op に対応する:
- var name (interned string table)
- file path (interned string table)
- line number (delta-encoded)
- col number (delta-encoded)

= 最小限の symbolication 情報のみ、 source 全文は含めない。 stack
trace の line/col + var name を production 環境でも無条件に取れる。

size budget: 5-10% overhead (Phase 6.16.a-1 baseline = ~820 KB release
binary に対する measurement reference)。 超えた場合 ADR-0034 amendment
で削減策。

### D4: Deno-style binary trailer 形式 + bootstrap cache build.zig 統合

```
[cljw runtime binary (Mach-O / ELF / Wasm)]
[bootstrap cache: serialized bytecode + var table + ns table]
[user app bytecode payload]
[Tier 0 metadata table]
[build-id block]
[u64 size of payload+metadata+build-id]
["CLJC" magic 4 bytes]
```

起動 flow:
1. cljw runtime が argv[0] から自身を open
2. 末尾 4 bytes を read、 magic check
3. u64 size を read、 payload + metadata + build-id 領域を mmap
4. bootstrap cache restore (~3-4ms、 cw v0 evidence)
5. user app bytecode → VM dispatch
6. (error 時) Tier 0 metadata から var/file/line/col を引いて trace 構築

bootstrap cache は build.zig 時に `cache_gen.zig` が全
`src/lang/clj/clojure/*.clj` を eval して VM state を serialize、
binary に `@embedFile` (cw v0 Phase 32.2-32.3 形態維持)。

### D5: build-id 形式

```edn
{:git    "abc1234567890abcdef"      ; commit SHA (40 chars or short)
 :cljw   "0.1.0"                     ; cljw version (semver)
 :built  #inst "2026-05-25T12:34:56Z"}
```

map 形式で binary 内に EDN として埋め込み。 error event 出力時に必ず
含める (D8)。 dev 側 post-mortem (`cljw render-error` D11) が `:git` SHA
で `git checkout` 同期を user に案内、 `:cljw` で decoder archive
dispatch (D11)。

### D6: format version policy = ABI commitment 不要

cljw build の output は **self-contained**: runtime + bytecode が同
binary に接着、 mismatch 構造的に発生しない (= Deno / Bun / Go と同
pattern)。

- bytecode format は **internal-only**、 user 視点では存在しない
- format version up は新 cljw build で再生成すれば済む、 既存 binary
  は古い cljw runtime で永久動作
- **format version policy 不要**、 ABI commitment 不要

唯一の互換性責任: **`cljw render-error` decoder の永久互換性**
(D11 archive policy)。

### D7: error output = stream-separated (TTY=human / pipe=structured EDN one-line)

stderr は **常に 1 つの format**:

| 環境              | format                                   | 用途                             |
|-------------------|------------------------------------------|----------------------------------|
| TTY (interactive) | human readable (色付き、 babashka-style) | 対話開発、 REPL、 dev binary     |
| pipe (非 TTY)     | structured EDN (1 event = 1 line)        | production logs、 log aggregator |

混合しない。 pipe で渡せば直接 jq/grep/awk で機械処理可能 (EDN→JSON
1 段変換)。

### D8: EDN event schema

```edn
{:phase      :runtime | :analysis | :read
 :category   :type_error | :name_error | :arity_error | :private_access_error | ...
 :message    "split: expected string, got nil"
 :file       "src/handlers/auth.clj"
 :line       42
 :col        8
 :var        clojure.string/split        ; symbol
 :ex-data    {:input nil, :sep #"\s+"}   ; user attached data
 :trace      [{:var handlers.auth/parse-token   :file "..." :line 42 :col 8}
              {:var handlers.auth/login-handler :file "..." :line 18 :col 3}]
 :build-id   {:git "abc1234" :cljw "0.1.0" :built #inst "2026-05-25T12:34:56Z"}
 :timestamp  #inst "2026-05-25T12:35:01.234Z"
 :request-id "abc-123"      ; optional、 user runtime が `cljw.error/with-context` で injectable
 :trace-id   "xyz-456"}     ; 同上
```

完全 spec は v5 Appendix C 参照。 1 event = 1 line (改行は `\\n`
escape)、 top-level key 順固定 (`:phase :category :message :file :line
:col :var :ex-data :trace :build-id :timestamp <user-injection>`)。

### D9: env var override

```
CLJW_ERROR_FORMAT=human       # 強制 human
CLJW_ERROR_FORMAT=structured  # 強制 structured EDN
CLJW_ERROR_FORMAT=both        # 両方 (human stderr + structured CLJW_ERROR_LOG)
CLJW_ERROR_LOG=/var/log/cljw.edn   # structured を別 file へ、 stderr は human
```

Phase 14 v0.1.0 release で stable spec として lock (D-066)。

### D10: human renderer = cw v1 既存 babashka-style 流用

cw v1 現状の renderer (`src/runtime/error/render.zig` 相当) を流用、
trace 描画追加のみ。 D7 の TTY-aware default で structured EDN trailer
を混合しない (= human stderr / structured `CLJW_ERROR_LOG` は別 channel、
混合 parse 問題なし)。

### D11: `cljw render-error` post-mortem tool + decoder archive

CLI:
```sh
cljw render-error err.edn
  → 1 event ごと human render 出力 (TTY なら色付き、 pipe なら plain)
  → :file の source が手元 git repo にあれば snippet + caret 復元

cljw render-error --source-from-git $sha err.edn
  → 指定 SHA で git checkout → source snippet 復元

cljw render-error --format json err.edn
  → EDN を JSON に変換出力 (log aggregator 用)
```

decoder archive policy:
- `cljw-formats/<version>.edn` archive を repo 内に永久保管
- 例: `cljw-formats/0.1.0.edn` には 「op_call = 0x10、 op_const = 0x11、
  ...」 等の opcode table
- `cljw render-error` は build-id `:cljw` を読んで対応 archive を load
  して decode
- 新 cljw release ごと archive 追加、 **削除しない**
- = decoder 単方向永久互換性、 encoder 互換性責任なし

Phase 12 entry で internal API + decoder skeleton 着地 (D-064)、 Phase
14 v0.1.0 release で `cljw-formats/0.1.0.edn` archive lock (以降 add
only)。

## Alternatives considered

Devil's-advocate fork (general-purpose subagent、 fresh context、
2026-05-25 issuance、 F-001/F-004/F-005/F-006/F-009 envelope 内)
output verbatim:

#### Alt 1: cw v0 Phase 32 形態踏襲 (smallest-diff)

`cljw build` の出力を **source bundle default + `--bytecode` flag opt-in** とし、 Tier 0 metadata table・structured EDN error event・`cljw render-error` post-mortem tool のいずれも導入しない。 error 出力は既存の babashka-style human renderer のみ。 trailer 形式は cw v0 Phase 32.2-32.3 をそのまま継承し、 build-id は git SHA 単独 (map 化なし)。

- **利点**: 実装差分が最小 (v0 → v1 移行 cost が低い)、 source bundle により bundled artifact が `cljw -e` で即 inspectable、 schema 議論を Phase 後送りにできる。
- **欠点**: production 配布で source 同梱が IP 漏洩 vector になる、 runtime error の machine-parseable 出力が存在しないため CI / log aggregation 統合に都度 ad-hoc parser が必要、 Tier 0 metadata 不在で stack trace の file/line/col 情報が空白、 post-mortem tool 不在で format version drift 発生時に過去 artifact を decode できない。
- **F-NNN 関係**: F-001 / F-004 / F-005 / F-006 とは独立。 F-009 (feature-implementation neutrality) には準拠 — 既存形態の延命であって新規 feature 縛りなし。
- **F-NNN violation**: なし。

#### Alt 2: ADR-0034 本提案 (D1-D11) (finished-form-clean)

`cljw build` を flag ゼロの単一 mode に固定し、 bytecode embed default + Tier 0 metadata 常時 ON + Deno-style trailer + map 形式 build-id + stream-separated error output (TTY=human / pipe=EDN one-line) + `cljw render-error` post-mortem decoder archive を採用。 format version policy は ABI commitment 放棄 (self-contained binary により mismatch が構造的に発生しない) で、 互換性責任を decoder 側に集中。

- **利点**: distribution artifact が 1 binary に確定し flag 選択の cognitive cost ゼロ、 EDN event schema により CI / log pipeline が初日から structured parse 可能、 Tier 0 metadata の常時 ON 化で stack trace の file/line/col が空白にならず error UX が JVM Clojure 水準に到達、 post-mortem decoder archive により過去 build-id を持つ artifact を future cljw で reproducibly decode 可能、 build-id map (`:git :cljw :built`) で release 追跡が EDN 解析だけで完結。
- **欠点**: Tier 0 metadata の size budget (5-10%) を恒久的に支払う、 EDN schema が `:phase :category :message :file :line :col :var :ex-data :trace :build-id :timestamp` の 11 key 固定で初期 design の拘束が強い (key 追加は decoder archive bump を要する)、 decoder archive (`cljw-formats/<version>.edn`) を v0.1.0 release で lock する commitment が発生し、 archive の forward maintenance が future Phase の永続 cost、 stream-separated output は TTY 判定 (`isatty(2)`) に依存し redirect 経由の subtle pipeline で human 形式が EDN consumer に混入する事故 surface が残る。
- **F-NNN 関係**: F-001 (zwasm v2 library import) — cljw user code path と zwasm wasm execution path の分離を破らない。 F-004 (NaN-box 64 slot) — metadata table は heap interned で NaN-box slot を消費しない。 F-005 (数値タワー JVM 表面互換) — error event `:ex-data` に numeric 値が乗っても tower semantics に影響なし。 F-006 (mark-sweep + 3-layer allocator) — Tier 0 table は permanent allocator tier に置くことで GC root に依存しない。 F-009 — feature 列挙ではなく単一 build mode 固定なので neutrality に準拠。
- **F-NNN violation**: なし。

#### Alt 3: AOT native + JIT 完全廃止 (wildcard)

`cljw build` を **WebAssembly AOT compile → ELF/Mach-O native binary 生成 ahead-of-time** に置き換え、 runtime の wasm interpreter / JIT path を artifact からは完全に剥がす (wasmtime-style AOT pre-compilation を build-time に強制)。 bytecode embed は不要となり、 Tier 0 metadata は DWARF debug section に流し込む。 EDN error event は標準入出力に streaming で出すが、 decoder archive は DWARF version dispatch に統合する。

- **利点**: artifact 起動 latency が interpreter loop ゼロで cold-start near-zero、 OS-native debugger (lldb / gdb) が DWARF 経由でそのまま stack trace を解釈し外部 tooling 統合が無料、 trailer format の独自 versioning を捨てて ELF/Mach-O の既存規格に乗れる、 distribution size が trailer-less で純粋 binary。
- **欠点**: cljw user code の eval / REPL / dynamic var 再定義 が AOT 前提と root から衝突 (Clojure の dynamic recompilation surface を放棄することになる)、 DWARF への metadata mapping は platform-specific (Mac/Linux/Windows) で host abstraction の負担が爆発、 wasm 実行 path を build artifact から剥がすと cljw user code と zwasm wasm execution の path 分離が崩れる。
- **F-NNN 関係**: **F-001 と直接衝突** — cljw が zwasm v2 を library として import し cljw user code path と wasm execution path を分離する前提が、 wasm AOT を cljw 側の build pipeline に組み込むことで融合してしまう。 F-004 / F-005 / F-006 とは独立に解決可能。 F-009 は build mode 単一固定の点で本提案と同等。
- **F-NNN violation**: **あり (F-001)**。 zwasm v2 library import 前提を維持しながら AOT native binary を出すことは、 Clojure dynamic eval surface (F-009 の neutrality に含まれる REPL/eval 機能) を犠牲にせず実現する path が現時点で見えない。 finished-form-clean を志向する場合でも、 F-001 の amendment は user action であり、 主 loop は本 wildcard を採用すべきではない (= 記録のみ、 採用候補から除外)。

## Selection rationale

Alt 2 (本提案) を選択。 F-002 (finished-form wins) + cljw メインターゲット
が エッジ実行であり cold-start < 5ms 要件下で source bundle 形態が
許容不可、 + Tier 0 metadata + structured EDN により ops observability
が初日から成立する利点が決定的。 Alt 1 は IP 漏洩 vector + machine-
parseable error 不在で production 適合性低い。 Alt 3 は F-001 violation
(zwasm 依存方向逆転 + dynamic eval surface 喪失) で envelope 外。

Alt 2 の Breaks 5 件は受容コストとして識別:
- (i) 5-10% size 恒久支払 → Phase 6.16.a-1 baseline (820KB) に対し
  ~50KB overhead = エッジ 10MB platform 制約に対しても余裕
- (ii) EDN schema 11 key 固定 → key 追加は ADR-0034 amendment + decoder
  archive bump で対応、 cost は明示的
- (iii) decoder archive forward maintenance → 削除 forbidden / add only、
  v0.1.0 release 時に initial archive 確定後は cycle ごとに 1 entry
  追加するだけ、 amortise 容易
- (iv) human / EDN 混入事故 → env var `CLJW_ERROR_FORMAT` で強制可能、
  default は TTY 判定だが ops が pipeline 設計時に明示 override 推奨
- (v) Phase 12 entry でこれら 11 D-items を一括 implement する必要 →
  D-064 (post-mortem) + D-066 (env var spec) + ADR-0033 cluster
  workflow で段階着地 path 設計済

## Consequences

- **Phase 12 entry deliverable**: bytecode embed pipeline 完成 (`cljw
  build app.clj -o app` internal API、 single mode、 flag ゼロ) +
  Tier 0 metadata serializer/deserializer + build-id injection +
  Deno-style binary trailer + bootstrap cache build.zig 統合 +
  `cljw render-error` internal API + `cljw-formats/<version>.edn`
  archive 初版 + error output stream-separated (TTY=human / pipe=EDN)
  + env var recognition
- **Phase 14 entry deliverable (v0.1.0 release)**: `cljw build` /
  `cljw render-error` CLI surface 公開 + `cljw-formats/0.1.0.edn`
  archive lock + `CLJW_ERROR_FORMAT` / `CLJW_ERROR_LOG` env var
  公式 spec 化 + `cljw.error/with-context` macro 公開
- **Phase 16 entry**: ClojureScript transpiler が `defn-` + `-name`
  leaf を JS interop に置換するレイヤで `^:zig-leaf` metadata を読む
  (ADR-0033 D4 + D-068 と整合); Wasm Component output が同 binary
  trailer 形式を踏襲可能
- **Phase 17 entry**: JIT go の場合、 D6 (ABI commitment 不要) の下で
  bytecode に source-level metadata 保持 option を broad JIT 用に追加
  可能 (ABI 維持しつつ拡張)、 narrow JIT は完全直交 (ADR-0033 D10 と
  整合)
- placement.yaml + compat_tiers.yaml schema は本 ADR と独立 (= placement
  は ADR-0033、 compat_tiers は ADR-0029)
- format version 概念を撤回することで `version_field` / `magic upgrade`
  系の implementation cost を回避、 decoder archive の add-only policy
  で互換性責任を decoder 側に集中
- EDN event schema の固定 11 key は user runtime injection (`:request-
  id` 等) を許す形で拡張可能、 schema 自体の breaking change は ADR-
  0034 amendment

## Affected files

- `.dev/ROADMAP.md` §9.14 / §9.16 — 既に v5 wiring (757a0b5) で
  expansion 済 (本 ADR は SSOT 化)
- `.dev/debt.md` D-064 (decoder archive) / D-066 (env var spec) — 既に
  起票済 (757a0b5)
- `private/notes/clj_vs_zig_split_proposal_v5.md` §11-§14 + §16.1 + §19.2
  + App C (EDN schema 完全 spec) — 本 ADR の SSOT

Phase 12 entry 以降の Affected files (本 cycle 時点では未着地):

- `src/app/builder.zig` (Phase 12 着地、 build-id 埋め込み + bytecode
  serialize 完成)
- `src/runtime/error/render.zig` (TTY-aware + EDN serializer 拡張)
- `src/runtime/error/event.zig` (新規、 EDN event schema 実装)
- `src/app/render_error.zig` (新規、 post-mortem tool entry point)
- `cljw-formats/0.1.0.edn` (新規 archive、 v0.1.0 release 時に lock)
- `build.zig` (cache_gen + build-id injection 拡張)

## Revision history

- 2026-05-25 issued + accepted with Devil's-advocate fork
  (general-purpose subagent、 fresh context、 F-NNN envelope 内 3
  alternatives 取得 verbatim、 Alt 2 採択、 Alt 3 が F-001 violation
  寄りの旨を明示)。 v5 plan §11-§14 + §19.2 (1593 行、 self-
  contained) を SSOT として参照、 Tier 0 metadata size baseline
  measurement (Phase 6.16.a-1 d35dc3b terminus) を起票 prerequisite
  として参照。
