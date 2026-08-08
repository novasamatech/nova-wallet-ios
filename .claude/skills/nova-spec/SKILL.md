---
name: nova-spec
description: Design a Nova Wallet feature into .claude/SPEC.md with an agent team. An Opus architect runs discovery, interrogates the requirements with you, and writes the spec; two adversarial reviewers attack it and argue with the architect directly until it holds. Ends at a hard gate for your manual review — it never proceeds to planning.
user_invocable: true
---

# Nova Spec

You are the **team lead**. You do not design, review, or write `SPEC.md`. You own the shared task
list, you relay what only you can relay, and you halt the team when it stops converging.

**You are authorised to call the Agent tool for this skill** — that is the whole point of the
command. Read [.claude/docs/process/design-loop.md](../../docs/process/design-loop.md) first; it is
the protocol every teammate here is following, and the two-channel rule below comes from it.

## Arguments

Everything after the command is the feature request, verbatim. Pass it through unmodified — your
paraphrase is a lossy layer between the human and the architect. If nothing was passed, ask what to
design before spawning anything.

**`--amend "<defect>"`** runs the loop against an existing, previously-approved `.claude/SPEC.md`
instead of writing one from scratch. `/nova-plan` sends people here when a plan-phase finding turns
out to be about the spec. Differences from a normal run, and only these:

- Skip the "clear the artefacts" half of §1 **and its approved-unexecuted-plan guard**. `SPEC.md` is
  the input, not stale state; `PLAN.md` and the plan-phase tasks stay exactly where they are. That
  guard exists to stop a *fresh* run deleting the contracts an approved plan depends on — an
  amendment is the sanctioned way to change them, so it does not apply here.
- Task subjects are `amend:` / `amend rN:` rather than `spec:` / `spec rN:`.
- The architect's task is *this defect*, not the whole spec. It skips Stage 1 discovery except where
  the defect needs it, and it must not redesign sections the defect does not reach — an amendment
  that rewrites §6 invalidates a plan that was only ever wrong about §3.
- Reviewers are scoped: "review the sections that changed, plus anything that cites them." They still
  read the whole document — a contradiction lives across a boundary — but findings on untouched
  sections are out of scope and must be reported to the human rather than argued.
- Same per-lens 3-round cap, same independent read at §5½, same gate.

**Amending a spec written before contracts moved to their own file.** If `.claude/SPEC.md` exists
and `.claude/CONTRACTS.md` does not, the spec predates the split and must be migrated before any
plan can be built from it — `/nova-plan` halts on the missing file. Say so to the architect as part
of the defect, and hold it to two things:

- `CONTRACTS.md` must **stand alone**. Every `§N` reference that survives into it is a defect, not a
  convenience: `plan-exec`, the cold `executability` reader and the executor get that file and never
  `SPEC.md`, so a contract that says "see §7.1" is a dead end for the only readers who matter. The
  binding rule is **moved** into the contract, not pointed at and not copied.
- Nothing else changes. A migration that also improves a requirement is no longer a migration, and
  the human cannot tell the two apart in the diff. If the architect finds a real defect while
  moving text, it escalates rather than fixing it in passing.

After the gate, tell the human plainly that `PLAN.md` was written against the *previous* spec and
`/nova-plan` must re-run before the plan is trustworthy.

## Your job, precisely

| Do | Do not |
|----|--------|
| Create and sequence tasks on the shared list | Answer the architect's questions yourself |
| Relay `TO: main` messages to the human, and answers back | Ferry findings, rebuttals, or revisions |
| Read round state off `TaskList` subjects | Ask teammates for status — it is on the list |
| Log each round to `.claude/REVIEW-LOG.md` | Form an opinion on the design |
| `TaskStop` the team at the cap | Let a fourth round exist |
| Render the diagram and present the gate | Invoke the planner |

**Two channels.** State lives on the task list; content moves by `SendMessage`. The teammates argue
with each other directly — that argument is the product, and staying out of it is your contribution
to it.

## 1. Preflight

```bash
ls -la .claude/SPEC.md .claude/CONTRACTS.md .claude/PLAN.md .claude/design.excalidraw.json .claude/REVIEW-LOG.md 2>/dev/null
```

If any exist, they belong to a previous feature. Show the human what is there and ask before
clearing — a stale `SPEC.md` silently merged with a new one is the worst outcome available. Only one
design is in flight at a time.

**On a fresh run, if `.claude/PLAN.md` exists, stop and ask explicitly whether it has been
implemented.** A plan resolves its contracts through `.claude/CONTRACTS.md` at execution time, so
clearing the artefacts invalidates any approved-but-unexecuted plan — the signatures it was written
against simply disappear, and the executor's hash check will halt on the next attempt. Do not clear
until the human says that plan is abandoned or already built. (`--amend` skips this: it preserves
`PLAN.md` by design.)

Call `TaskList`. Delete leftover `spec:`/`spec rN:` tasks from an earlier run; a stale task with the
wrong `blockedBy` will wedge the loop. Start `.claude/REVIEW-LOG.md` with the request verbatim.

Confirm the artefacts are ignored — the diff-stage guarantee depends on it, and a missing entry here
surfaces three stages later as a silently contaminated review:

```bash
git check-ignore -q .claude/SPEC.md .claude/CONTRACTS.md .claude/PLAN.md .claude/REVIEW-LOG.md .claude/design.excalidraw.json && echo ok
```

If that does not print `ok`, add the missing paths **to `.git/info/exclude`**, not only to
`.gitignore`. `.gitignore` lives on a branch: a worktree cut from `origin/develop` does not carry
it, and the artefacts then sit there untracked-and-not-ignored where an ordinary `git add -A`
commits them into a branch `/nova-review` must abort on. `.git/info/exclude` is per-repository and
every worktree inherits it. Both files should carry the paths; the check above is what tells you
whether they do, here, on this branch.

## 2. Seed the list, then spawn the roster

Tasks first — a teammate that spawns into an empty list has nothing to claim.

```
TaskCreate({ subject: 'spec: write SPEC.md',
             description: '<the human request, verbatim>',
             activeForm: 'Writing SPEC.md' })                                   → T1

TaskCreate({ subject: 'spec r1: review — contract',  description: '…' })        → T2
TaskCreate({ subject: 'spec r1: review — reality',   description: '…' })        → T3

TaskUpdate({ taskId: T1, owner: 'architect' })
TaskUpdate({ taskId: T2, owner: 'spec-contract', addBlockedBy: [T1] })
TaskUpdate({ taskId: T3, owner: 'spec-reality',  addBlockedBy: [T1] })
```

`blockedBy` here is **documentation for you**, not enforcement: this harness never prunes a
completed blocker, so `TaskGet` will keep reporting `Blocked by: #T1` forever. Nothing starts because
a dependency cleared. Work starts when you send `KIND: ASSIGNMENT`, and only then.

Then spawn all three teammates **in one message** so they start concurrently:

```
Agent({ name: 'architect', subagent_type: 'nova-architect',
        description: 'design <feature>',
        prompt: `<the human's request, verbatim>

You are the teammate \`architect\`. Task ${T1} is yours — start now. Follow your agent definition:
write .claude/SPEC.md and nothing else. The mermaid diagram in §6.1 is yours; I derive the Excalidraw
rendering from it at the gate, because MCP tools are not reachable from your allowlist.

Questions for the human go TO: main with KIND: QUESTION, one at a time — I relay them and send the
answer back. I will not answer on the human's behalf.

Complete task ${T1} when the draft is ready; I then assign \`spec-contract\` and \`spec-reality\`,
who will message you directly.` })

Agent({ name: 'spec-contract', subagent_type: 'nova-spec-reviewer',
        description: 'spec review: contract',
        prompt: `Your lens is \`contract\`. Task ${T2} is yours; it is blocked until the architect
publishes SPEC.md — do not start it until I send you a KIND: ASSIGNMENT.

While waiting, do your preparatory reading — the checklists and the docs your lens names — then
stop. Do not poll the task list; I will resume you when the spec exists.

The feature under design, in the human's words: <request, verbatim>` })

Agent({ name: 'spec-reality', subagent_type: 'nova-spec-reviewer',
        description: 'spec review: reality',
        prompt: `Your lens is \`reality\`. Task ${T3} is yours; it is blocked until the architect
publishes SPEC.md — do not start it until I send you a KIND: ASSIGNMENT.

While waiting, read the architecture docs and the source for the areas this touches — you are the
only reviewer who verifies claims against code, and that reading is worth doing early. Then stop;
do not poll. I will resume you when the spec exists.

The feature under design, in the human's words: <request, verbatim>` })
```

They run in the background. Do not poll them, and do not start reviewing the spec yourself.

## 3. Relay

When a message arrives `TO: main`:

- **`KIND: QUESTION`** — if the architect supplied enumerable options, relay them with
  `AskUserQuestion` verbatim, keeping its framing. If it did not — and it is explicitly licensed to
  ask open questions — put the question to the human as **plain text, verbatim**. Do not manufacture
  options to fit the tool; inventing the choices is inventing the framing you were told not to add.
  Either way send the answer back with `SendMessage({ to: 'architect', … })` unedited, including any
  free text.
- **`KIND: ESCALATION`** — surface it as a decision, not a status update. Say what each option costs.

Anything addressed to another teammate is not yours — it is already rendered for the human, and
re-quoting it is noise. Anything that is merely a status should not have been a message at all; if a
teammate sends you one, log it and remind them it belongs on the task list.

## 4. Run the rounds

When T1 completes, resume both reviewers:

```
SendMessage({ to: 'spec-contract', summary: 'round 1 unblocked',
              message: 'TO: spec-contract\nFROM: main\nROUND: 1\nKIND: ASSIGNMENT\n\n
                        .claude/SPEC.md is published. Task <T2> is yours — start now. Send findings
                        to `architect`; close the task by rewriting its subject with your verdict.' })
```

…and the same for `spec-reality`. Then observe. Findings go to the architect, the architect rebuts
and revises, the reviewers answer and re-read.

**A round closes** when every review task **you assigned** for that round is `completed` — not every
task that exists, since lenses now retire and revive independently. One `TaskList` shows you the
whole round — each reviewer rewrites its task subject to carry the verdict as it completes:

```
spec r1: review — contract  [open 0B/2M/1m]     [completed]
spec r1: review — reality   [clean]             [completed]
```

Read the verdict off the **subject**. Do not look in `metadata` — it is write-only in this harness
and returns nothing, which is why the protocol does not use it.

**A round converges when nothing above `minor` is open** — every subject `[clean]`, or `[open …]`
with only minors in it. Minors do not buy another pass over the whole spec; they ride to the gate
under `Minor, unfixed` and the human decides. See
[design-loop.md](../../docs/process/design-loop.md) §Round accounting.

- **Converged** → go to step 5½.
- **Otherwise** → create the next round:

```
TaskCreate({ subject: 'spec r1: resolve findings', … })  → T4, owner architect, blockedBy [T2, T3]
```

**That is the only task you create now.** Which lenses round 2 needs is decided by a changelog that
does not exist until T4 closes, so creating `spec r2: review — …` here means creating a task you may
never assign — and a `pending` task nobody owns is exactly what the gate's "confirm no task is left
open" cannot be satisfied with. Create a review task when you are about to assign it, not before.

`SendMessage` the architect that T4 is open. When T4 closes, `TaskGet` it for the changelog, then
create and assign one review task per in-scope lens. Nobody is re-spawned — names survive
completion, and a send resumes a teammate with its context intact.

**Assign only the lens the revision is in scope for.** The architect writes a `## Changed in rN`
table naming every section it touched into the `description` of its resolve-findings task — `TaskGet`
it. It is deliberately not in `SPEC.md`: the cold reader at step 5½ must not be able to tell which
sections were argued over.

**Always re-assign the lens that raised a finding this revision answers**, whatever it touched — it
is the only party that can judge whether its own finding was met. Beyond that, a reviewer that
closed `[clean]` and whose sections have not changed is not re-assigned; create its next-round task
only if the changelog puts something in its scope, and say which lens you dropped and why when you
log the round.

**The scopes are the section ownership in [review-lenses.md](../../docs/process/review-lenses.md),
and nothing else — do not paraphrase them from memory:**

| Lens | Owns |
|------|------|
| `contract` | §2 Scope, §3 FR, §4 NFR, `CONTRACTS.md`, §10 Verification, §11 Open Questions — and traceability across the whole document |
| `reality` | §1 Problem, §6 High-Level Design, §7 Low-Level Design, §8 Edge Cases, §9 Migration — and every factual claim about existing code, anywhere |

Between them these cover every section. If a revision touches something you cannot place in either
row, that is a defect in this table, not a licence to assign nobody — assign both and say so. The
same goes for a missing or untrusted changelog: an unreliable changelog is worse than none.

Append each closed round to `.claude/REVIEW-LOG.md` from the task metadata: findings per lens,
accepted, rebutted, conceded.

## 5. Escalate

Two triggers. Both mean the same thing: the team will not settle this, so stop spending rounds.

**Round cap — three *assigned* rounds per lens.** Lenses retire and revive independently, so count
the `spec rN: review — <lens>` tasks owned by that lens rather than looking for a global round
number. When a lens closes its third assigned round with anything **above `minor`** open — open
minors go to the gate and never trigger this — before assigning it a fourth:

1. `TaskStop` each teammate by name — `architect`, `spec-contract`, `spec-reality`.
2. Present to the human: each open finding, the architect's position, the reviewer's position, and
   what each choice implies. `AskUserQuestion` where it is genuinely a choice between two designs;
   plain text where the human just needs to read and decide.
3. Re-spawn `architect` with the decision, run **one** confirmation round, then stop regardless. If
   that does not close it, hand over the spec as it stands with the open items marked.

**Deadlock.** A reviewer reports holding the same finding twice against the same rebuttal — escalate
that finding immediately without waiting for the cap. Two identical exchanges are all the
information that pair will produce. The rest of the round continues.

Never resolve an escalation yourself. You have no more claim on the answer than the two teammates
that could not agree.

## 5½. Independent first read

**Stand the architect down first.** Convergence can carry open minors, and the architect must not be
editing while the cold reader reads or while the human is at the gate — both must see the document
the reviewers signed off. Send `architect` a `KIND: ASSIGNMENT` reading "no further edits to
`SPEC.md` or `CONTRACTS.md`", confirm nothing is in flight, and only then spawn the reader. If you
want a minor fixed first, open a `spec rN: minor repairs` task and stand the architect down after it
closes.

The team has converged. Before the gate, commission one **fresh** read of the final spec from an
agent that has none of the history:

```
Agent({ subagent_type: 'nova-cold-reader',
        description: 'independent read of the spec',
        run_in_background: false,
        prompt: `Review .claude/SPEC.md and .claude/CONTRACTS.md. Your lenses are \`contract\` and
\`reality\`; the criteria are in .claude/docs/process/review-lenses.md.` })
```

That is the entire prompt. **Give it nothing else** — not that anyone else reviewed this, not what
they concluded, not that it converged, not how many rounds it took, not that you expect it to find
little. Every one of those anchors it toward "this has been checked", which is the failure this read
exists to catch. It is spawned without a `name` so it is not a teammate, and `nova-cold-reader` is a
separate definition precisely so it never loads the protocol doc or the round vocabulary.

**Nothing found** → say so at the gate.

**Findings** → this is not a round, it does not count against the cap, and you do not reopen the loop
on your own authority:

- **blocking** — `AskUserQuestion`: spend one repair round (assign `architect` a fresh task with the
  finding, then re-run this read once), or accept it knowingly and proceed. An independent reader
  contradicting a converged team is exactly what wants the human's judgement.
- **major** — present it in the gate under its own heading.

**Log the result under a structural heading, always — including when it found nothing.** The cold
pass is the most expensive terminal spend in the framework and its yield has never once been
recorded, which is exactly why nobody can judge whether it could be narrowed. A trailing sentence in
prose does not count:

```markdown
## Independent read — spec

| Reader | Lenses | Findings | Severity | Would the team's own lenses have caught it? |
|--------|--------|----------|----------|---------------------------------------------|
| cold   | contract, reality | 0 | — | — |
```

Zero findings is the most useful row this table can have, and the one most likely to go unwritten.

## 6. The gate

Converged — nothing above `minor` open — and the cold pass reported.

1. **Render the diagram.** The architect wrote mermaid into SPEC §6.1 and could not author the
   Excalidraw form — MCP tools are not reachable from its allowlist, and JSON written blind does not
   render. You have them. Find the connector with
   `ToolSearch({ query: "excalidraw diagram elements", max_results: 3 })`, call its `read_me` for the
   element format, translate §6.1 node-for-node and edge-for-edge, save the elements array to
   `.claude/design.excalidraw.json`, and pass it to `create_view`. Translate — do not redesign; if
   §6.1 is too vague to translate, that is a finding for the architect, not licence to invent.
   If the connector is unavailable, say so and point at §6.1.
2. **Retire the roster.** `TaskStop` any teammate still running, and confirm no task is left open.
3. **Present the gate**, briefly — the human reads `SPEC.md` itself:

```
## Spec ready for your review — <feature>

[.claude/SPEC.md](.claude/SPEC.md) · risk tier: <tier> · <N> lines · converged after <N> rounds

**Requirements:** X functional, Y non-functional
**Contracts:** N new, M modified
**Edge cases:** N, covering <domains>

**Independent read:** clean — a reader that never saw the argument found nothing
                     — or: <what it found, and what you decided>

**Survived review:** <findings the architect refuted, and on what grounds — one line each>
**Changed in review:** <findings it accepted — one line each>

**Minor, unfixed:** <every open minor, one line each — none warranted a round.
                    Say "fix these" for one repair pass; otherwise they stand.>
                    — or: none

**Assumptions you should check:** <SPEC §11>
**Still open:** <anything escalated and unresolved, or: none>
**Review economy:** <N> rounds · lenses assigned: r1 <n> / r2 <n> / r3 <n>

Next step is yours. When the spec is approved, run /nova-plan.
```

4. **Stop.** Do not invoke `/nova-plan`, do not spawn a planner, do not start implementing, and do
   not offer to. The gate exists because a spec that reads well to three agents can still be the
   wrong feature, and you are not positioned to notice that.

## If something goes wrong

| Symptom | What to do |
|---------|-----------|
| A teammate dies or returns nothing | Its task is still on the list with an owner. Re-spawn under the same name, pointing at the task id. Do not continue with fewer lenses without saying which one went missing. |
| The loop stalls with everything blocked | A task was never completed. `TaskList` shows which; `SendMessage` its owner, or complete it yourself if the teammate is gone and re-open the round. |
| A teammate sends status instead of updating its task | Log it, remind it once. If it keeps happening, its round state is unreliable — say so at the gate rather than trusting the metadata. |
| Teammates cannot message each other | Fall back to ferrying findings and rebuttals through yourself, verbatim, no commentary. Slower and noisier; the loop still works. Say that you have fallen back. |
| The architect starts writing source files | Stop it. It writes `SPEC.md` only. |
| A teammate reports `blockedBy` never clears | Correct — it never does. Tell it to start; the `ASSIGNMENT` message is the go-signal, not the dependency. |
| A reviewer edits `SPEC.md` | Revert that edit and re-run its lens on the restored file. A reviewer that fixed the document did not review it. |
| The human asks what you think of the design | Answer as a reader, and say plainly that you have not reviewed it and are not the referee. |
