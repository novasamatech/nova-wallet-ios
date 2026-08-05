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

The tier is derived automatically and can only be raised, never lowered, by the path floor in the
workflow script. A diff touching signing, fees, keystore, migrations, XCM, or swaps is always
`critical` regardless of what anything else says.

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
- **Unverified** — findings past the per-lens verification cap. Flag them as unverified rather than
  quietly dropping them.
- **Coverage** — what was examined and found sound, and which lenses did *not* run at this tier.

State the tier and the reviewer count plainly, so the strength of the pass is visible.

### 4. Do not auto-fix without being asked

Unless `--fix` was passed, stop at the report. Findings are the deliverable; the decision to apply
them is the user's.

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
