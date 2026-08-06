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

`.claude/SPEC.md` must exist and must be one the human has **approved**. Ask. A spec that reached
`clean` is not the same as a spec that was accepted, and planning an unapproved spec wastes the whole
phase.

```bash
ls -la .claude/SPEC.md .claude/PLAN.md && head -8 .claude/SPEC.md
```

If `.claude/PLAN.md` exists, show it and ask before clearing. `TaskList` and delete leftover
`plan:`/`plan rN:` tasks from an earlier run — a stale task with the wrong `blockedBy` will wedge the
loop, and the round tasks are the ones that accumulate. Append a new section to
`.claude/REVIEW-LOG.md` for this phase rather than overwriting the spec phase's record.

**Record the spec's hash.** The plan is only valid against the spec it was written from, and nothing
else in this framework notices if that changes underneath it:

```bash
shasum -a 256 .claude/SPEC.md | cut -d' ' -f1
```

Keep it. Re-check it at the start of every round. If it has changed mid-flight, halt the phase and
tell the human — a plan half-written against two different specs is worse than either.

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
KIND: ASSIGNMENT. Read ONLY .claude/PLAN.md when it appears — do not open .claude/SPEC.md, and do not go looking for
design rationale anywhere. You are simulating an executor with no context. Do no preparatory reading
at all: it would give you context the executor does not have. Stop now and wait to be resumed.` })
```

`plan-exec`'s isolation is load-bearing — it is the only check that the plan stands on its own. Its
prompt deliberately gives it no prep work. If you leak spec context into it, in a prompt or a relay
or an answer, you have destroyed that check.

## 3. Relay

Same rules as `/nova-spec`. `KIND: QUESTION` → `AskUserQuestion` → answer back verbatim.
`KIND: ESCALATION` → surface as a decision with its cost. Status is never a message.

If `plan-exec` asks you something only `SPEC.md` answers, that is **a finding, not a question**. Send
it back and say so.

The escalation that matters in this phase is **"the spec is wrong"**. Do not let the planner route
around it — that is a decision for the human, and the honest answer is often another `/nova-spec`
round rather than a plan that quietly exceeds its spec.

## 4. Run the rounds

When T1 completes, send all three reviewers a `KIND: ASSIGNMENT` naming their task id. A round closes
when all three review tasks are `completed`; read each verdict off its **task subject**, which the
reviewer rewrites as it completes (`plan r1: review — executability [clean]`). Metadata is write-only
in this harness and returns nothing — never read state from it.

- **Every subject reads `[clean]`** → step 5½.
- **Otherwise** → `TaskCreate` `plan rN: resolve findings` (owner `planner`, blocked by the three
  review tasks) and the next round's three review tasks (blocked by it). Message the planner, then
  the reviewers when it closes. Nobody is re-spawned.

Log each closed round to `.claude/REVIEW-LOG.md` from the task subjects and the findings you saw go by.

## 5. Escalate

**Round cap.** Round 3 closed with anything open → `TaskStop` all four teammates by name, present
each open finding with both positions, get the human's decision, re-spawn `planner` with it, run one
confirmation round, then stop regardless.

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

The team has converged. Commission two **fresh** reads of the final plan — two, because
`executability` needs a reader that has never seen `SPEC.md` and the other lenses need one that has,
and no single agent can be both. Spawn both **unnamed** so neither is a teammate, in one message:

```
Agent({ subagent_type: 'nova-cold-reader',
        description: 'independent read: fidelity + correctness',
        run_in_background: false,
        prompt: `Review .claude/PLAN.md. Your lenses are \`spec-fidelity\` and
\`codebase-correctness\`; the criteria are in .claude/docs/process/review-lenses.md. You may read
.claude/SPEC.md and the Nova Wallet source.` })

Agent({ subagent_type: 'nova-cold-reader',
        description: 'independent read: executability',
        run_in_background: false,
        prompt: `Review .claude/PLAN.md under the \`executability\` lens; the criteria are in
.claude/docs/process/review-lenses.md. Your reading list is .claude/PLAN.md and that file only —
not .claude/SPEC.md, not the source, not anything else. Anything you need that the plan does not
contain is a finding.` })
```

Those are the entire prompts. **Give them nothing else** — no round history, no "three reviewers
already signed this off", no expectation of how much they should find.

**Nothing found from both** → say so at the gate.

**Findings** → not a round, not a silent reopen. Take them to the human: `blocking` as an
`AskUserQuestion` (one repair round, or accept knowingly); `major` under its own gate heading.

A cold `executability` finding carries particular weight: it means the plan does not stand on its
own, and the team's own `plan-exec` had drifted into knowing things the executor will not.

Append both results to `.claude/REVIEW-LOG.md`.

## 6. The gate

All three clean and the cold pass reported. `TaskStop` anything still running, confirm no task is
left open, then present:

```
## Plan ready for your review — <feature>

[.claude/PLAN.md](.claude/PLAN.md) · <N> tasks · clean after <N> rounds

**Coverage:** every FR/NFR/edge case in SPEC maps to a task — or: <the exceptions, and why>
**Files:** X created, Y modified. Peer files included: <Protocols, ViewFactory, Cuckoo, strings, migration>
**Verification:** <N> tasks verify by build, <N> by targeted test, <N> by hand
**Riskiest task:** <which, and why — the one to read first>

**Independent read:** both readers clean — neither saw the argument
                     — or: <what they found, and what you decided>

**Survived review:** <findings the planner refuted, and on what grounds — one line each>
**Changed in review:** <findings it accepted — one line each>
**Spec gaps found while planning:** <anything worth feeding back into SPEC.md, or: none>
**Still open:** <escalations, or: none>

Next step is yours.
```

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
