# The Design Loop — Team Protocol

How the spec and plan agents coordinate as an **agent team**. Every teammate in `/nova-spec` and
`/nova-plan` reads this file before doing anything else.

Two phases, each ending at a **hard human gate**:

```
requirements ──▶ /nova-spec  ──▶ .claude/SPEC.md ──▶ [ YOU review ] ──┐
                                                                      │
              ┌───────────────────────────────────────────────────────┘
              ▼
           /nova-plan ──▶ .claude/PLAN.md ──▶ [ YOU review ] ──▶ implementation
```

`/nova-spec` never invokes the planner. `/nova-plan` never invokes an implementer. The gates are the
point of the framework; a teammate that walks through one has failed regardless of output quality.

## The team

The session has one implicit team. Any agent spawned with a `name` is a teammate: addressable by
that name through `SendMessage`, stoppable by that name through `TaskStop`, and able to own tasks on
the shared list.

The **orchestrator** is the main session. It is the team lead and the only party that can reach the
human. It does not design, review, or write the artefact.

Names are fixed constants, so every agent definition can hardcode who it talks to.

| Phase | Teammate           | Definition            | Model / effort | Writes             |
|-------|--------------------|-----------------------|----------------|--------------------|
| spec  | `architect`        | `nova-architect`      | opus / max     | `SPEC.md`, diagram |
| spec  | `spec-contract`    | `nova-spec-reviewer`  | opus / high    | nothing            |
| spec  | `spec-reality`     | `nova-spec-reviewer`  | opus / high    | nothing            |
| plan  | `planner`          | `nova-planner`        | opus / max     | `PLAN.md`          |
| plan  | `plan-fidelity`    | `nova-plan-reviewer`  | opus / high    | nothing            |
| plan  | `plan-correctness` | `nova-plan-reviewer`  | opus / high    | nothing            |
| plan  | `plan-exec`        | `nova-plan-reviewer`  | opus / high    | nothing            |

Reviewers are **read-only on the artefact**. Only `architect` writes `SPEC.md`; only `planner` writes
`PLAN.md`. A reviewer that edits the document under review has destroyed the review.

## Files

Flat, one design in flight at a time.

| Path                             | Owner        | Contents                                  |
|----------------------------------|--------------|-------------------------------------------|
| `.claude/SPEC.md`                | `architect`  | The behavioural contract                  |
| `.claude/design.excalidraw.json` | `architect`  | Excalidraw elements for the §6.1 diagram  |
| `.claude/PLAN.md`                | `planner`    | The implementation plan                   |
| `.claude/REVIEW-LOG.md`          | orchestrator | Append-only record of every round         |

Starting a new feature means clearing all four.

**These four files are never committed.** They are listed in `.gitignore`, and that entry is not
optional bookkeeping — it is what makes the contamination rule below enforceable. Committed on a
feature branch, they arrive inside `git diff develop...HEAD` and `gh pr diff` as added-file body
text, which means the diff reviewer receives the entire spec, plan, and round-by-round argument
inside a command it was ordered to run. There is no `Read` for it to decline.

**Contamination rule.** `nova-adversarial-reviewer` — the agent that reviews the finished *diff* —
must never read any of these. Its value comes from not having the author's reasoning, and `SPEC.md`
is that reasoning written down and argued into looking correct.

The rule is enforced in three places, and all three are required because any one of them can be
bypassed by an ordinary mistake:

1. `.gitignore` keeps them out of the branch.
2. Every diff command in the framework carries `-- . ':(exclude).claude/'`, so an artefact that was
   committed anyway (a `git add -f`, a pre-existing tracked copy) still does not reach a reviewer.
3. `/nova-review` asserts on the fetched diff before spawning anyone, and **aborts loudly** if a
   design artefact appears in it.

Layer 3 is the one that matters most. Layers 1 and 2 prevent the failure; layer 3 is what stops it
failing *silently*, which is the difference between a bug and a false guarantee.

## Two channels, and what belongs in each

This is the rule that keeps the loop legible. Getting it wrong is how a team turns into a group chat.

| Channel | Carries | Never carries |
|---------|---------|---------------|
| **Task list** (`TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet`) | State: who is doing what, and whether a round closed clean | Findings, argument, prose |
| **`SendMessage`** | Content: findings, rebuttals, concessions, questions | Status pings, "done", "starting now", structured JSON progress |

If you are about to send a message whose whole payload is a status, stop — it is a `TaskUpdate`.
If you are about to put a findings list in a task description, stop — it is a `SendMessage`.

## The task list is the state machine

The orchestrator owns the list. Teammates claim, work, and complete; they do not create tasks.

### Two harness facts this protocol is built around

Both were reproduced against the live tools. Design against them; do not design against what the
tool descriptions imply.

**Task metadata is write-only.** `TaskCreate`/`TaskUpdate` accept a `metadata` object and neither
`TaskGet` nor `TaskList` returns it. Anything written there is unreadable by anyone, including its
author. **No part of this protocol may depend on metadata.**

**`blockedBy` is never pruned.** Completing a blocker does not remove it from the blocked task;
`TaskGet` still reports `Blocked by: #N` after `#N` is `completed`. So "wait until `blockedBy` is
empty" is a condition that never becomes true, and a teammate gating on it would never start.
`blockedBy` is **display only** — it documents intent for a human reading `TaskList`, and it
enforces nothing.

### The verdict rides in the subject

Because metadata cannot be read back, a round's outcome goes in the task **subject**, which
`TaskList` does return. One `TaskList` call gives the orchestrator the whole round:

```
spec: write SPEC.md                              [completed]
spec r1: review — contract  [open 0B/2M/1m]      [completed]
spec r1: review — reality   [clean]              [completed]
spec r1: resolve findings                        [in_progress]
spec r2: review — contract                       [pending]
```

A reviewer closing a round calls `TaskUpdate` with **both** a rewritten `subject` carrying its
verdict and `status: 'completed'`. The verdict suffix is `[clean]` or `[open <n>B/<n>M/<n>m]`,
counting blocking, major and minor. Detail that will not fit goes in `description`, which `TaskGet`
does return — never in `metadata`.

### Starting work

A teammate starts when **the orchestrator tells it to**, not when it observes state. The go-signal
is a `KIND: ASSIGNMENT` message naming the task id. There is no polling and no self-dispatch:

**Do not poll.** After completing your task, stop. Do not loop on `TaskList` waiting for work; that
burns the budget on nothing. Names survive completion, so the orchestrator resumes you with a
`SendMessage` when the next round's task exists.

## Message envelope

Plain text output is invisible to other agents. All content traffic goes through `SendMessage`, and
every message opens with:

```
TO: <name> | main
FROM: <name>
ROUND: <n>
KIND: ASSIGNMENT | FINDINGS | REBUTTAL | REVISION | CONCESSION | QUESTION | ESCALATION
```

There is deliberately no `VERDICT` kind. A round's outcome is the task subject, not a message.

Routing:

- **Teammate → teammate** — `SendMessage({ to: "architect", … })`. This is where the argument
  happens: reviewers talk to the author directly, not through the orchestrator.
- **Teammate → human** — impossible. Send `TO: main` with `KIND: QUESTION` or `KIND: ESCALATION`.
  The orchestrator relays those two kinds and nothing else.
- **Orchestrator → teammate** — `KIND: ASSIGNMENT` to start a task (naming its id), or the human's
  answer to a relayed question. `ASSIGNMENT` is the only go-signal; a teammate that has not received
  one has no work, regardless of what the task list says.

**Deadlock is reported on both channels.** A reviewer holding a finding for the second time against
the same rebuttal tells the author on the peer channel *and* sends `TO: main` with
`KIND: ESCALATION`. The orchestrator does not read peer traffic for control decisions, so a deadlock
declared only to the author never reaches the party whose job it is to escalate it.

**The legacy `plan_approval_request` handshake is not used here.** It is a boolean plus a feedback
string; a review round is a severity-ranked list of findings, each of which can be accepted,
rebutted, or conceded independently. Do not collapse a round into an approve/reject.

## Round accounting

A **round** is one complete review pass over the current version of the artefact.

```
round n:  every reviewer reviews vN            → FINDINGS to the author; task closed [clean] or [open …]
          author answers every finding          → REBUTTAL (contested) + REVISION (accepted)
          reviewer answers every rebuttal       → CONCESSION, or the finding is held
          author publishes v(N+1)               → orchestrator opens round n+1 with ASSIGNMENTs
```

**Convergence** is every reviewer's task for the current round completed with `[clean]` in its
subject. Reviewers must re-read the artefact before recording that — a verdict based on the author's
description of the fix is not a review.

**The cap is 3 rounds.** The orchestrator reads the round count off the task list; there is no
counter to maintain. If round 3 closes with any finding open, the orchestrator halts the team with
`TaskStop` before round 4 exists, and escalates to the human with the open disagreements laid out.
Three failed rounds means the disagreement is about intent, not correctness, and no further agent
cycles will settle it.

**Deadlock escalation.** A single finding the author has rebutted twice and the reviewer has held
twice is escalated immediately, without waiting for the cap. Two identical exchanges are the whole of
the information that pair will produce. The rest of the round continues.

## After convergence

Convergence closes the team's work; it does not close the phase. What happens next is the
orchestrator's business and is specified in the skills — deliberately not here, because everything
in this file is read by teammates, and the step that follows convergence only works if the agent
performing it has read none of this.

## Arguing well

The author is expected to push back. A rebuttal is legitimate when:

- The scenario is unreachable given a requirement or constraint the document already states —
  **quote the line**.
- The reviewer misread the document — quote what it actually says.
- It is explicitly out of scope, and the document says so in its scope section.
- It is a preference with no observable difference in behaviour.
- The proposed change would not alter the outcome.

A rebuttal is **not** legitimate when it rests on:

- "Unlikely in practice." Reachable-but-rare still counts. This is a wallet.
- "The implementation will handle it." If it is not in the contract, it is not guaranteed.
- "The planner/implementer will figure it out." That is the gap being reported.
- Rewording the same claim more confidently.

A reviewer receiving a rebuttal answers `CONCESSION` (with what convinced it) or holds it (with the
specific thing the rebuttal failed to address). Silence is not a concession, and neither is moving on
to a different finding.

## Findings must be falsifiable

A finding must name a **concrete failure** — inputs, and the wrong result they produce. For documents
rather than code, that failure takes one of these shapes. A finding fitting none of them is a
preference; drop it silently.

| Shape           | What must be shown                                                                   |
|-----------------|---------------------------------------------------------------------------------------|
| `ambiguity`     | Two conforming implementations, A and B, that differ in observable behaviour            |
| `gap`           | A specific input or state the document does not answer for                              |
| `contradiction` | Two lines that cannot both hold — quote both                                            |
| `ungrounded`    | A type, API, or field that does not exist or has a different shape — cite `file:line`   |
| `unverifiable`  | A requirement with no criterion an agent could check                                    |
| `infeasible`    | A conflict with a stated architectural constraint — cite the doc                        |

Zero findings is a valid and useful outcome. Record `verdict: "clean"` and say so plainly; a long
list of soft findings buries the one that mattered.

## Severity

| Severity   | Meaning                                                                          |
|------------|-----------------------------------------------------------------------------------|
| `blocking` | Following the document as written produces loss of funds, key exposure, data loss, a wrong signed payload, or a wrong amount. Also: a contract so ambiguous that a reasonable implementation gets one of those wrong. |
| `major`    | Missing requirement, unhandled edge case on a critical path, architectural conflict, incomplete feature-area coverage, missing migration. |
| `minor`    | Traceability, naming, structure — real but with no behavioural consequence.        |

When torn between two, take the higher and say why in one clause.
