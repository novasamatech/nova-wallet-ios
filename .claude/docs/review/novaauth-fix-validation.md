# NovaAuth client fixes and validation

12 October 2026 · `feature/nova-auth` · local commits only.

This implements the accepted client findings from the [independent review assessment](novaauth-review-assessment.md). The client remains exclusively profile 3, with one NovaAuth owner and one current bearer for every consumer. Both existing POST paths remain unchanged: `/v1/analytics/events` and `/v1/bittensor/operations/search`. The user confirmed that another developer owns their server migration.

## Changes

| Area | Result |
| --- | --- |
| Ordinary recovery | Lost keys and unrecoverable registration can recover on later background demand, including analytics, with a persisted minimum 60-second recreation interval. Reset, origin replacement and app-policy gates still require a real user action. |
| Policy refusal | Preserve an existing binding after `binding_not_allowed`; retry it after the persisted delay. A usable bearer remains available. Legacy ambiguous policy state probes its existing binding on user demand. |
| Pending registration | Count observed `unknown_client` responses, not offline/overload/cancelled attempts. A successful token challenge resets the count but does not prematurely mark registration complete. Old stored attempt counts migrate safely. |
| Apple calls | Reject already-expired registration attempts before calling Apple. Assertion timeout preserves the key; native calls retain a per-key lease until the actual callback. Reset detaches old flights while fencing late results. |
| Request coordination | Enqueue and cancellation ownership are atomic. Permit one bounded unsent re-admission separately from the existing one sent-denial replay; preserve immutable POST bytes and caller gate errors. Locally rejected credentials stay excluded even if deletion fails. |
| Availability | Shared authentication/edge backoff remains common. Business failures back off only the affected service family. Bittensor network/protocol errors retain retryable meaning. Retry-After allows 905 seconds without changing the 900-second token limit. |
| Persistence | Distinguish corrupt identity data from transient storage failures. Retry the exact intended state, persist owed bearer deletion, and keep reset gates across restart. Replace the App Group file lock with atomic fingerprint-matched Keychain deletion. |
| Analytics consent | An actual opt-in schedules one user-initiated admission on the shared client. Restored consent and foreground changes do not. Withdrawal/throttle cancel only analytics-owned recovery; uploads remain background requests. |
| Diagnostics | Record fixed authentication stages, categories, status and bounded request IDs asynchronously. Do not log bearers, identity/key IDs, proofs, challenges, bodies or arbitrary error descriptions. |

The implementation and updated tests were independently cross-reviewed. No actionable correctness finding remained. The final verification pass separately corrected two stale reset assertions and a Subtensor test expecting the former shared-origin cooldown; the latter still asserts chain fallback and exactly one network request.

## Verification

Xcode 26.5, Debug, iPhone 17 Pro simulator:

| Check | Result |
| --- | --- |
| NovaAuth package | 141 tests passed |
| NovaAnalytics package | 53 tests passed |
| Focused app integration | 28 tests passed |
| Subtensor active-root flows | 3 tests passed |
| Full app unit suite | 1,374 tests passed, zero failures |
| Formatting | Pinned formatter check passed |
| Lint | Exit success; configuration, style and complexity warnings remain |
| Architecture diagrams | Nine views rendered and checked; source anchors updated |

The [architecture diagrams](../architecture/novaauth-client-diagrams.html) describe the changed client code.

Implementation commits: `df883652f` (NovaAuth), `2790bfc3f` (analytics/Bittensor integration), and `6186d114b` (independent Subtensor regression correction). Verification logs are retained locally under `/private/tmp/novaauth-reviewed-fixes-*`.

## Boundaries

These tests use controlled Apple/network/storage doubles. They do not establish successful live App Attest authentication or deployed server authorization. Real-device end-to-end verification is still required after server rollout. If Apple never delivers an underlying callback, the affected key remains busy until process restart.

The unused extension reader retains its conservative reset fence and documented visibility limitation if app-side deletion fails; no new reader generation protocol was introduced. The existing boot-marker limitation also remains. There is no profile-2 fallback, new token pool, backend edit or push in this work.
