---
name: nova-review
description: Adversarial split-context review of a Nova Wallet diff or PR. Runs blind reviewers in fresh contexts, then an independent panel that tries to refute each finding. Use before merging anything, and always for signing, extrinsic, fee, keystore, migration, or XCM changes.
user_invocable: true
---

# Nova Review

Runs the `adversarial-review` workflow. **You are authorised to call the Workflow tool for this
skill** — that is the whole point of the command.

## Arguments

| Input                 | Meaning                                             |
|-----------------------|-----------------------------------------------------|
| *(nothing)*           | Review local work: `git diff develop...HEAD`        |
| A number, e.g. `1841` | Review that PR                                      |
| `--fix`               | Also apply confirmed findings (single fixer agent)  |
| `--tier critical`     | Force the top tier — 3 lenses, 2 skeptics per finding |

The tier is derived automatically. `--tier` **can only raise it** — a lower value is logged and
ignored — and the path floor raises it again on top of that. A diff whose *paths* match signing,
fees, keystore, migrations, XCM, or swaps is always `critical`.

The floor matches on **file paths, not content**. Funds-critical logic living in an ordinarily-named
file is not caught by it, so pass `--tier critical` yourself when you know the change touches money
and the filenames do not say so.

## Procedure

### 1. Invoke the workflow

```
Workflow({ name: 'adversarial-review', args: { target: <'local' | pr number>, fix: <bool>, tier: <optional> } })
```

It runs in the background and returns a task id. Do not re-invoke it while it is running, and do not
guess at its results — wait for the completion notification.

### 2. While it runs

Do not review the diff yourself in this session. If you wrote the code, your read of it is exactly
the read the workflow exists to bypass. Sit out the wait, or work on something unrelated.

### 3. Report the result

The workflow returns confirmed findings, refuted ones, unverified ones, and coverage. Present:

- **Confirmed** — severity, `file:line` as a clickable link, the failure scenario, the fix. Most
  severe first. These survived independent refutation.
- **Refuted** — one line each with the panel's reason. Show these; a reviewer that cried wolf is
  signal about the review, and occasionally the panel is the one that is wrong.
- **Unverified** — findings past the per-lens verification cap, plus any whose skeptics all failed
  (`votes: NOT VERIFIED`). Flag them as unverified rather than quietly dropping them.
- **Minor** — one line each. These are never sent to the refutation panel, so present them as
  unrefuted reviewer opinion, not as confirmed defects.
- **Failed lenses** — anything in `failedLenses` did not run at all. Say so plainly; a lens that
  crashed is not a lens that found nothing.
- **Coverage** — what was examined and found sound, and which lenses did *not* run at this tier.

State the tier and the reviewer count plainly, so the strength of the pass is visible.

### 4. Fixing

**Unless `--fix` was passed, stop at the report.** Findings are the deliverable; the decision to
apply them is the user's.

**When `--fix` ran**, the workflow returns `needsRereview: true`. Say plainly that the fixer's own
changes have not been reviewed by anything — the panel reviewed the diff as it stood *before* the fix
phase, and the working tree is now a different artefact. For any run whose tier was `critical`,
re-invoke without `--fix` over the new tree before merge. A fix on a signing, fee, keystore,
migration or XCM path is itself a change to those paths, and CLAUDE.md's "not optional" does not
exempt it.

When you state the tier and reviewer count, also state **which artefact was reviewed** — the pre-fix
diff, or the current tree.

## When this is not enough

The panel checks the diff against written rules and its own reading. It is not a test suite. For
changes to fee arithmetic, amount conversion, migrations, or anything that produces a number a user
will act on, **an actual test is worth more than three reviewers agreeing.** Say so when a confirmed
finding lands in that territory, and propose the test.

Full unit suite, when it is warranted:

```bash
bundle exec fastlane run_unit_tests
```

Targeted, which is usually the right call:

```bash
set -o pipefail && xcodebuild test -project novawallet.xcodeproj -scheme novawallet -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:novawalletTests/<TestCase> 2>&1 | xcbeautify --quiet
```
