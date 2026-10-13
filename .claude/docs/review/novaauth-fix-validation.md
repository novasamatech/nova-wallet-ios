# NovaAuth client fixes and validation

13 October 2026 · `feature/nova-auth` · local commits only.

The client remains profile 3 only, with one NovaAuth owner and one current bearer shared by
analytics and Bittensor. Both existing POST routes are unchanged. Server authorization and
pre-handler token rejection belong to the separately owned backend migration.

## Lean test suite

After the main-thread stall fix and the dead-code removal, the feature's tests were reduced to
the key scenarios. They now add 629 test lines instead of about 8,200. NovaAuth keeps 12 tests
that run the real client, bootstrap factory and settings identity store against one fake server.
NovaAnalytics passes 45 tests, two of them for offline opt-in parking and withdrawal. The 24
feature-related app classes pass 142 tests, including the stall test, a delayed-invalidation cache
test, refused-registration and offline flow tests and a Max-APY termination test. Each kept key
test failed with its fix reverted and passed after restoration: invalid-token replay, user-only
refused registration, the two-recreation budget, the attestation age guard, both cooldown scopes,
exchange release, offline consent parking and withdrawal, the non-blocking availability read,
the cache revision guard, the refused-attestation and offline error mappings and Max-APY
termination. Test counts and test-specific claims in the sections below describe the earlier,
larger suite.

## Round 3 corrections

- Max-APY authentication-wide refusals, final token denial and local auth configuration/support
  failures terminate the walk with the original error. They do not skip a target, schedule an
  outer retry, or memoize nil/partial success. Existing route/data skips and transient retries stay.
- A genuine opt-in whose endpoint cannot resolve remains pending until successful endpoint
  adoption. Readiness is separate from invalidation; it wakes only unresolved pending work.
  Invalidation wins, including cold origin replacement. Withdrawal and deactivation discard it.
- Every genuine opt-in gets its first attempt. Only automatic admission-cooldown re-arms spend
  the two-retry launch budget. They respect the full cooldown; uploads remain background.
- Independent review found a delayed-invalidation race in the new facade callback delivery.
  The implementer confirmed it and a separate fixer added immutable invalidation revisions
  to Bittensor admissions and cache fencing. A delayed callback no longer retires a newer
  active generation, while old admissions/completions remain rejected.
- Removed the added `settingsCommit` API and second synchronize call. Settings writes still
  validate, write and check cached read-back before key generation. This does not establish
  durable persistence or detect every refused disk write. An undetected failed reservation can
  be lost on relaunch; the cross-launch budget depends on ordinary settings persistence.
- Removed tests of the fictitious production commit acknowledgement, added presenter tests,
  redundant private-marker/enum permutations and constructor echoes. Existing test adaptations
  are separated from optional new coverage. Retained tests use bounded waits and safe unwraps.
- The native-call age test now checks 39 → 40.001 seconds; exactly 40 remains allowed.
- README and diagram source links are repository-relative, and the offline HTML is regenerated
  from the same Markdown describing the final client.

These corrections supersede the round-2 validation claims that a second synchronize call
acknowledged persistence, that a three-second resolution retry fully recovered offline consent,
and that skipping an auth-refused Max-APY target was correct. The earlier reviewers missed these.

The earlier core fixes remain: exchange terminal release, user-only registration refusal and
abandonment recovery, two non-user replacement reservations, independent recreation/policy/proof
ladders, same-key eligible Apple deferral, native invocation age guard, and denial/cooldown before
throwing token deletion. Boot change ends delays but does not reset the stored recreation count.
A usable bearer is served before recovery waits; business send gates still enforce cooldowns.

After an origin change, consent-on analytics-only installations remain stopped
until a real Bittensor action or a later consent off/on cycle. An opt-in whose own first endpoint
resolution performs a cold replacement is discarded too. This preserves the approved D3 boundary.

## Current verification

Final source: `db2cfe255`. Source plus retained optional tests: `db4196133`.
The executed final snapshot `d3883b8d3` has an identical Git tree; only the test-commit split changed.
The isolated final snapshot matched all 6,814 tracked Swift source/test files in the working
checkout before execution. All tests used the iOS simulator, serial execution, `RUN_IN_CI=true`
and enabled execution timeouts (60 seconds default, 90 seconds maximum).

| Check | Result |
| --- | --- |
| NovaAuth package | 258 passed, 0 failed |
| NovaAnalytics package | 56 passed, 0 failed |
| Focused cache/facade/factory/Max-APY classes after the separate fix | 52 passed, 0 failed |
| Full app unit suite on the final snapshot | 1,388 passed, 0 failed |
| Optional-test-omitted package suites | NovaAuth 153 and NovaAnalytics 53 passed; NovaAuth also passes all 141 original tests with the earlier standalone exchange test changes omitted |
| Optional-test-omitted app build and suite | Build passed; 1,374 ran with only the known gift-status failure |
| Independent review | No surviving actionable findings after implementer discussion and separate fixer |
| Formatting/lint | Pinned SwiftFormat passed for 34 changed files and 27 adaptation copies; lint has no errors |
| Offline diagrams | Nine views rendered; navigation, zoom/fit, SVG export, print visibility and script checks passed |

The optional-test-omitted snapshot is `f8fed36e9`. Required changes to existing tests live in
that explicit adaptation commit. `dc9adcbb5` and `db4196133` contain the optional additions and
can be omitted without breaking compilation. The earlier standalone exchange-lifetime test
commit remains separate. The old unpublished test/doc suffix is preserved on the local backup
branch `codex/nova-auth-before-round3`; no branch was pushed.

The first omission run used `e03fb1961`. Refining the split only preserved the already-separate
exchange-cancellation test improvement in its original commit; the final source/test tree is
unchanged. The refined omission snapshot `f8fed36e9` was rechecked with all 153 NovaAuth tests,
and then with the earlier standalone exchange-test changes removed too (141 passed). Its app,
analytics and all production source files are byte-identical to the first omission snapshot,
so the 53-test analytics and 1,374-test app results apply to that same code. The two additional
package logs are `novaauth-round3-required-auth-refined.log` and
`novaauth-round3-all-optional-auth-omitted.log`.

The omission run's sole failure was
`GiftsSyncServiceTests.testStatusTrackerDelegate_StatusDetermined_DoesNotUpdateWhenStatusSame`.
Both its test and production source match `14567daae`. It passed in the final full run; that
success does not establish that the pre-existing flake is fixed. Gift behavior was not changed.

Fresh Astra Extra High agents performed research, planning, implementation and independent
reviews. The B/C review cleared the Max-APY and settings changes. The consent reviewer found
that moving generic callbacks outside the facade lock exposed the cache's mutable-generation
cutoff. The implementer confirmed the concrete interleaving; a separate fresh fixer implemented
the revision contract and two bounded production-flow regressions. A fresh independent reviewer
cleared that fix. Builds and execution results above were then collected independently of agents.

All five isolated reverted-fix checks failed their intended assertions and passed after restoration:

| Disabled behavior | Regression scenarios | Restored result |
| --- | --- | --- |
| Native invocation bound at 40 seconds | Queued age 39 → 40.001 | 1 passed |
| Initial consent attempts exempt from retry budget | Deliberate actions after two automatic re-arms | 1 passed |
| Max-APY termination on auth failures | Root refusal, alpha conflict, final token denial | 3 passed |
| Offline consent parking | Failed initial resolution followed by successful endpoint adoption | 1 passed |
| Revision-aware cache invalidation | Delayed origin change and delayed reset | 2 passed |

Failures were bounded assertion failures, not compiler failures, crashes or hangs. All temporary
mutations were confined to isolated copies, and all changed files were restored byte-for-byte.
The working branch was never mutated for these checks. Local evidence is in the
`novaauth-round3-*-mutated.log` and `novaauth-round3-*-restored.log` files under `/private/tmp`.

SwiftLint reports one nonblocking file-length warning (405 lines in
`BittensorApiOperationFactory.swift`) and the repository's existing invalid `nesting.statement_level`
configuration warning. There are no remaining settings-commit API references in source/tests,
no added presenter scenarios, and no machine-local paths in the README or diagram source links.
All 92 relative links in those two Markdown documents resolve. The revised diagrams were also
visually inspected, including storage, recovery, registration, Bittensor and analytics flows.

Reproduce normal suites using the simulator commands in [build and tooling](../code/build-and-tooling.md).
This round's local logs are named `novaauth-round3-auth-verified.log`,
`novaauth-round3-analytics-verified.log`, `novaauth-round3-app-verified.log`,
`novaauth-round3-fixer-focused.log`, and `novaauth-round3-required-*.log` under `/private/tmp`.
The source and test commit IDs above identify the reproducible snapshots.

## Historical evidence and remaining boundaries

At `b1e9bb365`, the round-2 suites passed 299 NovaAuth tests, 83 analytics tests and 124 focused
app tests. The full unit run executed 1,433 tests with one failure in
`GiftsSyncServiceTests.testStatusTrackerDelegate_StatusDetermined_DoesNotUpdateWhenStatusSame`.
An isolated three-iteration gift run passed that test twice and failed once. Its live queue-count
assertion is timing-dependent; gift source/tests are outside this task and remain unchanged.
Claude independently confirmed 299/83 package tests and 113 selected app tests on its frozen
snapshot, with seven reverted fixes detected. This is not evidence of a green full app suite.
Historical round-2 logs are under `/private/tmp/novaauth-round2-v2-*`.

Simulator tests use controlled Apple, network and storage implementations. They cannot establish
successful signed-device App Attest, deployed POST authorization or physical persistence behavior.
The server must reject `invalid_token` before either POST reaches its business handler to permit
the client's one replay without duplicate effects. There is no profile-2 fallback.

Ordinary issuance Retry-After remains in memory. If Apple never delivers a callback, the native
key lease remains busy until restart. Exact `kern.boottime` comparison retains its
calendar-correction limitation. A cooldown may defer the original opt-in's user intent for its full remaining duration;
this round does not introduce an intent expiry or shorten a cooldown to issue early.
