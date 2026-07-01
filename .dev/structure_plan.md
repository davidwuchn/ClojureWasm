# Anticipated directory structure — Phase 5-20 imagination

> Output of the Structural imagination phase
> (`.dev/principle.md`). The tree below predicts what the cw v1
> source tree will look like as Phase 5-20 ROADMAP entries land.
>
> ## Two kinds of entries below (read this before assuming "owner can amend")
>
> - **Decree** (≈ project law): entries directly tied to an
>   `F-NNN` in `.dev/project_facts.md` are **decreed**. The
>   owning Phase entry's owner does **not** re-decide them; the
>   owner implements them. Examples in the tree:
>   - `runtime/value/` split layout — decreed by F-004 +
>     co-related D-029.
>   - `runtime/numeric/{big_int,ratio,big_decimal,promote}.zig`
>     — decreed by F-005.
>   - `runtime/gc/{mark_sweep,root_set,free_pool,arena_node,
>     gc_strategy}.zig` — decreed by F-006.
>   - `runtime/wasm/{engine,linker,marshal,trap_map,host_func,
>     wasi,funcref,externref,…}.zig` — decreed by F-001 + F-008.
>   - `runtime/collection/{map_entry,range}.zig`,
>     `runtime/seq/{string_seq,array_seq}.zig`,
>     `runtime/reader_extra/{tagged_literal,reader_conditional}.zig`
>     — decreed by F-004 (day-1 64-slot enumeration).
>   - These entries are tagged **(F-NNN)** below. Owner amends
>     them **only** by user direction + F-NNN Revision history.
>
> - **Imagination** (open structural plans): entries not tied
>   to an F-NNN. The owning Phase entry's owner takes the part
>   that still makes sense and amends the part that does not,
>   per F-003 Structural imagination phase. Examples in the tree:
>   - `analyzer/` split exact file names (D-030 picks the
>     decomposition).
>   - `app/` internal organisation (D-031 picks file boundaries).
>   - These entries are tagged **★new** / **★split** + a
>     (D-NNN) debt pointer.
>
> Markers used below:
>
> - **★new** = directory or file that does not exist at HEAD,
>   anticipated to land at the noted Phase.
> - **★split** = current single file expected to fan out under
>   the noted Phase (per debt D-029 / D-030 / D-031 / D-033 /
>   D-035).
> - **(F-NNN)** = decreed by that F-NNN in project_facts.md;
>   owner implements, does not re-decide.
> - **(D-NNN)** = open structural plan; owning Phase entry
>   owner picks the shape within the F-NNN envelope.

## Origins of this file

Built 2026-05-24 from:

- The Phase 4 entry's as-shipped src/ tree.
- The Structural imagination research note
  (`private/notes/struct_imagination_research.md`, 525 lines —
  the cw v0 GC / Wasm / 45-tag / Clojure-JVM-140-class
  enumeration that informs the slot expansion in F-004).
- User direction F-001 (zwasm v2 unavoidable; carries JIT + GC),
  F-002 (finished-form wins), F-003 (defer to owning Phase),
  F-004 (64-slot NaN-box, types day-1: range / map_entry /
  tagged_literal / string_seq / array_seq / funcref / externref),
  F-005 (numeric tower JVM-surface compatible), F-006 (mark-sweep
  + 3-layer alloc; zwasm dual-heap; cw GC allocator injects into
  zwasm bookkeeping), F-007 (chapter cadence stays dormant),
  F-009 (feature-implementation neutrality; impl in namespace-
  neutral runtime/ root, Clojure/Java/cljw surfaces as thin
  wrappers — decreed 2026-05-24 alongside ADR-0029).
- ROADMAP §A1 (zone layering) + §A6 (≤ 1000 lines soft cap) +
  §A11 (day-1 enum reservation).
- ADR-0006 a1+a3 (zwasm) / ADR-0011 (host) / ADR-0012 a1 (NaN
  slots) / ADR-0023 (comptime stub) / ADR-0025 (chapter archive).

## Future tree (Phase 5-20)

```
ClojureWasm/
├─ build.zig
├─ build.zig.zon
├─ CLAUDE.md
├─ .dev/
│  ├─ ROADMAP.md
│  ├─ handover.md
│  ├─ principle.md
│  ├─ project_facts.md             (F-001..F-009, append-only)
│  ├─ structure_plan.md            (this file)
│  ├─ debt.yaml
│  └─ decisions/
│     └─ 0001…NNNN.md              (time-ordered, never reserved)
├─ scripts/                        pre-commit + pre-push hooks
│  ├─ check_smell_audit.sh
│  ├─ check_md_tables.sh
│  ├─ check_stale_git_lock.sh
│  ├─ check_learning_doc.sh        (dormant per ADR-0025)
│  ├─ check_roadmap_amendment.sh
│  └─ zone_check.sh
├─ test/
│  ├─ run_all.sh
│  ├─ e2e/                         phase4_cli.sh, phase4_exit.sh, …
│  ├─ diff/                        cases.yaml + runner.zig    (Phase 4.10+)
│  └─ clj/                         Clojure test port           (Phase 11+) ★new
├─ private/                        gitignored (notes, surveys, research)
│  └─ notes/                       per-task + research output
├─ docs/ja/
│  ├─ README.md                    (dormant marker)
│  └─ archive/                     learn_clojurewasm_v1_phase1to3 / learn_zig_v1
└─ src/
   ├─ main.zig                     Layer 3 entry (shrinks in Phase 8 ★split)
   ├─ app/                                         ★new (Phase 8 entry, D-031)
   │  ├─ repl.zig
   │  ├─ runner.zig                file / -e / stdin 共通の eval runner
   │  ├─ self_host_loader.zig                                Phase 8
   │  ├─ nrepl_server.zig                                    Phase 10
   │  ├─ builder.zig                                         Phase 12 (cljw build)
   │  └─ pod_runner.zig                                      Phase 16 (zwasm v2)
   ├─ runtime/                     Layer 0
   │  ├─ value/                                    ★split (Phase 5 entry, D-029, co-issued with D-027)
   │  │  ├─ value.zig              Value enum + NaN-box constants
   │  │  ├─ nan_box.zig            encode / decode helpers
   │  │  ├─ heap_tag.zig           HeapTag enum + 64-slot table (F-004)
   │  │  └─ heap_header.zig        HeapHeader struct + gc_and_lock
   │  ├─ runtime.zig
   │  ├─ env.zig                   Namespace / Var / dynamic binding stack
   │  ├─ dispatch.zig              Layer-0 VTable + threadlocal
   │  ├─ dispatch/                                 ★new (Phase 4 entry, landed at 4.25)
   │  │  ├─ method_table.zig       CallSite cache (4.25 skeleton; dispatch fn at Phase 7 per ADR-0008 a1)
   │  │  └─ callable.zig                                              ★new Phase 17 entry (D-035, backend-shared callable dispatch)
   │  ├─ error/                                    ★ Phase 5 終盤 consolidation (ADR-0029)
   │  │  ├─ info.zig               (= 旧 error.zig)
   │  │  ├─ catalog.zig            (= 旧 error_catalog.zig)
   │  │  └─ print.zig              (= 旧 error_print.zig)
   │  ├─ io/                                       ★ Phase 5 終盤 consolidation (ADR-0029)
   │  │  ├─ interface.zig          (= 旧 io_interface.zig、Tier 1)
   │  │  └─ default.zig                                       ★new Phase 5+ (Tier 2, std.Io バインド)
   │  ├─ type_descriptor.zig
   │  ├─ protocol.zig
   │  ├─ keyword.zig
   │  ├─ collection/
   │  │  ├─ string.zig             (current)
   │  │  ├─ list.zig               (current)
   │  │  ├─ ex_info.zig            (current)
   │  │  ├─ vector.zig                                        ★new Phase 5 (HAMT)
   │  │  ├─ hash_map.zig                                      ★new Phase 5 (HAMT)
   │  │  ├─ hash_set.zig                                      ★new Phase 5 (HAMT)
   │  │  ├─ array_map.zig                                     ★new Phase 5
   │  │  ├─ map_entry.zig                                     ★new Phase 5 (F-004 new slot)
   │  │  ├─ range.zig                                         ★new Phase 5 (F-004 new slot)
   │  │  ├─ sorted_map.zig                                    ★new Phase 6+
   │  │  ├─ sorted_set.zig                                    ★new Phase 6+
   │  │  ├─ persistent_queue.zig                              ★new Phase 6+
   │  │  └─ transient/                                        ★new Phase 5+
   │  │     ├─ transient_vector.zig
   │  │     ├─ transient_map.zig
   │  │     └─ transient_set.zig
   │  ├─ seq/                                       ★new Phase 5+
   │  │  ├─ lazy_seq.zig           (moved or co-resident)
   │  │  ├─ cons.zig
   │  │  ├─ chunked_cons.zig
   │  │  ├─ chunk_buffer.zig
   │  │  ├─ string_seq.zig                                    ★ F-004 new slot
   │  │  └─ array_seq.zig                                     ★ F-004 new slot
   │  ├─ reader_extra/                              ★new Phase 5+ (F-004 new slots)
   │  │  ├─ tagged_literal.zig
   │  │  └─ reader_conditional.zig
   │  ├─ numeric/
   │  │  ├─ big_int.zig            (current)
   │  │  ├─ ratio.zig                                         ★new Phase 5 (F-005)
   │  │  ├─ big_decimal.zig                                   ★new Phase 5 (F-005)
   │  │  └─ promote.zig                                       ★new Phase 5 (Long ↔ BigInt auto)
   │  ├─ gc/                                        ★new Phase 5 entry (F-006, D-011, D-020)
   │  │  ├─ mark_sweep.zig         tracing GC body (cw v0 path inheritance)
   │  │  ├─ root_set.zig           env / threadlocal / fn closure / lazy_seq / inline cache (5 sources cw v0 D100 patched late)
   │  │  ├─ free_pool.zig          intrusive free list (3-7x perf from cw v0)
   │  │  ├─ arena_node.zig         Analyzer-AST Arena (3-layer middle)
   │  │  └─ gc_strategy.zig        vtable abstraction (Arena ↔ MarkSweep switch)
   │  ├─ concurrency/                               ★new Phase 14-15
   │  │  ├─ atom.zig
   │  │  ├─ agent.zig
   │  │  ├─ future.zig
   │  │  └─ promise.zig
   │  ├─ stm/                                       ★new Phase 15 (ADR-0010)
   │  │  ├─ ref.zig
   │  │  ├─ dosync.zig
   │  │  └─ mvcc.zig
   │  ├─ wasm/                                      ★new Phase 16 entry (F-001 + F-008 + D-036)
   │  │  ├─ engine.zig             zwasm v2 Engine wrapper (cw GC allocator inject point per F-006 + D-038)
   │  │  ├─ linker.zig             zwasm v2 Linker wrapper (Clojure → defineFunc / defineMemory / defineWasi 橋渡し)
   │  │  ├─ module.zig             zwasm v2 Module wrapper (compile-once, instantiate-many)
   │  │  ├─ instance.zig           zwasm v2 Instance wrapper (Clojure Value から typedFunc/invoke 呼び出し)
   │  │  ├─ table.zig / global.zig / memory.zig    各 wasm 構成要素の Clojure-side handle
   │  │  ├─ funcref.zig            (★ F-004 inline slot — zwasm v2 ref:u64 を NaN-box Group D に inline、 要 align(8))
   │  │  ├─ externref.zig          (★ F-004 inline slot — 同上)
   │  │  ├─ marshal.zig            Clojure Value ↔ zwasm v2 Value (untyped invoke 経路、 §3.5、 cw v1 dynamic dispatch を支える要)
   │  │  ├─ trap_map.zig           zwasm Trap 12 variant → cw error_catalog Code への 1:1 mapping (D-038 で stability 確認後)
   │  │  ├─ host_func.zig          Clojure fn → zwasm `Linker.defineFunc` host import 登録 (Caller* 第一引数の optional 扱い per F-008 Q2 推奨)
   │  │  ├─ wasi.zig               WASI 統合 (F-008 Q4 推奨 = bulk defineWasi; cw io_interface との責務分離は D-039)
   │  │  └─ pod_boundary.zig       (zwasm v2 Pod-boundary connector if Pod path chosen — F-008 では inline path が default)
   │  │
   │  │  ───── 中立な OS / std ラッパ (ADR-0029 + F-009) ─────  ★new
   │  │  これらは Clojure ns 経由 (lang/primitive/) と Java ns 経由
   │  │  (runtime/java/) と cljw ns 経由 (runtime/cljw/) の三家族から
   │  │  共有される。F-009 が名前空間中立性を invariant 化。
   │  ├─ uuid.zig                                              ★new Phase 6 (16-byte 乱数 → UUID v4)
   │  ├─ clock.zig                                             ★new Phase 6 (mono + wall clock)
   │  ├─ random.zig                                            ★new Phase 6 (fast PRNG)
   │  ├─ uri_parse.zig                                         ★new Phase 6 (std.Uri ラッパ)
   │  ├─ path.zig                                              ★new Phase 6 (std.fs.path ラッパ)
   │  ├─ file_io.zig                                           ★new Phase 6 (io_interface 経由)
   │  ├─ charset.zig                                           ★new Phase 6 (UTF-8/16/Latin-1)
   │  ├─ locale.zig                                            ★new Phase 6+
   │  ├─ regex/                                                ★new Phase 6
   │  │  ├─ compile.zig, match.zig
   │  ├─ crypto/                                               ★new Phase 6+
   │  │  ├─ secure_random.zig
   │  │  └─ message_digest.zig
   │  ├─ time/                                                 ★new Phase 6
   │  │  ├─ instant.zig, local_date.zig, local_date_time.zig
   │  │  ├─ duration.zig, zone.zig
   │  ├─ net/                                                  ★new Phase 14+
   │  │  ├─ socket.zig, url.zig, dns.zig
   │  │
   │  │  ───── Java-compat surface (ADR-0029、ADR-0011 を supersede) ─────  ★new
   │  ├─ java/                                                 ★new (Phase 6+ 着地、ADR-0011 supersede)
   │  │  ├─ _README.md             配置基準 + Backend marker 規約
   │  │  ├─ _host_api.zig          ___HOST_EXTENSION marker (元 host/_host_api.zig)
   │  │  ├─ lang/                  Object, String, Long, Integer, Double, Boolean, Character, Math, System, Throwable, Exception, RuntimeException, Thread
   │  │  ├─ io/                    File, PrintWriter, InputStream, OutputStream, Reader, Writer, ByteArrayInputStream, ByteArrayOutputStream
   │  │  ├─ util/                  UUID, Date, Random, Locale, regex/{Pattern, Matcher}, concurrent/{Future, atomic/AtomicLong}
   │  │  ├─ time/                  Instant, LocalDate, LocalDateTime, Duration, ZonedDateTime, ZoneId
   │  │  ├─ net/                   URL, URI                                                          (Phase 14+)
   │  │  ├─ nio/                   file/{Path, Files}, charset/Charset                              (Phase 6+)
   │  │  ├─ math/                  BigInteger, BigDecimal
   │  │  ├─ security/              MessageDigest, SecureRandom                                       (Phase 14+)
   │  │  └─ reflect/               Method, Field (薄、TypeDescriptor 経由)                          (Phase 7+ Tier C)
   │  │
   │  │  ───── cljw-original surface (ADR-0029) ─────  ★new
   │  └─ cljw/                                                 ★new (Phase 10+ 着地)
   │     ├─ _README.md
   │     ├─ build/Compiler.zig                                 (Phase 12, cljw.build/compile)
   │     ├─ wasm/{Engine, Module, Instance, Component}.zig     (Phase 16+, cljw.wasm/instantiate)
   │     ├─ edge/{Server, Request}.zig                         (Phase 14+, cljw.edge/serve)
   │     ├─ pod/Pod.zig                                        (Phase 16+, cljw.pod/invoke)
   │     └─ repl/NReplServer.zig                               (Phase 10+)
   ├─ eval/                        Layer 1
   │  ├─ analyzer/                                 ★split (Phase 5+ entry, D-030; already 1335 lines today)
   │  │  ├─ analyzer.zig           entry + orchestration
   │  │  ├─ special_form.zig       SPECIAL_FORMS dispatch
   │  │  ├─ symbol.zig             resolution + Scope
   │  │  ├─ macro.zig              macro expand routing
   │  │  └─ deftype_analyze.zig                              ★new Phase 5+ (deftype / defrecord / reify)
   │  ├─ driver.zig
   │  ├─ evaluator.zig             (compare across backends)
   │  ├─ form.zig
   │  ├─ macro_dispatch.zig
   │  ├─ node.zig
   │  ├─ reader.zig
   │  ├─ tokenizer.zig
   │  └─ backend/
   │     ├─ tree_walk.zig
   │     ├─ vm.zig
   │     ├─ vm/
   │     │  ├─ compiler.zig
   │     │  └─ opcode.zig
   │     └─ jit/                                   ★new Phase 17 entry (D-035 + ADR-0005)
   │        ├─ codegen.zig
   │        ├─ compiler.zig
   │        └─ runtime.zig
   └─ lang/                        Layer 2
      ├─ bootstrap.zig
      ├─ diff_test.zig
      ├─ macro_transforms.zig
      ├─ primitive.zig             registry
      ├─ primitive/                                ★split (Phase 5+, D-033)
      │  ├─ core/
      │  │  ├─ core.zig            general fns
      │  │  ├─ sequence.zig        map / filter / reduce / partition / interleave
      │  │  └─ type.zig            type? / instance? / class
      │  ├─ math.zig
      │  ├─ io/                                    ★new Phase 5+
      │  │  ├─ print.zig
      │  │  └─ read.zig
      │  ├─ numeric/                               ★new Phase 5 (F-005)
      │  │  ├─ promote.zig
      │  │  └─ bigint.zig
      │  ├─ collection/                            ★new Phase 5+
      │  └─ error.zig
      └─ clj/                      Clojure source (bootstrap)
         └─ clojure/
            ├─ core.clj            (current)
            └─ (landed pre-Phase 9: string/set/walk/zip; Phase 9: edn + data/{json,csv} + tools/cli; Phase 10+: pprint)
```

## Cross-phase coordination notes

- **Phase 5 entry is the biggest single landing**: GC (`gc/`) +
  numeric (`numeric/ratio.zig` + `big_decimal.zig` + `promote.zig`)
  + value split (`value/`) + collection wave 1 (`vector/hash_map/
  hash_set/array_map/map_entry/range`) + analyzer split + new
  reader-extra slots (`tagged_literal`) + host first wave. The
  ADR cluster is large (D-027 + D-029 + D-030 + D-032 + D-011 +
  D-020 + D-014a + D-017). The Phase 5 entry owner co-issues
  these as a co-ordinated cluster, not one at a time.
- **Phase 8 entry triggers `src/app/` extraction** before the
  Phase 10 nREPL / Phase 12 builder land. main.zig stays as a
  thin Juicy-Main entry; everything else moves under `app/`.
- **Phase 16 entry decides zwasm integration shape** (F-001 +
  F-006 + D-036). The decision is between Pod boundary
  (default) and inline NaN-box `funcref` / `externref` (the
  F-004 reservation that this file marks as ★ Phase 16 entry).
- **Phase 17 entry triggers backend dispatch extraction** under
  `src/runtime/dispatch/callable.zig` before adding
  `src/eval/backend/jit/`.

## When to update this file

- A Phase entry's owner amends the **★new / ★split (D-NNN)
  parts**  as decisions land (and records which sections they
  touched).
- **(F-NNN) parts are not amended by the loop on its own.** A
  user-declared invariant (new F-NNN in `project_facts.md`) is
  the only thing that can change a decreed entry. When that
  happens, the F-NNN's Revision history records the change, and
  this file follows.
- Audits (`audit_scaffolding` skill) flag drift between this file
  and the live src/ tree.

This file is **append-only history** for amendments; sections
that no longer reflect reality get `(superseded by F-NNN /
ADR-NNNN at YYYY-MM-DD)` notes appended, not deletions.
