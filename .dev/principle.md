# ClojureWasm v1 — Principles

> The project's working principles in one short file. It does not
> duplicate ROADMAP / ADR / CLAUDE.md. When plan and implementation
> conflict, this file wins; the others should be edited to match.
> Detail lives elsewhere; this file holds only fuzzy premises so it
> does not become a checklist.

## Premises

- **Reason backwards from the finished shape**. Judge today's choice
  by how it will look in the finished form. Ask "how will this part
  read when the project is done?" and pick the choice that fits
  that view.
- **The plan is a means; the finished form is the end**. ROADMAP /
  ADR / rule are tools for reaching the finished form. When the
  tool distorts the finished form, fix the plan side. Ad-hoc
  workarounds that bend the finished form are forbidden.
- **Follow the Bad Smell**. Mid-implementation "wait, this feels
  off" is a signal. Do not suppress it; you have the latitude to
  stop and look.
- **Latitude and discipline coexist**. Without latitude you can't
  be creative; without discipline you don't reach the finished
  form. Hold both.

## Bad Smell catalogue

Smells that surface during implementation. The list is a memory
aid, not a checklist. Stop on any of these — and on others that
fit the same shape:

- **TODO smell** — wanting to leave a "fix this later" comment in
  the code.
- **Magic constant smell** — "100 for now", "1024 should be fine".
- **Branch sprawl smell** — stacking `if` / `else` three or more
  levels deep.
- **Stub smell** — a do-nothing implementation that lets you feel
  "it works".
- **Spec drift smell** — ROADMAP / ADR text and the implementation
  seem to disagree.
- **Cascade smell** — fixing one file forces touching five others.
- **Resignation smell** — settling for "it can't be helped" or
  "the JVM does it this way too".
- **Premature commitment smell** — the implementation path is
  already settled before the test is written.
- **Test skip smell** — leaning on "I'll write this test in a
  later Phase".
- **Doc drift smell** — implementation changed but ROADMAP /
  handover has not.
- **Shortcut smell** — the proper path looks costly, so a side
  route looks attractive.
- **Workaround smell** — "if I can dodge this point, I can keep
  moving".
- **Smallest-diff bias smell** — picking the smallest-diff option
  *because it is smallest*, rather than because it lands at the
  finished form. The project's premise is "the finished form
  wins"; ROADMAP P5 ("smallest diff first") is a tie-breaker, not
  a veto. If the smallest-diff choice would be re-done later
  anyway, take the bigger surgery now and keep the finished form
  in place.
- **Reservation-as-bias smell** — treating a "reserved" slot /
  number / name as a hard constraint when it was only a memo. ADR
  numbers, NaN-box slots, debt rows that say "future X is
  reserved" — none of these are promises to obey. If the reservation
  blocks the cleanest landing, edit the reservation and take the
  number.
- **Progress-pressure smell** — the autonomous loop's forward
  momentum encouraging "I'll fix this later" / "let me push and
  move on" / "the next task is waiting". Forward momentum is a
  feature, but it must not bypass depth-3 / depth-4 surgery when
  the smell calls for it. "Let me finish 4.X first and come back"
  rarely comes back.

The catalogue is not exhaustive. Any felt smell counts.

## When the smell triggers

The procedure is fuzzy; the writer chooses:

1. Pause for a while. Re-read the related ADR / ROADMAP /
   surrounding implementation.
2. Fork a subagent if a deeper look is warranted.
3. Imagine how this will look in the finished form.
4. Pick a depth and act.

## Four depths of revision

| Depth          | Situation                                   | Where the conclusion lives                                            |
|----------------|---------------------------------------------|-----------------------------------------------------------------------|
| 1. Local fix   | One file, no ADR cross-reference            | commit message                                                        |
| 2. ADR amend   | Wording of an existing ADR needs adjustment | ADR Revision history                                                  |
| 3. ADR cascade | Several ADRs need amending together         | New ADR amendment + Affected files entries                            |
| 4. Big rewrite | ROADMAP-scale redesign                      | New ADR (`Supersedes NNNN`) + old surface moved to `private/archive/` |

Choosing the depth is the writer's call. The four levels are not a
flow chart.

**All four depths proceed within the autonomous loop.** Depth 2-4
land their conclusion (ADR amendment / new ADR / archive move) in
a separate commit before the source commit, then the loop
continues. The AI drafts and accepts the ADR itself — there is no
external review gate. See CLAUDE.md § Autonomous Workflow
"ADR-level designs are handled inline, not as a stop".

## Three questions to picture the finished form

When you stop, ask:

1. How will this read when the project is done?
2. Which later Phase actually feels the effect of this choice?
3. If I patch it lightly now, what does the redesign cost look like
   later?

## How this file is maintained

- Keep it short. Detail belongs in ROADMAP / ADR / rules.
- If another file (ROADMAP / ADR / CLAUDE.md / rule) contradicts
  this one, edit the **other** file. This file is the meta layer.
- Edits to this file ride a normal commit, but they must pass the
  same Bad Smell self-audit that the principle prescribes.
