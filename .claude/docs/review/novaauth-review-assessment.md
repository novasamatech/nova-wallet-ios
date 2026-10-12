# Independent assessment of Claude's NovaAuth review

Follow-up: the accepted client fixes and their verification are recorded in [NovaAuth fix validation](novaauth-fix-validation.md). The analysis below is the original assessment of the pre-fix snapshot; its descriptions of current behavior refer to that snapshot. The user subsequently confirmed that another developer owns profile-3 server support for both existing POST endpoints.

Reviewed 12 October 2026 against iOS commit `725c44d66` on `feature/nova-auth` and the locally available infrastructure `origin/main`, `d570b16bd31cdab26f0007cce3f37b67565156c8`. The infrastructure working checkout is on a different revision, so backend verification used the Git object for `origin/main`, not its working files. This does not establish what is deployed.

Input: [Claude's REVIEW.md](/private/tmp/claude-501/-Users-svojs-Documents-workspace-nova-wallet-ios/573315b9-f4d2-4a58-88c9-6c9c348c10a8/scratchpad/advrev/REVIEW.md). Its findings and proposed fixes were treated as claims to investigate, not implementation instructions. Two fresh Astra agents independently examined recovery and concurrency; the parent examined integration, contracts, error mapping and cleanup claims. No application code was changed.

The review finds genuine availability bugs in the implementation I produced. Passing tests did not establish that the recovery policy was correct: several tests assert the very behavior under criticism. However, this is not a set of 30 independent defects of equal importance, and its proposed combined fix is not ready to implement. Several findings describe the same eventual failure, some are deliberate conservative choices, and some proposed remedies would introduce new recovery or persistence problems.

I would retain one NovaAuth owner and one current bearer shared by the app. The main problems are how that owner classifies failures, retires identities and permits recovery. None of the findings establishes that separate feature tokens would improve this design.

## What should drive the next changes

1. **Make recovery work for every consumer, including analytics.** N03 is the most consequential client finding. Analytics always requests `.background`; all retired identities require `.userInitiated`, and the actual user-initiated callers are Bittensor screens. An app that never opens those screens has no recovery path after key loss or several transient failures. Separate ordinary lost-key recovery from an explicit reset or accepted origin change; do not simply relabel every automatic upload as a user action.
2. **Stop treating recoverable conditions as permanent identity loss.** F02, F04/F14 and the assertion-specific part of F10 are real. Policy refusal should not irreversibly destroy the client's ability to use a still-existing binding after policy changes. Offline or overloaded registration probes do not prove registration failed. A local assertion timer expiring does not prove the key disappeared.
3. **Separate service availability from authentication availability.** F08 is real. One bearer does not require an analytics ingestion failure to block Bittensor. Keep shared credential issuance and coordination; classify which failures justify shared backoff. Keep appropriate service backoff for failures excluded from it.
4. **Resolve the backend release dependency without silently changing the requested endpoint contract.** F01 is a release gate against the checked backend snapshot. The user explicitly selected the existing analytics and operations-search endpoints with the same bearer. New `/profile-3/` POST aliases are one possible cross-client migration design, not an automatic correction to this client's requirements.
5. **Fix the small, demonstrable correctness problems and add useful diagnostics.** N01's error mapping, F06's enqueue/cancellation race, F15's pre-send recovery gap, F17's error masking and Q2's missing transition logs deserve focused changes. They do not require a state-machine rewrite.

## Findings with the largest impact

### N03 — Analytics can remain blocked indefinitely

**Accept; high priority.** [AnalyticsUploadOperationFactory.swift:112](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAnalytics/Sources/NovaAnalytics/Network/AnalyticsUploadOperationFactory.swift:112) always uses background intent. [NovaAuthRegistrationService.swift:7](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:7) rejects background demand after reset/origin change and after every retirement. [NovaAuthTokenProvider.swift:165](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift:165) retires a missing key.

A concrete path is restoring preferences onto a new phone: the saved key identifier can survive while the App Attest key does not. Apple explicitly documents that App Attest keys do not survive device migration or backup restoration. The next assertion fails, the identity retires, and later analytics flushes cannot recreate it. [Apple: Establishing your app's integrity](https://developer.apple.com/documentation/DeviceCheck/establishing-your-app-s-integrity).

“Permanent” here means no automatic recovery under the current app integration; a qualifying Bittensor interaction can recover non-policy retirements. Origin changes take effect when a new config is actually accepted, not immediately on every device when the remote file changes. Neither qualification makes the analytics dependency acceptable.

The review itself is inconsistent: N03 calls this a major bug, while its final “Missing steps” calls the same consequence “Not a bug.” I agree with N03. This is a missing app-wide recovery path, not an analytics product requirement the user accepted.

### F02 — Policy refusal becomes a permanent local prohibition

**Accept; high priority.** A `binding_not_allowed` response leads to `.retired(.policyRefused)`; [prepareIdentity:10](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:10) then rejects even a user-initiated attempt. The backend may later restore its allowlist, but this installation will not ask again. The facade reset has no production caller.

The existing bearer remains usable until its local deadline, so the outage is not necessarily immediate. Also distinguish an existing binding being temporarily disallowed from registration of an app that is not permitted at all. Preserving an existing binding and providing bounded recovery is appropriate; periodically generating fresh identities after a policy rejection is not.

### F04/F14 — Registration recovery can discard a valid binding

**Accept the core issue; change the proposed remedy before implementation.** [NovaAuthPendingRecovery.swift:6](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthPendingRecovery.swift:6) retires after eight reserved attempts. Reservation happens before sending; offline failures, 429s, transient 5xx, cancellation and successful token challenges followed by a later failure can all consume this budget. The count survives restarts. Separately, [handleChallengeFailure:54](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:54) treats almost any pending-state 4xx as a final registration refusal.

These observations justify changing when a binding is declared unrecoverable. They do not justify dropping limits or blindly refunding every cancellation: interrupted attempts and persistence-before-send ordering still need a consistent model.

A token-challenge 200 proves the server found a binding, but the written protocol describes successful bearer issuance as confirmation of recovered registration. The review alternates between immediately saving `.registered` and retaining that literal rule. Choose that state meaning explicitly. Avoid grafting both alternatives onto the existing model.

### F08 — Business failures affect the whole app

**Accept; high priority.** [NovaAuth+Authorization.swift:25](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuth+Authorization.swift:25) feeds every business 503 and transport failure into `originCooldown`. Both demand and the final send check consult it, even with a usable bearer. Telemetry's `503 queue_over_capacity`, once that POST is authorized, can therefore suppress Bittensor requests. Bittensor service 503s already affect this shared state.

This is coupling between services, not an argument for multiple credentials. Classify authentication/edge refusal separately from identifiable domain failures. The reviewed protocol's generic “503 and transport failures” wording is broad, so I do not claim the precise revised classification is already mandated by it. The ledger's additional “one cooldown / auth signals only” owner rule is not the same thing as the user's explicit requirement of one token.

Do not simply remove every transport/uncoded-503 backoff: uncoded edge overload can be real, and Bittensor needs some retry control. Analytics already has its own upload scheduling/backoff. Agree the classification and keep that separation in both issuer and reader if the reader remains.

### F01 — The POST migration is not supported by the checked backend

**Accept as a release dependency, not a newly discovered client routing defect.** The [client allowlist](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Wire/NovaAuthRoute.swift:5) intentionally sends the shared bearer to the existing POST paths. The checked [backend topology](https://github.com/novasamatech/nova-infrastructure/blob/d570b16bd31cdab26f0007cce3f37b67565156c8/attestation/tests/integration/edge/topology.json) still routes those paths through profile-2 proof authentication. Its `request_proof` rejects missing `X-Attestation-Profile` with `400 unsupported_profile`. Merely forwarding the paths to the current profile-3 verifier is also insufficient: its allowed flow is read-only.

The [client README:48](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/README.md:48) already states this rollout dependency. A deployment matching this backend cannot deliver analytics or operations searches from this client. This review did not inspect deployment manifests or authenticate against the live backend, so it does not prove the current deployment revision.

I disagree with treating new alias URLs as the required client fix. They follow the old backend ADR's compatibility rule but conflict with the user's explicit existing-path decision. Existing clients, endpoint authorization and the ADR need a coordinated backend decision. Nothing here requires separate bearers or restoring profile 2 inside this app.

### F05/F10/N04 — Apple error phases must stay distinct

**F05's wasted work is real; its proposed retry is not established as correct.** [attest:114](/Users/svojs/Documents/workspace/nova-wallet-ios/Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift:114) retries a deferred attempt before checking the original challenge's age. Success can immediately be thrown away because the challenge already expired. The client should not call Apple for a result it already knows it cannot register.

However, after `serverUnavailable`, Apple specifically recommends retaining both the key and `clientDataHash`. The review's fresh-challenge/fresh-hash retry changes that guidance; a fake successful Apple callback in a unit test cannot validate it. This is a genuine interaction between the backend's 60-second challenge and Apple's retry semantics, not an obvious local refactor. [Apple: serverUnavailable](https://developer.apple.com/documentation/devicecheck/dcerror-swift.struct/serverunavailable).

**F10 is valid for assertion generation.** A locally imposed timer expiring in `generateAssertion` does not prove a registered key is lost. Retrying later with a new challenge need not reset its counter or identity. The local timer does not cancel the underlying DeviceCheck call, so a fix must also preserve safe serialization around a late callback. In contrast, a timed-out or interrupted one-time `attestKey` can leave an unknown attestation outcome. A blanket “all Apple timeouts keep/retry the key” fix conflates those stages.

**N04 is not proven defective solely because it is conservative.** Retiring a persisted `appleInFlight` attempt after a crash can cost an extra key. But the claimed safe optimization—retrying with a fresh hash because an already-attested key will fail—needs stronger support and real-device validation. Even accepting the review's already-attested-key rejection premise does not establish that every interrupted call can safely be retried with different inputs. I would address the background recovery consequence through N03 without calling this optimization mandatory.

### N01 — Network problems are presented as device problems

**Accept; reproduced.** [BittensorAuthorizedResponseGrader.swift:46](/Users/svojs/Documents/workspace/nova-wallet-ios/novawallet/Common/Network/Bittensor/Transport/BittensorAuthorizedResponseGrader.swift:46) maps every non-NovaAuth error to `attestationFailure`. A cold configuration fetch produces an ordinary `URLError`; that becomes device-bound and hides retry controls. Generic business 401/403 and malformed bootstrap responses have the same classification problem.

A standalone Swift probe compiled the unchanged production grader, error enum and recovery classification, with minimal response/cache type scaffolding. Results:

| Input | Current result | Device-bound |
|---|---|---|
| Cold-config `URLError.notConnectedToInternet` | `attestationFailure` | Yes |
| Same offline error already wrapped as `NovaAuthError.transport` | `transport` | No |
| `NovaAuthError.invalidResponse` | `attestationFailure` | Yes |
| HTML edge 401 or 403 | `attestationFailure` | Yes |

The previous grader explicitly preserved `URLError` as transport. This is a real regression. Cancellation is largely suppressed before UI delivery, so that part of the ledger does not have the same demonstrated user impact.

## Complete disposition of the numbered findings

“Accept” means the relevant behavior is established, not that the proposed patch should be applied unchanged. Related effects are intentionally not counted again as independent major bugs.

| ID | Assessment | Opinion and action |
|---|---|---|
| F01 | Accept: release gate | POST backend support is missing in the checked snapshot. Preserve the user's endpoint decision while resolving the backend contract; deployment remains unverified. |
| F02 | Accept: high priority | Persistent policy refusal has no supported recovery even after backend policy is repaired. Preserve binding information and add deliberate recovery. |
| F03 | Partial: severity overstated | Repeated user actions after cooldown can create new keys on a persistent refusal. There is no autonomous endless registration loop. Distinguish terminal/configuration errors from recoverable failures; a new 1-minute→24-hour persisted ladder is a proposed policy, not a proven requirement. |
| F04 | Accept core: high priority | All reserved attempts consume the pending budget, even when no evidence of failed registration is obtained. Do not implement the contradictory confirmation/refund proposals verbatim. |
| F05 | Accept wasted attempt; reject unproven fix | Detect an already unusable challenge before calling Apple. Same-key/new-hash retry after `serverUnavailable` needs a compatible protocol decision. |
| F06 | Accept: real package race, currently latent | Cancel-before-enqueue can crash with the pinned dependency. Reorder/coordinate enqueue and cancellation, keeping completion installed first. Current combining wrappers limit reachability; later ledger text incorrectly asserts demonstrated app reachability. |
| F07 | Accept corruption recovery gap; narrow latch claim | An undecodable identity survives relaunch and defeats both activate and reset. A transient save/delete failure is not necessarily permanent after relaunch. Distinguish corruption from temporary storage unavailability before any destructive recovery. |
| F08 | Accept: high priority | Service 503s/transport errors feed the shared origin gate. One credential does not require one service's failure to stall another. Preserve appropriate backoff outside auth. |
| F09 | Accept: bounded availability issue | An irreversible old flight can occupy the single-flight slot after origin/reset change. Old-context results are fenced; this is delay/failure of new work, not old credentials being installed. Detachment must preserve callback fencing and the required per-key serialization. |
| F10 | Accept only with phase distinction | Assertion timeout is not evidence of lost key. Unknown one-time attestation is a different recovery problem. |
| F11 | Partial | Retirement can happen in pre-send while the flight remains joinable; another demand can mutate identity before the old completion. Coordinate retirement/flight ownership. Removing cooldown after retirement is not independently correct and can worsen F03. |
| F12 | Accept: low priority | Non-pending Retry-After is memory-only. Restart can make one early request; server preflight limits it. New persistent schema/backoff state may cost more than this defect warrants. |
| F13 | Accept: tiny latent mismatch | Client caps Retry-After at 900; backend maximum TTL plus slot skew can require 905. Default TTL is 300 in the checked code; the difference normally produces one extra refusal, not bypassed authorization. |
| F14 | Accept: part of pending recovery | A failed token-challenge request is not generally proof the existing binding is invalid. Generic 4xx policy should not indiscriminately retire pending identity. Distinct from an initial registration request conclusively refused before it was applied. |
| F15 | Accept: bounded pre-send race | Another request can invalidate/remove the bearer after admission; final send check then fails without joining refresh. A bounded re-admission before any send can help. Do not bypass context/cancellation checks or create another POST replay cycle. |
| F16 | Accept: narrow integration error | Caller `beforeSend` errors are sanitized into `invalidResponse`, losing analytics abort semantics. Preserve caller errors at that boundary; do not remove redaction from all auth/network errors. Consent validation still prevents the send. |
| F17 | Accept: small clear bug | `issuanceStart` is checked before unwrapping a failed token operation; the real failure can become `clockUnavailable`. Unwrap the operation result first. |
| F18 | Partial: hardening | Later demands can repeat fresh proofs after persistent `invalid_proof`; it is not an in-operation infinite loop or reuse of the same proof. Better classification/backoff is reasonable. Blind identity rotation or permanently stopping background consumers is not. |
| F19 | Accept limitation; keep exact comparison for now | Clock steps can change `kern.boottime`, discarding credentials and affecting cooldown/pending checks. Mostly documented already. A two-second equality heuristic is not established as a reliable reboot discriminator; do not adopt it casually. |
| F20 | Accept platform risk; not reproduced on device | Holding an App Group file lock across suspension has a documented termination risk. Reader deletion is an optional scope decision, not the only fix. Any lock-free compare-delete redesign needs its own verification. |
| F21 | Behavior real; proposed fix is conditional | Reader can discard a 200 after the record disappears. Missing record can also mean reset, so accepting it unconditionally weakens reset fencing. No active extension consumer today. |
| F22 | Latent reset boundary issue | A failed/interrupted reset can leave the old bearer visible to a reader that cannot see preferences generation. Reordering deletion reduces a window, but cannot guarantee successful revocation if deletion itself fails. Reset throws; server validity is unchanged. |
| F23 | Contract/rollout documentation, not a client bug | No profile flag exists. Under the selected profile-3-only design it would be a kill switch, not fallback. Do not restore profile 2 or add a flag merely to match an older rollout clause. |
| F24 | Accept conditional replay design | A conclusive token-auth denial before forwarding permits one same-body POST retry. Include this guarantee in the POST backend contract. This is not general exactly-once analytics delivery or permission to retry ambiguous transport failures. |
| Q1 | Optional cleanup | Centralize values that actually represent the same protocol rule. Equal numeric literals can have unrelated meanings; do not merge all size limits or unrelated character sets. |
| Q2 | Accept: operationally valuable | Logger is injected but never used; first recovered denial ID is discarded. Add bounded, redacted transition diagnostics. Final-denial and bootstrap request IDs already reach callers. |
| Q3 | Accept unused wiring; deletion optional | Extension reader factory has no production caller and README says it is used. Correct that claim. A public reader/reset capability is not necessarily an erroneous design merely because current app code does not invoke it. |
| Q4 | No demonstrated correctness bug | Header-name filtering can reject a benign response from cache; it does not admit private content. Narrowing to a fixed exact-name list could weaken the guard. No need to change without a real benign response being rejected. |
| Q5 | No demonstrated synchronization bug | State spans extensions, but inspected paths use the same lock. Encapsulation could improve maintenance; a reducer rewrite is not required to fix these findings. |
| Q6 | Reject test volume as a defect; accept coverage criticism | 107 tests or a roughly 1:1 test/source line ratio is not evidence of excess for this state machine. Fix tests that encode mistaken requirements and fill real behavioral gaps. Droppable commits/no-comment rules are asserted by the ledger, not established by this task. |
| N01 | Accept: reproduced regression | Preserve transport/edge/protocol errors as such instead of blaming the device and suppressing retry. |
| N02 | Not established as a separate defect | A conclusively pre-forward refusal of the initial register request leaves a spent attestation and no binding; retirement is defensible. The ledger overstates this as a universal guarantee for every uncoded 4xx. No concrete post-commit uncoded-4xx path was established. |
| N03 | Accept: high priority | Shared authentication recovery must not depend on opening Bittensor in order to restore analytics. |
| N04 | Conservative behavior; optimization unproven | Crash during initial attestation may cost a new key. Fresh-hash retry of the unknown call is not established as safe/Apple-recommended. Fix the eventual recovery path first. |

## Additional cluster observations

Most C1–C6 observations duplicate the table: background recovery is N03; storage corruption is F07; cross-service cooldown is F08; reader results/reset are F21/F22; unused reader documentation is Q3. They should not inflate defect counts.

- **Cancelled pending probes retaining their reservation:** real, part of F04. Reserving before send deliberately covers interrupted attempts; a refund policy must account for cancellation and dropped completion, not just server responses.
- **`unknown_client` tests use HTTP 404 instead of 401:** valid test-fixture defect. The checked backend uses 401. Matching both status and code would make state transitions more robust; it would not fix an observed conforming-server failure.
- **A rejected token may be returned by admission after compare-delete fails:** real recovery inconsistency. `usableToken` ignores the in-memory rejected set, while `checkSend` rejects it. This fails closed; it does not send a knowingly rejected bearer. “Every request fails until expiry” overstates duration: an existing refresh or the early-refresh threshold can recover if replacement succeeds. Admission should honor the same rejection knowledge as send.
- **A caller's `beforeSend` transport-shaped error can feed shared backoff:** real boundary issue combining F16 and F08, but latent for the current callers: analytics throws its own abort error and Bittensor supplies an empty hook. Caller validation errors should not silently become an origin connectivity verdict.
- **Tests drive reset even though the UI does not:** not sufficient reason to delete them. They test a package behavior and generation fencing. The missing real recovery entry point is the more important observation.

## Proposed fixes I would not accept as written

- The final instructions for **F06** contradict its detailed section about actual cancellation propagation. Fix the package race, but do not claim an observed screen-exit crash without a reachable trace. Merely moving cancellation installation after enqueue can let fast completion/recovery install a newer cancellation action that is then overwritten; synchronize enqueue and cancellation ownership and exercise that exact window.
- **F04** alternately recommends marking registration complete on a challenge 200 and retaining bearer-confirmed registration. Those are different state semantics.
- **F07/Q2/Q3** sometimes claim changing origin clears `storageFailed`. It does not: `activate` checks that latch before it can replace the context. An explicit reset can clear it if loading succeeds; relaunch can clear a purely in-memory failure if persisted data is valid.
- The extra persistent generation key proposed for **F07** is not justified by the cited cache collision. The Bittensor cache is in-memory, and identity loading happens before first activation. Any recovery still needs to fence work and clear the shared token, but another independently stored counter is not automatically necessary.
- **F18's** final combined remedy eventually rotates identity after enough proof failures. That does not repair a deterministic hash/configuration bug and can recreate F03's key churn.
- **F21** cannot both accept every missing shared record and use record removal as a reset signal. Choose an explicit cross-process reset contract before weakening the current check.
- “Remove the reader,” “add a two-second boot tolerance,” “persist a 24-hour refusal ladder,” and “prune tests” are architecture/policy proposals. They do not follow mechanically from the established bugs.
- **Q5's** claim that a pure policy cannot model persistence ordering is too strong: a reducer can emit effects and consume their results. That still does not make a reducer rewrite the right priority here.

## Verification and limits

The assessment used current production code, its tests, the pinned Operation-iOS source, the previous grader, the checked backend Git snapshot and Apple documentation. The standalone grader probe used unchanged production error-handling functions. The independent cancellation probe compiled unmodified Operation-iOS 2.1.2 (`e607713…`) on macOS Foundation: cancel then enqueue terminated with `NSInvalidArgumentException`/SIGABRT; enqueue then cancel exited normally. This establishes the dependency mechanism, not an iPhone app reproduction.

Supporting material: [recovery analysis](/private/tmp/novaauth-review-recovery.md), [concurrency analysis](/private/tmp/novaauth-review-concurrency.md), [grader probe](/private/tmp/novaauth-review-probes/main.swift), [cancellation probe](/private/tmp/novaauth-review-concurrency/main.swift).

Apple documents suspension while holding a file lock as a cause of `0xdead10cc`. That supports F20's risk, not a claim that this app has already experienced such a crash. [Apple: EXC_CRASH (SIGKILL)](https://developer.apple.com/documentation/xcode/sigkill).

No signed-device App Attest retry experiment, live authenticated backend test, deployment audit or whole-app test run was performed for this read-only assessment. In particular, passing mocks cannot validate changing Apple's retry inputs, and a local backend snapshot cannot prove what the phone currently reaches.

The next implementation should use a small recovery/error-classification plan, preserving one shared token, followed by targeted regression tests and a signed Debug device exercise. I would not implement the ledger's combined rewrite or call the feature release-ready solely because its current suites pass.
