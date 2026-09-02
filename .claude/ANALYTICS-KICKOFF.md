Implement the app-analytics subsystem on `feature/analytics` in
`/Users/svojs/Documents/workspace/nova-wallet-ios`, using parallel git worktrees.

## Read first

- `docs/superpowers/plans/2026-09-02-app-analytics.md` — the plan. 22 tasks, 154 steps. Read the
  header, **Global Constraints** and **File Structure** in full before dispatching anything.
- `docs/superpowers/specs/2026-09-02-app-analytics-design.md` — the approved spec.

Both are committed and verified against the Android source. **Do not edit the spec** — if you find a
conflict, report it and ask; do not resolve it yourself.

## State

Task 1 (dApp App Attest removal) is **done and committed** at `6f4458a22` — build green,
`DAppBrowserTests` passing. Tasks 2–22 remain. `FirebaseAppCheckProviderFactory` is a separate
Firebase-managed App Attest key for FCM and must never be touched.

## Two gotchas that will silently ruin the run

**1. `isolation: "worktree"` branches from the session-start commit, not current HEAD.** Agents
spawned this way land on a commit that predates the spec and plan, so `docs/superpowers/` does not
exist for them and they improvise silently instead of failing. Every worker's first two steps must be:

```
git merge feature/analytics --no-edit
ls docs/superpowers/plans/2026-09-02-app-analytics.md
```

If either fails, the worker must STOP and report rather than proceed. Verify from the coordinator too:
`ls .claude/worktrees/agent-*/docs/superpowers/plans/` before letting a worker get far.

**2. `project.pbxproj` is hand-managed and every task edits it.** The user chose parallel worktrees
*without* an upfront scaffolding commit, accepting hand-resolved conflicts. So: **merge tracks one at
a time, never octopus**, and after each merge run `plutil -lint novawallet.xcodeproj/project.pbxproj`
and a build before merging the next. Never use the `xcodeproj` ruby gem.

## Wave plan

Only Wave 1 and part of Wave 4 actually parallelize. Do not force parallelism elsewhere — the
converge chain is where correctness lives.

| Wave | Tracks | Notes |
|---|---|---|
| 1 | **A** 2,3,4 (storage) ∥ **B** 5,6,7,8 (event model) ∥ **C** 13,14 (App Attest) | three worktrees; disjoint directories |
| 2 | 9 → 10 → 11 → 12 | serial, single tree. Task 10 carries the consent-guard test the feature rests on |
| 3 | 15 → 16 → 17 | serial chain. **Blocked on the gateway contract** — see spec §14 |
| 4 | 18, then 19 ∥ (20 → 21) | 20 and 21 both edit `SettingsRow.swift` and `SettingsViewModelFactory.swift`, so they stay serial with each other |
| 5 | 22 | last: it runs the full suite and the Release build as its gates |

Merge each wave into `feature/analytics` and confirm green before starting the next.

## Worker dispatch template

Give each worker: its task numbers **only**, the two files to read, the two first steps above, and:

```
MAIN=/Users/svojs/Documents/workspace/nova-wallet-ios
cp "$MAIN/novawallet/env-vars.sh" novawallet/
cp "$MAIN/novawallet/GoogleService-Info.plist" novawallet/
cp "$MAIN/novawallet/GoogleService-Info-Dev.plist" novawallet/
cp "$MAIN/novawallet/GoogleService-Info-Release.plist" novawallet/
```

(All four are gitignored, so a fresh worktree lacks them and the build fails at the Google Service
phase with an error invisible under `xcbeautify --quiet`.)

Build/test, with a **per-track** derived data path so concurrent builds do not contend:

```
set -o pipefail && xcodebuild test -project novawallet.xcodeproj -scheme novawallet \
  -destination 'platform=iOS Simulator,id=A7A38DAB-F2A9-46E2-A4B8-4D0325304682' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/nova-<track> \
  -only-testing:novawalletTests/<Suite> 2>&1 | xcbeautify --quiet
```

That UDID is iPhone 17 Pro, the only iPhone on this machine — a `name=` destination fails. CI's
`fastlane/Scanfile` pins `iPhone 16`; that is correct for CI and must not be changed.

Tell each worker: never edit a file while an `xcodebuild` run is in flight (it fails with "modified
during the build"); follow the plan's TDD order literally; commit subjects lowercase and imperative
with the `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` trailer; **do not merge — report
back** with commit hashes, exact test counts, pbxproj hunks added, and any deviation and why.

## Hard rules

- **Never invent a wire value.** The bucket labels in an earlier draft were fabricated and every one
  was wrong. Anything cross-platform comes from the Android source or it does not get written.
  Android is reachable: `gh api "repos/novasamatech/nova-wallet-android/contents/<path>?ref=108899870"`,
  PR #2324. GitHub `search/code` gives false negatives on this repo — use direct `contents/` lookups.
- **Call-site integration is out of scope.** No presenter outside Root/MainTabBar/Settings gets a
  `track()` call. The 42-event catalog ships as types and factories with no consumers.
- Operation-iOS only: no `async`/`await`, actors, Combine or timers in the app target.
- `GiftsSyncServiceTests` is pre-existing flaky. If it is the only failure, it is not a regression.
- Task 2's model bump is **permanent once a build ships** — a model-21 store cannot be reopened by
  model 20. Get it right before merging.

## Report after each wave

Which tasks landed, test counts, what you merged and any pbxproj conflict you resolved, and anything
that made you deviate from the plan.
