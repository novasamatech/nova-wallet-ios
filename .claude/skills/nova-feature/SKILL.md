---
name: nova-feature
description: End-to-end flow for a non-trivial Nova Wallet change — scope with the user, plan against the architecture docs, implement, then hand the diff to a blind adversarial review before it is called done. Use for new features and for extending existing ones.
user_invocable: true
---

# Nova Feature

Four stages: **Scope → Plan → Implement → Review.** The human is in the loop for the first two. The
last one deliberately is not run by the session that wrote the code.

Do not skip to implementation because the change "looks small". Small changes to a wallet are how
funds move.

## Stage 1 — Scope (with the user)

Before proposing anything, resolve the questions whose answers change the work. Ask only these; make
the ordinary calls yourself.

- Which feature areas does this touch? Staking has four flavours (relaychain, pools, parachain,
  Mythos), governance has two versions. Is this all of them, or one with a stated reason?
- New VIPER module, or a change inside an existing one?
- Does it touch a submission path? If so: which call, whose fee, which validators.
- Does it need a CoreData schema change, a new setting, or a keystore change?
- Delegated wallets (proxy, multisig, watch-only) — in scope or explicitly not?

Read the routed docs from `CLAUDE.md` for every area involved *before* proposing a design. Do not
design from memory of the codebase.

## Stage 2 — Plan

Write `.claude/PLAN.md`:

```markdown
# <change>

## Goal
One paragraph. What behaviour changes, from the user's point of view.

## Approach
The mechanism. Which layers, which existing types, which seams. Name the alternative you
rejected and why — that line is what makes the plan reviewable.

## files_touched
- path — what changes and why

## peer_files
Protocols.swift, ViewFactory, Cuckoo mocks, tests, localization — whichever the change implies.

## must_not_touch
## out_of_scope
## risk_tier
critical | standard | low — critical if it touches signing, extrinsics, fees, keystore,
migrations, XCM, swaps, or delegated-wallet resolution.

## verification
How we will know it works. Name the tests. If the answer is "by hand", say so — that is a
finding in itself, not a plan.
```

Show the plan and get agreement before writing code. If the answer to `verification` is only "build
and click through it", say plainly that the change will ship without a referee, and propose the test
that would give it one.

## Stage 3 — Implement

Follow the plan. Stay inside `files_touched` plus the peer files it implies; if the plan turns out
to be wrong, stop and say so rather than quietly widening scope.

Conventions that are not negotiable here — all of them are in `.claude/docs/`, read the relevant one
rather than working from memory:

- Operation-iOS `CompoundOperationWrapper` from a `*OperationFactory`. **No async/await, no actors,
  no new Combine.**
- `CancellableCallStore` for anything the user can re-trigger; cancelled on teardown.
- `[weak self]` in every operation callback; Presenter callbacks marshalled to `.main`.
- No force unwraps. No `try?` or `?? 0` that turns a failure into a number.
- Every user-visible string localized via `R.string(preferredLanguages:)`.
- New service registered in `ServiceCoordinator` with **both** `setup()` and `throttle()`.
- Schema change ships a model version, an enum case, `nextVersion`, and a migration test.

Never stub a body with `TODO` and move on. If you find yourself writing a paragraph justifying why a
piece is left incomplete, that is the signal the code is wrong — fix it properly or stop and raise
the blocker.

Build before handing off:

```bash
set -o pipefail && xcodebuild -project novawallet.xcodeproj -scheme novawallet -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | xcbeautify --quiet
```

Then run the tests the plan named. Targeted, not the full suite.

## Stage 4 — Review (not by you)

**Do not review your own diff in this session.** You have the reasoning that produced it, and that
reasoning is what made any bug in it feel correct while you were writing it. A self-review here
produces confidence, not coverage.

Invoke the review workflow instead — **you are authorised to call the Workflow tool for this skill**:

```
Workflow({ name: 'adversarial-review', args: { target: 'local', tier: <risk_tier from PLAN.md> } })
```

Reviewers run in fresh contexts, fetch the diff themselves, and never read `.claude/PLAN.md`.

When it returns, present the confirmed findings and stop. Applying them is the user's call, and a
second `/nova-review` pass after fixes is cheap compared to what it checks.

## Stage 5 — Close out

Once findings are resolved, note anything the work revealed that the docs do not yet cover:

- A non-obvious constraint you hit.
- A correction the user made to your approach.
- A checklist rule that would have caught a confirmed finding earlier.

Propose the specific doc or checklist edit. The checklists in `.claude/docs/review/` are the only
oracle this codebase has for most changes — every rule added there makes every future review sharper.
