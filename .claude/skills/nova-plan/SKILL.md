---
name: nova-plan
description: Turn an approved .claude/SPEC.md into .claude/PLAN.md with an agent team. An Opus planner writes ready-to-paste tasks; three adversarial reviewers attack them on spec fidelity, codebase correctness, and executability, and argue with the planner directly. Ends at a hard gate for your manual review — it never proceeds to implementation.
user_invocable: true
---

# Nova Plan

You are the **team lead**. You do not plan, review, or write `PLAN.md`. You own the shared task list,
you relay what only you can relay, and you halt the team when it stops converging.

**You are authorised to call the Agent tool for this skill.** Read
[.claude/docs/process/design-loop.md](../../docs/process/design-loop.md) first — it is the protocol
every teammate here follows. This is the same machine as `/nova-spec` with a different cast; the
differences are in steps 1, 2, 4 and 6.

## Arguments

Usually none — the input is `.claude/SPEC.md`. Anything passed is a constraint on the plan
(`"split it into two PRs"`, `"skip the Mythos flavour"`) and is forwarded to the planner verbatim.

## 1. Preflight

`.claude/SPEC.md` **and `.claude/CONTRACTS.md`** must both exist, and the spec must be one the human
has **approved**. Ask. A spec that reached `clean` is not the same as a spec that was accepted, and
planning an unapproved spec wastes the whole phase. A missing `CONTRACTS.md` means the spec phase
did not finish — the plan cites contracts from that file and `plan-exec` reads nothing else, so
halt rather than planning against SPEC §5.

```bash
ls -la .claude/SPEC.md .claude/CONTRACTS.md .claude/PLAN.md && head -8 .claude/SPEC.md
```

If `.claude/PLAN.md` exists, show it and ask before clearing. `TaskList` and delete leftover
`plan:`/`plan rN:` tasks from an earlier run — a stale task with the wrong `blockedBy` will wedge the
loop, and the round tasks are the ones that accumulate. Append a new section to
`.claude/REVIEW-LOG.md` for this phase rather than overwriting the spec phase's record.

**Record both hashes.** The plan is only valid against the documents it was written from, and
nothing else in this framework notices if either changes underneath it:

```bash
shasum -a 256 .claude/SPEC.md .claude/CONTRACTS.md
```

Keep them. Re-check at the start of every round; halt and tell the human if either moved mid-flight
— a plan half-written against two different specs is worse than either. The `CONTRACTS.md` hash also
goes into the plan header, where the executor re-checks it before Task 1: the artefacts are
single-slot and gitignored, so a plan approved today can find different contracts under that path
next week.

## 2. Seed the list, then spawn the roster

```
TaskCreate({ subject: 'plan: write PLAN.md',
             description: 'From approved .claude/SPEC.md. <any constraints, verbatim>',
             activeForm: 'Writing PLAN.md' })                                 → T1

TaskCreate({ subject: 'plan r1: review — spec-fidelity',       … })           → T2
TaskCreate({ subject: 'plan r1: review — codebase-correctness', … })          → T3
TaskCreate({ subject: 'plan r1: review — executability',        … })          → T4

TaskUpdate({ taskId: T1, owner: 'planner' })
TaskUpdate({ taskId: T2, owner: 'plan-fidelity',    addBlockedBy: [T1] })
TaskUpdate({ taskId: T3, owner: 'plan-correctness', addBlockedBy: [T1] })
TaskUpdate({ taskId: T4, owner: 'plan-exec',        addBlockedBy: [T1] })
```

`blockedBy` is **documentation for you**, not enforcement — this harness never prunes a completed
blocker, so it reads as blocked forever. Work starts on your `KIND: ASSIGNMENT` message and nothing
else.

Then spawn all four **in one message**:

```
Agent({ name: 'planner', subagent_type: 'nova-planner', description: 'plan <feature>',
        prompt: `You are the teammate \`planner\`. Task ${T1} is yours. Write .claude/PLAN.md from
the approved .claude/SPEC.md per your agent definition — that one file, nothing else.

<any constraints the human passed, verbatim>

If the spec turns out to be wrong or under-specified once you are in the code, send TO: main with
KIND: ESCALATION rather than patching the gap in the plan. Questions go TO: main with KIND:
QUESTION, one at a time.

Complete ${T1} when the draft is ready; I then assign the three reviewers, who message you
directly.` })

Agent({ name: 'plan-fidelity', subagent_type: 'nova-plan-reviewer',
        description: 'plan review: spec fidelity',
        prompt: `Your lens is \`spec-fidelity\`. Task ${T2} is yours — do not start it until I send you a
KIND: ASSIGNMENT. While waiting, read .claude/SPEC.md and build your requirement inventory — every FR, NFR, contract
and edge case you will map in both directions. Then stop; do not poll.` })

Agent({ name: 'plan-correctness', subagent_type: 'nova-plan-reviewer',
        description: 'plan review: codebase correctness',
        prompt: `Your lens is \`codebase-correctness\`. Task ${T3} is yours — do not start it until I send
you a KIND: ASSIGNMENT. Do NOT read .claude/SPEC.md at any point. While waiting, read the code
checklist and the conventions docs. Then stop; do not poll.` })

Agent({ name: 'plan-exec', subagent_type: 'nova-plan-reviewer',
        description: 'plan review: executability',
        prompt: `Your lens is \`executability\`. Task ${T4} is yours — do not start it until I send you a
KIND: ASSIGNMENT. When it appears, read .claude/PLAN.md and .claude/CONTRACTS.md — those two whole
files, and never .claude/SPEC.md. They are exactly what the executor is handed. Do not go looking
for design rationale anywhere. You are simulating an executor with no context. Do no preparatory
reading at all: it would give you context the executor does not have. Stop now and wait to be
resumed.` })
```

`plan-exec`'s isolation is load-bearing — it is the only check that the plan stands on its own. Its
prompt deliberately gives it no prep work, and its reading list is **two file names** rather than a
section range, because a section range is not enforceable: `SPEC.md` sits under the `Read` tool's
line cap, so one ordinary call returns the entire design and nothing detects it. If you leak any
part of `SPEC.md` into this lens, in a prompt or a relay or an answer, you have destroyed the check.

## 2½. The mechanical prepass — before every review round

Reviewers are Opus at `high`, three in parallel, re-reading the plan. They are the most expensive
thing in this pipeline and the worst possible instrument for checks a script can do exactly. So
whenever `planner` completes a draft or a resolve task — **before** you send any `ASSIGNMENT`:

```bash
.claude/scripts/plan-lint.sh
```

It checks the size budget, placeholders, `Produces`/`Consumes` drift, symbols consumed that nothing
declares and no `.swift` file contains, requirement ids that appear in `SPEC.md` and nowhere in
`PLAN.md`, file-table mismatches, and tasks missing a runnable `Verify`. Then:

- **Findings** → send them verbatim to `planner` with `KIND: FINDINGS`, `FROM: plan-lint`. This is
  not a review round: no round task, no round number bump, no reviewer involvement. Wait for the
  fixed version, re-run, and only then assign the round.
- **Over the size budget** → that is the one finding you do not simply forward. A plan over 3200
  lines, or a task over 450, goes to the human as a **scope decision** before a single reviewer is
  spawned: split the plan, cut scope, or accept the review cost knowingly. Three lenses × three
  rounds over a 5000-line plan is the single largest cost this framework can incur, and it is the
  one the human should have the chance to decline.

  **If the human accepts knowingly, record the waiver and stop asking.** Re-run every subsequent
  prepass with the accepted figures so the budget check goes quiet and every other check keeps
  running:

  ```bash
  PLAN_LINE_BUDGET=4956 TASK_LINE_BUDGET=1509 .claude/scripts/plan-lint.sh
  ```

  Note the waiver under `Review economy` at the gate. The same rule applies to any lint finding the
  planner cannot fix without a decision the human has already made: forward it once, then carry the
  decision rather than re-raising it every round.
- **Clean** → assign the round.
- **`CHECK DID NOT RUN`** → treat as a finding, never as a pass. It means that check examined
  nothing: a missing `SPEC.md` or `CONTRACTS.md` (both gitignored, so both absent in a fresh
  worktree), a plan with no `## Task` headings, an empty file table. Fetch what is missing, or tell
  the reviewers in their `ASSIGNMENT` that the prepass did not run.

**Every `ASSIGNMENT` states the prepass state** — `prepass: clean` or `prepass: did not run`. The
reviewers have been told to skip the mechanical checks only on the first, and to do them by hand and
say so on the second. Never let them infer it.

If the linter reports something a reviewer later finds by hand, or a reviewer reports something the
linter should have caught, note it at the gate. The script is cheaper to fix once than to work
around every round.

## 3. Relay

Same rules as `/nova-spec`. `KIND: QUESTION` → `AskUserQuestion` → answer back verbatim.
`KIND: ESCALATION` → surface as a decision with its cost. Status is never a message.

If `plan-exec` asks you something only `SPEC.md` answers, that is **a finding, not a question**. Send
it back and say so.

The escalation that matters in this phase is **"the spec is wrong"**. Do not let the planner route
around it — that is a decision for the human, and the honest answer is often another `/nova-spec`
round rather than a plan that quietly exceeds its spec.

## 4. Run the rounds

When T1 completes and the prepass is clean, send all three reviewers a `KIND: ASSIGNMENT` naming
their task id. A round closes when every review task you assigned is `completed`; read each verdict
off its **task subject**, which the reviewer rewrites as it completes
(`plan r1: review — executability [clean]`). Metadata is write-only in this harness and returns
nothing — never read state from it.

**A round converges when nothing above `minor` is open** — `[clean]` everywhere, or `[open 0B/0M/2m]`.
Minors do not open a round; they ride to the gate under `Minor, unfixed` and the human decides. See
`design-loop.md` §Round accounting.

- **Converged** → step 5½.
- **Otherwise** → `TaskCreate` **only** `plan rN: resolve findings` (owner `planner`, blocked by the
  review tasks that found something) and message the planner. **Do not create the next round's
  review tasks yet** — which lenses are in scope is decided by a changelog that does not exist until
  the planner closes that task, and a review task you create and then never assign sits `pending`
  forever, which the gate's "confirm no task is left open" cannot be satisfied with. Create a review
  task only when you are about to assign it. Nobody is re-spawned.

When the resolve task closes:

1. `TaskGet` it and read the `## Changed in rN` changelog from its `description`.
2. Re-run `.claude/scripts/plan-lint.sh`. The planner is required to be lint-clean before closing,
   so this is a check, not a step — but it is the check that catches a planner that closed first and
   linted second, which makes the changelog wrong.
3. Create and assign one review task per in-scope lens, per the table below.

### Assign only the lenses the changes are in scope for

Round 2 and round 3 are **not** automatic re-runs of all three. When `planner` closes a resolve task
it writes a `## Changed in rN` changelog into that task's `description` — `TaskGet` it (the changelog
is deliberately not in `PLAN.md`, so the cold readers at step 5½ cannot see which tasks were argued
over). Read it and decide per lens:

**Always re-assign the lens that raised a finding this revision answers**, whatever the revision
touched. It is the only party that can judge whether its own finding was met. Beyond that:

| Lens | Re-assign when the revision touched |
|------|--------------------------------------|
| `plan-fidelity` | any **Implements** line, the Contracts table, scope, the task set, or **any test case table's `Discharges` column** — anything that changes what the plan claims to cover |
| `plan-correctness` | any Swift snippet, signature, file list, task ordering, or **any test case table's `Given`/`Expect` columns** — those are arithmetic, and arithmetic is its lens |
| `plan-exec` | any step, Verify block, Interface block, task boundary, or **any test case table row** — i.e. almost any change |

Test case tables need naming explicitly because they do not look like the things in the other rows:
a revision that only corrects an expected value is a revision to the arithmetic, and without these
entries it would re-assign nobody.

A lens that closed `[clean]`, raised no finding this revision answers, and whose scope the revision
did not touch is **not** re-assigned, and
you say so when you report the round: *"`plan-fidelity` retired clean at r1; r2 changed only snippet
bodies."* If you are genuinely unsure whether a change is in a lens's scope, assign it — the point is
to stop paying for three certain no-ops, not to gamble on one.

Re-assigning a lens costs a re-read of the changed tasks. Not re-assigning one that should have been
costs a defect reaching the gate. Both are real; the changelog is what lets you tell them apart, so
if the changelog is missing or you do not trust it, assign everyone and say why.

Log each closed round to `.claude/REVIEW-LOG.md` from the task subjects and the findings you saw go
by — including which lenses you did not assign, and on what grounds.

## 5. Escalate

**Round cap — three *assigned* rounds per lens, counted per lens.** Lenses retire and revive
independently, so there is no global round number to read; count the `plan rN: review — <lens>`
tasks owned by that lens. When a lens closes its **third assigned round** with anything above
`minor` open, `TaskStop` that lens, present its open findings with both positions, get the human's
decision, re-spawn `planner` with it, and run one confirmation round scoped to that lens. Other
lenses continue to their own third assigned round. Open minors never trigger this; they go to the
gate.

A previous run reached `plan-exec` round 5 against a documented cap of 3 because nobody was counting
anything. Count the tasks — `TaskList` shows them.

**Deadlock.** A reviewer holding the same finding twice against the same rebuttal → escalate that
finding immediately; the rest of the round continues.

**Spec defect.** Any finding whose real subject is the spec rather than the plan → escalate
immediately. Do not let it be fixed in the plan; `planner` has no licence to write `SPEC.md` and
neither do you. Present the human three options, and note what each actually costs:

| Option | What it means |
|--------|----------------|
| **Amend** | `/nova-spec --amend "<the defect>"` — re-assigns `architect` against the existing `SPEC.md` with the reviewers scoped to the changed sections. `PLAN.md` is untouched. Cheapest, and right when the defect is local. |
| **Re-run** | `/nova-spec` from scratch. Right when the defect is in the design rather than in one section. `PLAN.md` is discarded. |
| **Accept** | Proceed knowingly. The plan diverges from the spec, and the divergence is recorded in `REVIEW-LOG.md` so the diff stage is not surprised by it. |

Whichever is chosen, the spec's hash changes, so re-record it and restart the current round rather
than continuing on findings written against the old text.

Never resolve an escalation yourself.

## 5½. Independent first read

**Stand the authors down first.** Convergence can carry open minors, and the author must not be
editing the plan while the cold readers are reading it or while the human is at the gate — they have
to see the document the reviewers signed off. Send `planner` a `KIND: ASSIGNMENT` reading "no
further edits to `PLAN.md`", confirm it has nothing in flight, and only then spawn the readers. If
you want a minor fixed first, open a `plan rN: minor repairs` task, re-run the prepass when it
closes, and stand the planner down after that.

The team has converged. Commission two **fresh** reads of the final plan — two, because
`executability` needs a reader that has never seen `SPEC.md` and the other lenses need one that has,
and no single agent can be both. Spawn both **unnamed** so neither is a teammate, in one message:

```
Agent({ subagent_type: 'nova-cold-reader',
        description: 'independent read: fidelity + correctness',
        run_in_background: false,
        prompt: `Review .claude/PLAN.md. Your lenses are \`spec-fidelity\` and
\`codebase-correctness\`; the criteria are in .claude/docs/process/review-lenses.md. You may read
.claude/CONTRACTS.md, .claude/SPEC.md and the Nova Wallet source.` })

Agent({ subagent_type: 'nova-cold-reader',
        description: 'independent read: executability',
        run_in_background: false,
        prompt: `Review .claude/PLAN.md under the \`executability\` lens; the criteria are in
.claude/docs/process/review-lenses.md. Your reading list is .claude/PLAN.md and
.claude/CONTRACTS.md — those two whole files and nothing else, not .claude/SPEC.md, not the source.
Anything you need that is in neither is a finding.` })
```

That second reading list is **two files, not one**, and it must stay in step with `plan-exec`'s.
The plan deliberately does not carry its contracts; a cold reader given only `PLAN.md` would report
every contract reference as a blocking gap on every run, and the one check whose findings carry the
most weight would become the one that always cries wolf.

Those are the entire prompts. **Give them nothing else** — no round history, no "three reviewers
already signed this off", no expectation of how much they should find.

**Nothing found from both** → say so at the gate.

**Findings** → not a round, not a silent reopen. Take them to the human: `blocking` as an
`AskUserQuestion` (one repair round, or accept knowingly); `major` under its own gate heading.

A cold `executability` finding carries particular weight: it means the plan does not stand on its
own, and the team's own `plan-exec` had drifted into knowing things the executor will not.

**Log both results under a structural heading, always — including when they found nothing.** The
cold pass is the most expensive terminal spend in the framework, and its yield has never been
recorded, which is precisely why nobody can judge whether it can be narrowed. A trailing sentence in
prose does not count; write the section:

```markdown
## Independent read — plan

| Reader | Lenses | Findings | Severity | Would the team's own lenses have caught it? |
|--------|--------|----------|----------|---------------------------------------------|
| cold-A | spec-fidelity, codebase-correctness | 0 | — | — |
| cold-B | executability | 1 | major | no — plan-exec had drifted into knowing Task 6's rationale |
```

Zero findings from both is the most useful row this table can have, and the one most likely to go
unwritten. Write it.

## 6. The gate

Converged and the cold pass reported. `TaskStop` anything still running, confirm no task is left
open, then present:

```
## Plan ready for your review — <feature>

[.claude/PLAN.md](.claude/PLAN.md) · <N> tasks · <N> lines · converged after <N> rounds

**Coverage:** every FR/NFR/edge case in SPEC maps to a task — or: <the exceptions, and why>
**Files:** X created, Y modified. Peer files included: <Protocols, ViewFactory, Cuckoo, strings, migration>
**Verification:** <N> tasks verify by build, <N> by targeted test, <N> by hand
**Riskiest task:** <which, and why — the one to read first>

**Independent read:** both readers clean — neither saw the argument
                     — or: <what they found, and what you decided>

**Survived review:** <findings the planner refuted, and on what grounds — one line each>
**Changed in review:** <findings it accepted — one line each>

**Minor, unfixed:** <every open minor, one line each, read from each reviewer's closing task
                    `description` — none of these warranted a round.
                    Say "fix these" for one repair pass; otherwise they stand.>
                    — or: none
**Minor, fixed:** <anything repaired in a `minor repairs` task, or: none>
**Handoff:** the implementation session needs [.claude/PLAN.md](.claude/PLAN.md) **and**
             [.claude/CONTRACTS.md](.claude/CONTRACTS.md). Both are gitignored, so neither
             travels with a branch or into a worktree — copy them.
             Contracts pinned at `<sha256>`; starting a new /nova-spec invalidates this plan.

**Spec gaps found while planning:** <anything worth feeding back into SPEC.md, or: none>
**Still open:** <escalations, or: none>

**Review economy:** assigned rounds per lens: fidelity <n> / correctness <n> / exec <n>
                    · plan-lint caught <N> findings before any reviewer ran
                    · size waiver: <none, or the accepted figures and who accepted them>
                    · <anything a reviewer found by hand that plan-lint.sh should have caught, or: nothing>
                    · <any `CHECK DID NOT RUN` the prepass reported, or: none>

Next step is yours.
```

**Review economy** is not decoration. It is the only place you will see whether a run spent its
budget on judgement or on re-reading, and a reviewer finding that the linter should have caught is a
script fix worth making before the next feature rather than a cost paid again every round.

Then **stop**. Do not implement, do not start Task 1, do not offer to. Three agents agreeing a plan
is executable is not the same as it being the right change, and you are not positioned to tell the
difference.

If the human approves and asks to build it, that is a separate instruction and a separate session —
and when the diff exists it goes to `/nova-review`, whose reviewers must never read `SPEC.md`,
`PLAN.md`, or `REVIEW-LOG.md`.

## If something goes wrong

| Symptom | What to do |
|---------|-----------|
| A teammate dies or returns nothing | Its task is still on the list with an owner. Re-spawn under the same name pointing at the task id. Say which lens went missing rather than continuing quietly with two. |
| The loop stalls with everything blocked | A task was never completed. `TaskList` shows which; message its owner, or close it yourself if the teammate is gone and re-open the round. |
| A teammate sends status instead of updating its task | Log it, remind it once. If it repeats, its round state is unreliable — say so at the gate rather than trusting the metadata. |
| `plan-exec` was given spec context | That lens is compromised for this version. `TaskStop` it, re-spawn under a fresh name against the current plan, and discard its earlier findings. |
| A teammate reports `blockedBy` never clears | Correct — it never does. Tell it to start; the `ASSIGNMENT` message is the go-signal. |
| `SPEC.md` changed mid-phase | Halt. Re-record the hash, tell the human what changed, and restart the current round — findings written against the old text are not about this plan. |
| Teammates cannot message each other | Ferry findings and rebuttals yourself, verbatim, no commentary. Say that you have fallen back. |
| The planner starts editing source files | Stop it. It writes `PLAN.md` only. |
| A reviewer edits `PLAN.md` | Revert the edit and re-run that lens on the restored file. |
| The plan keeps growing each round | Say so. A plan that gains tasks every round is usually a spec problem wearing a plan costume — escalate it as one. |
| A revision arrives with no `## Changed in rN` changelog | Send it back before assigning anyone. Without it you cannot scope the round and every lens reads everything — one message now, or three full re-reads. |
| A changelog says "wording only" and a reviewer finds a behaviour change there | Report it to `planner` as a process defect, and assign all lenses fully for that round. An unreliable changelog is more expensive than none, because it is trusted. |
| `plan-lint.sh` fails to run | Do not skip the prepass silently — say it failed and why, then assign the round and note at the gate that the mechanical checks did not run. |
| A reviewer disputes a lint finding | The linter is textual and has no opinions, but it can be wrong. Fix the script, re-run, and note it under Review economy. Do not have `planner` work around a bad check. |
