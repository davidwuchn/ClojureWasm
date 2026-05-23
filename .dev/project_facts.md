# Project facts — user-declared invariants

> **What this file is for.** ClojureWasm v2's ROADMAP / ADRs /
> rules describe the *engineering decisions* the project has
> committed to. This file captures the **invariants the user has
> declared** that those documents may not yet reflect — facts the
> autonomous loop must treat as load-bearing even when ROADMAP /
> ADR text appears to admit other readings.
>
> The autonomous loop must read this file as part of every Phase
> entry's reading list (CLAUDE.md Step 1a) and consult it whenever
> a planned change touches the topics below.
>
> This file is **append-only history** — entries are dated and
> never silently rewritten. A later fact that supersedes an
> earlier one is added as a new entry with a `Supersedes: <id>`
> line; the earlier entry stays, annotated `Superseded by: <id>`.

## How to add an entry

User declares a project-level invariant in chat that the loop
should treat as fact. The loop captures it here as the next
`F-NNN` entry with verbatim or near-verbatim quoting + a one-line
"why this matters for the loop" + cross-reference to the ROADMAP
section / ADR / debt row it interacts with. The user reviews the
entry at end of session.

---

## F-001 — zwasm v2 integration is unavoidable

**Declared**: 2026-05-23 (user chat).
**Verbatim**: 「このプロジェクトがzwasmと連携するのは確実です。zwasm
v1は今それなりの完成度ですが、zwasm v2と連携するつもりです。
$My/zwasm_from_scratchはまだ開発途上ですが、wasm FFIは欠かせない
要素だということは自覚してください。また、zwasmはそれ自体がJITや
メモリ管理の機能を持っています」

**What this changes for the loop**:

1. ADR-0006 frames Wasm FFI as "deferred to Phase 16 via Pod
   boundary". The Pod-boundary framing remains the **default
   protocol shape**, but the inline-vs-Pod choice **is not closed**.
   Phase 16 entry must re-open it with the user (D-036).
2. ADR-0006 amendment 1 (NaN-box slot release for big_int /
   ratio) assumed Pod-boundary. If Phase 16 chooses inline
   NaN-box Values, those slots cannot be reclaimed — Phase 16
   must mint fresh slots, co-ordinated with D-027 (NaN-box
   layout 第二世代).
3. zwasm v2 carries its own JIT + GC. cw v2's Phase 5 mark-sweep
   GC and Phase 17 JIT (ADR-0005 3rd backend) **overlap
   territorially**. Phase 16 entry resolves heap-boundary and
   JIT-coordination design (cw-heap vs wasm-heap, JIT handoff).
4. The counterparty is **zwasm v2**, not zwasm v1. zwasm v1 is
   reasonably complete, but cw v2 targets zwasm v2.
   `~/Documents/MyProducts/zwasm_from_scratch/` is the in-progress
   counterparty repo.

**Cross-references**: ADR-0006 amendment 3 (records this fact in
the ADR); debt D-036 (Phase 16 inline-vs-Pod decision); ROADMAP
§9.18 Phase 16 placeholder (Entry debts).

---

## F-002 — Finished-form cleanliness wins; shipping fast / avoiding rework are second-tier

**Declared**: 2026-05-23 (user chat).
**Verbatim**: 「完成した時の綺麗さ、 が何よりも優先されています。
さっさと作る、 手戻りしない、 は二の次です(もちろん少ないに越した
ことはないので事前ロードマップを敷いているが)」

**What this changes for the loop**:

1. Big surgery (depth 3-4 in `.dev/principle.md`) is welcome when
   the plan misses something. The autonomous loop must not
   hesitate at ADR-level revisions.
2. ROADMAP P5 ("smallest-diff first") is a tie-breaker, not a
   veto. If smallest-diff and finished-form collide, finished-form
   wins.
3. Skeleton-then-rewrite is endorsed (per
   `permanent_noop_forbidden.md`), but excessive skeletons are a
   smell (Smallest-diff bias smell in principle.md).
4. Reservations (ADR numbers, NaN-box slots, debt rows promising
   future ADRs) are memos, not contracts. ADR numbers are
   time-ordered (`max + 1` at issue).

**Cross-references**: CLAUDE.md § Project spirit (top); ADR-0029
→ ADR-0025 rename history; D-021 retirement; principle.md Bad
Smell catalogue.

---

## F-003 — Decision-deferral over decision-seizure on structural plans

**Declared**: 2026-05-23 (user chat).
**Verbatim**: 「すでにロードマップが将来にわたるまであるのだから、
テーブル予約についてどれくらいありそうかを省略せずにしっかり
想像するフェーズを入れて、 どうするかを決めるのはその担当のとき
にやってください」
+ 「あと、 ついでにディレクトリ構造、 ファイル構造の予測や責務
分離や依存関係でも将来にわたり無理がこないのかを想像・シミュレート
して考えてみて」

**What this changes for the loop**:

1. The loop's job at any task touching a reservation table /
   directory or file structure / responsibility / dependency
   graph is **imagine, record, defer** — not decide.
2. Decisions belong to the owning Phase entry's owner. The
   current loop records the imagination output as debt rows
   scheduled at the owning Phase.
3. This is the antidote to the Progress-pressure smell on
   structural work.

**Cross-references**: principle.md "Structural imagination
phase"; CLAUDE.md Step 0.5 (Phase-entry debt read) + Step 1
(Structural imagination trigger); debt rows D-027 / D-029 /
D-031 / D-032 / D-034 / D-035 / D-036.
