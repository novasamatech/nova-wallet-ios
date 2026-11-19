# Commits & Jira Tasks

Jira links a commit to a task only when the task key (`NW-1234`) is in the commit message, the
branch name or the pull request. Work without a key is invisible on the task. Every commit you
write must either carry the key of the task it belongs to, or be a deliberate "no task" commit
that the developer confirmed.

This doc decides what goes into a commit message. It does not authorize committing: commit only
when the developer asked for it.

## Finding the Task

Before the first commit of a piece of work, decide which task it belongs to. Use the first source
that gives an answer:

1. The developer named a task in this conversation (a key, a Jira link, "this is for NW-1234").
2. The branch name contains a key (`fix/nw-2511-network-chips`).
3. Otherwise ask the developer once: "Is there an NW task for these changes?" Offer three
   answers: a key, "no task", or "several tasks" (then ask which change belongs to which).

Do not take the key from earlier commits on the branch: long feature branches carry work for many
tasks. Do not guess a key from a similar-sounding task, and do not invent one. If a Jira tool is
available, read the task and show its summary so the developer can confirm it is the right one;
if it is not available, use the key as given.

Remember the answer for the rest of the session: do not ask again for follow-up commits on the
same piece of work. Ask again when the work moves to a different bug or feature.

## Writing the Commit

- Put the key first in the subject line, then the usual lowercase subject:
  `NW-2511 toggle token select network chips and allow several at once`
- One commit, one task. If a change covers two tasks, split it into two commits. Only when it
  cannot be split, list both keys: `NW-2510 NW-2511 ...`.
- "No task" confirmed by the developer: commit without a key and do not add a placeholder. If the
  change fixes a bug nobody filed, say so once, so the developer can decide whether it needs a
  ticket.
- Never add Jira smart-commit commands (`#close`, `#comment`, `#time`, or any `#word` after a
  key): they change the ticket.
- Do not amend, reword or rebase existing commits to add a key unless the developer asks.

No key and no question for: merge commits, localization pulls, version bumps, dependency bumps
and CI-only changes.

## Branches and Pull Requests

- A new branch for a task carries its key after the prefix: `fix/nw-2511-network-chips`,
  `feature/nw-2452-swap-screen`.
- A pull request names every task it covers: the key in the title when there is one task, a list
  of keys in the description when there are several.
