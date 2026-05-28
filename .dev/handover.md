# Session handover

> ≤ 100 lines. Driving doc; framing per
> [`.claude/rules/handover_framing.md`](../.claude/rules/handover_framing.md).

## Resume contract

- **HEAD**: ≈ `ecb24013` (Phase 14 rows 14.0-14.4 closed + 14.5/14.6/
  14.7 refined impl plans; D-014a/D-079/D-097 Discharged this session;
  D-101..D-107 minted Active. See `git log` for exact HEAD).
- **First commit on resume MUST be**: a focused **row 14.5 (D-014b
  ex-info `:type` + catch dispatch)** implementation cycle. D-014b's
  refined barrier carries the concrete 5-piece file-level plan
  (`node.zig` CatchTarget union + analyzer relax + tree_walk keyword
  arm + vm/compiler VM-DEFER marker + Layer-2 e2e). ~80 LOC.
  Alternative pivot if the next owner prefers: row 14.6 (D-099 user
  defmacro, ~200 LOC; analyzer + macro_dispatch user-fn fallback)
  or row 14.7 (D-098 ns directive surface, ~250 LOC; analyzer
  filter accumulator + libspec + opcode + env extension). Each
  refined debt row carries its own seam-level impl plan.
- **Forbidden this session**: pulling the v0.1.0 release tag (row
  14.14) forward without all 14.5-14.13 closed. Re-opening row 14.4
  (D-014a) — fully Discharged this session at `dc141ef9`.

## Cold-start reading order

handover → CLAUDE.md (§ Project spirit + § Autonomous Workflow +
§ The only stop) → `.dev/project_facts.md` (F-001..F-009; F-005
numeric-tower JVM surface still governs follow-up arithmetic bugs
like D-107) → `.dev/principle.md` → `.dev/ROADMAP.md` §9.16
(rows 14.0-14.4 [x], 14.5+ [ ]) → `.dev/debt.md` Phase-14-entry
debts (refined barriers with seam-level plans: D-014b / D-099 /
D-098; latent: D-066 / D-100 / D-102 / D-104 / D-105 / D-106 /
D-107 / D-036 / D-037 / D-038 + F-008).

## Current state

Phase 14 (v0.1.0 milestone) IN-PROGRESS on `cw-from-scratch`. Phase
13 closed DONE at `797cb1a`. Gate green at HEAD: Mac 76/76 +
OrbStack Ubuntu x86_64 75/75.

This session: full Phase 12→13 boundary + Phase 13 open-to-close
(ADR-0010 a3 + ADR-0047 with DA forks; Ref/deref + peephole +
fib(25) 110%-verified) + Phase 13→14 boundary + Phase 14 rows
14.0-14.4 closed:
- 14.0 Step 0.5 sweep (6 Discharged + 7 Opportunistic + 3 promoted)
- 14.1 D-079 installAll aggregator + Pattern.zig retrofit
- 14.2 D-097 second-wave (Matcher / BigDecimal / 3 time surfaces)
- 14.3 D-097 third-wave (Socket / MessageDigest)
- 14.4 **D-014a fully Discharged** — 3 numeric tower gaps closed:
  BigDecimal printer (f9085e6) + Ratio literal parser (8c9a258) +
  Long→BigInt overflow promotion (dc141ef9).

D-107 minted: Ratio × Integer arithmetic bug (NotAnInteger from
`(* 1/3 6)`) — separate cross-type concern, NOT part of D-014a.

## Active task — §9.16 row 14.5 (D-014b catch-by-`:type`)

Probe surfaced precise gaps; D-014b's refined barrier names the
5-piece discharge anchor: `CatchTarget` union + analyzer accept
keyword + TreeWalk `(:type (ex-data))` arm + VM-DEFER marker per
ADR-0036 + Layer-2 e2e. Row 14.6 (defmacro) and row 14.7 (ns
directive) similarly carry refined impl plans — pick whichever the
next focused cycle judges the strongest v0.1.0 lever.

## Guardrail refresh history

Phase 13→14 boundary (2026-05-28): §9.16 expanded inline (15 rows);
D-082 → Discharged table; D-008/D-017/D-026/D-030/D-069/D-070
Discharged + D-022/D-023/D-024/D-025/D-033/D-045/D-048 Opportunistic
+ D-014a/D-014b/D-079 promoted. Phase 13 landmarks (2026-05-28):
ADR-0010 a3 + ADR-0047 minted; D-014c/D-014d/D-027/D-029/D-040/
D-079/D-097/D-014a Discharged; D-101..D-107 minted Active.
