# NovaAuth

Operation-based, app-wide profile-3 authentication for iOS 16+. The host owns one `NovaAuth`
instance and injects its `NovaAuthClientProtocol` into analytics and Bittensor. One installation
and one persisted current bearer serve every approved consumer; renewal replaces that bearer.

`activate(origin:)` selects the exact HTTPS backend origin. `createAdmissionWrapper` checks a
usable bearer before domain caches, while `createResponseWrapper` checks again before native
URLCache or network access. GET uses the seven allowed `/v1/bittensor/profile-3` routes.
Analytics and operations search retain their existing POST paths and immutable request bodies.
Only conclusive pre-backend `invalid_token` allows a single replay. A credential rejected by
another request before sending permits one separate, bounded re-admission. Neither path
changes the POST body or allows more than two actual sends. Caller `beforeSend` runs before
each send, including an authorized retry; its errors are returned unchanged.

The main host supplies AppIdentifierPrefix + bundle identifier, settings, the shared Keychain
access group, a required stable host-app namespace, and separate
owner/bootstrap/business queues. Keychain holds one atomic bearer record per installed host
app with continuous-clock/boot metadata; preferences hold no bearer. The namespace is the
host app's bundle identifier, explicitly injected into the app's build metadata.
Auth no longer resolves or requires an App Group filesystem container; the Keychain access
group is retained. Other host features still use the App Group container.
Release and Staging share an App Group but use distinct Keychain services, so neither can
read, overwrite or delete the other's bearer. All features within one host still share its
single current record; origin, consumer and client UUID never select separate token pools.

Explicit reset or an origin change fences old work and requires a new user-initiated demand.
Analytics withdrawal/erasure only affects analytics state and never resets shared auth.
After an origin change or explicit reset, an install with analytics consent on and no Bittensor
use uploads nothing. Uploads can resume after a real Bittensor user action or a consent off/on
cycle, subject to normal admission and retry limits. Saved consent and automatic uploads do
not provide user intent.

An actual consent false-to-true event keeps one in-memory pending admission. A retryable
endpoint-resolution failure parks it until successful endpoint adoption; there is no short
polling deadline that loses an offline action. Each genuine opt-in gets its initial attempt.
Only automatic admission-cooldown re-arms spend the launch-wide budget of two retries, with
the full remaining cooldown respected. Other admission failures finish the event. Withdrawal,
deactivation or context invalidation discards it. Endpoint readiness is separate from
invalidation and cannot revive an event discarded by a cold origin replacement or reset.
Uploads always retain background intent.

Native URLCache owns HTTP freshness. Domain caches retain decoded, explicitly stale display
seeds and coalesce admitted in-flight work; they never return a seed as a protected fetch result.
The host stamps each accepted endpoint with an invalidation revision. Bittensor carries it
through admission and checks the latest revision before cache participation, completion and
peek. Delayed invalidations cannot retire newer state; old work cannot restore retired seeds.

## Recovery and admission

A first installation can authenticate on background demand. Replacement policy depends on the
persisted retirement reason:

| Retirement reason | Recreation policy after the applicable delay |
| --- | --- |
| `lostKey` (invalid assertion key), `interrupted` (relaunch finds `appleInFlight`) | Any intent while the persisted background recreation count is below two; thereafter user action only. |
| `registrationRefused` (any non-429 registration 4xx, including `app_not_allowed` and `invalid_proof`) | User action only; no probe or background replacement of that refused registration. |
| `registrationAbandoned` (uncertain/failed attestation except `serverUnavailable`, expired attempt, oversized object, exhausted pending `unknown_client` evidence, or `401 unknown_client` for a registered identity) | User action only. |
| Legacy `unrecoverableRegistration` | Decode-compatible; same user-only policy as abandonment. |
| Legacy `policyRefused` | User action only; with a saved key, first probe the existing binding through pending registration. Without a key, recreate. |

Recovery keeps three independent persisted ladders. Each uses the base steps 60, 600, 3,600,
86,400 seconds, capped **before** multiplying by `1 + 0.1 × random` (0–10% jitter):

| Delay | Charged once for | Base cap |
| --- | --- | --- |
| `recreationDelay` | Each retirement; checked only while retired | 86,400 s |
| `policyRetryDelay` | `binding_not_allowed` at token challenge or issuance | 600 s |
| `proofRetryDelay` | `invalid_proof` at `/tokens` | 3,600 s |

Policy/proof failures keep the key and registration, consume no recreation budget, and permit
any intent after the delay. A proof retry obtains a fresh challenge/assertion. Starting a
replacement does not charge another retirement delay. Each non-user replacement reserves one
of two background slots before key generation; cancellation or failed generation can consume
the reservation. User actions consume no slots and do not bypass active delays. The old retired
reason stays stored until the replacement key and new client UUID can be saved together.

Settings writes, including reset markers, use `SettingsManager.set` and verify read-back.
The production manager internally calls `UserDefaults.synchronize()`, but neither that call
nor matching in-process read-back proves durable persistence or detects every refused disk
write. There is no extra commit acknowledgement API. Validation/read-back errors block admission
and retain the intended state for repair on activation. The reservation is written before key
generation; the cross-launch budget relies on ordinary settings persistence. Undetected failed
persistence can lose that reservation on relaunch, so this is not a fail-closed durability or
power-loss guarantee.

All waits are boot-scoped: a `kern.boottime` mismatch ends the wait without advancing a tier or
resetting the persisted budget. Repeated key creation is bounded by the budget, not wall time.
A successful bearer install clears all recovery delays and the count **after** the bearer write;
context replacement starts fresh. Legacy `recoveryCooldown` preserves its deadline but starts
the recreation ladder at tier zero.

Main-owner admission returns a usable bearer first. Without one, it joins an existing flight
or checks origin, issuance, applicable recovery, then pending-registration cooldowns before
starting a flight. Business sends still check shared-origin and family cooldowns even with a
usable bearer. During an origin cooldown the owner can still construct a request wrapper,
but its send gate blocks cache/network access.
An early refresh also respects origin, issuance and recovery delays.

Pending registration recovery persists its original uncertainty window and continuous-clock
backoff before each probe leaves the process. Only observed `unknown_client` responses spend
the eight-response absence budget; offline, overloaded and interrupted probes do not. A valid
token challenge resets that count, while registration stays pending until bearer installation.
Legacy attempt counts migrate to zero conclusive responses while preserving their cooldown.
Conclusive absence is specifically `401 unknown_client`: pending recovery continues only on
the same boot, below 120 seconds, and below eight such responses. The 120-second window is not
a deadline for every inconclusive pending failure.

Apple `serverUnavailable` saves `appleDeferred` for the same key/hash. The early pre-call check
requires the same boot and age in `0...40` seconds before saving `appleInFlight`. After acquiring
the key lease, `beforeAttest` checks the current flight/context and the same age budget immediately
before native `attestKey`, covering time spent queued. Exactly 40 seconds passes; 40.001 does
not. This chooses a minimum 20-second margin on the 60-second challenge. The authoritative
post-call check requires `0 <= age < 60`; Apple's local timeout is 100 seconds, so the chosen
margin cannot guarantee completion in time. Expiry retires as `registrationAbandoned` once
and requires user action for replacement. A native-guard age failure takes that retirement
through the current flight's fenced completion; a stale flight cannot retire an identity in
the new context.

If the execution guard fails, no native call has begun, so the adapter releases the unused lease.
Once a native call has begun, only its actual DeviceCheck callback releases the lease, even
after local timeout/cancellation. An assertion timeout keeps the registered key. Issuance checks
`isBusy(keyID:)` before requesting a token challenge and fails locally while busy. If Apple never
calls back, that key remains busy until process restart; no timer releases a called lease.

## Cooldowns, errors and storage

| Business result | Cooldown scope |
| --- | --- |
| 429; uncoded 500; explicit 503 `attestation_unavailable` | Shared origin, affecting both consumers. |
| Uncoded 502/503/504 and other 5xx, including coded domain 5xx except the explicit shared case above | Only the analytics or Bittensor family. |
| Business transport failure | Only that family. |

“Uncoded” means the client could not parse a valid error code. This is client classification,
not proof of which server component failed. Default short backoff is 1, 2, 4, 8, 16, 30 seconds
plus up to one second of jitter; numeric Retry-After is clamped to 1–905 seconds (429 defaults
to 30). Token lifetime remains capped at 900 seconds. Expiry does not itself schedule a retry.

Bittensor maps bootstrap `401 attestation_failed` to device-bound `attestationRejected`, with
no user retry. `409 client_already_registered` is non-device-bound `bindingConflict`, also
without retry. `403 insufficient_scope` is generic `invalidRequest`, without retry, before the
generic 401/403 mapping. Invalid challenge, 503 and transport failures remain retryable.

The max-APY walk ends on authentication-wide refusal, final token denial, unsupported device
or invalid auth configuration, preserving the error without caching nil or a partial maximum.
It does not start another outer retry for those errors. Route/data gaps retain their existing
per-target skip policy; transient failures retain bounded retries.

Keychain writes atomically include a SHA-256 record fingerprint. Conditional deletion matches
that fingerprint in the Security query, so a late denial cannot remove a replacement record.
There is no cross-process file lock. Legacy untagged records remain readable and are replaced
on renewal. When rejection or invalidity needs deletion, only the main writer, under its gate,
can fall back to `removeAll()` after conditional removal returns false and a reload still equals
the same record. Corrupt records are not deleted during a read. Repeated-denial cooldown is
applied before throwing deletion; a failed delete cannot skip it. The owner uses issuance
cooldown. Identity-storage repair distinguishes corruption from transient failure and completes
owed bearer deletion before admitting work.

Diagnostics use fixed retirement reasons, typed cooldown scopes (`shared`, `family`,
`recreation`, `policy`, `proof`), and a `storageFailed` transition on entering failed/dirty
storage state. They omit bearer values, client/key IDs, proofs and response bodies.

**Accepted restart limitation:** ordinary issuance Retry-After is in memory and is lost when
the owner restarts. Pending-registration cooldown and the three recovery ladders are persisted;
the non-pending issuance delay is not. Origin/family business cooldowns are also in memory.

Source walkthrough: [nine client views](../../.claude/docs/architecture/novaauth-client-diagrams.md),
[recovery policy](Sources/NovaAuth/Lifecycle/NovaAuthRecoveryService.swift),
[business cooldown classification](Sources/NovaAuth/Authorization/NovaAuthBusinessCooldowns.swift),
[bounded consent recovery](../NovaAnalytics/Sources/NovaAnalytics/AnalyticsConsentAuthRecovery.swift),
[settings storage](Sources/NovaAuth/API/NovaAuthConfiguration.swift), and
[native attestation guard](Sources/NovaAuth/AppAttest/NovaAuthDeviceCheckService.swift).

## Clock limitation

The protocol mandates `kern.boottime` as the persisted boot marker. Apple adjusts that value
when correcting calendar time, so a clock correction can conservatively discard a usable
bearer, cause extra issuance, or reset boot-scoped cooldown checks. Token
deadlines still use continuous elapsed time; a correction cannot extend or revive a token.
`kern.bootsessionuuid` is unavailable to apps on iOS 18 and later and is not a supported
substitute. This implementation retains the mandated reboot detection and existing entitlements.
See [Apple's calendar-clock implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/clock.c)
and [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes).

## Backend rollout coordination

The server migration is owned separately. The client uses profile 3 exclusively for the seven
Bittensor GET routes, **POST /v1/analytics/events** and
**POST /v1/bittensor/operations/search**, with the same existing `bittensor-read` issuance flow
and bearer. Release coordination must confirm server authorization for both existing POST
paths **and rejection of `invalid_token` before either POST reaches its business handler**.
That pre-handler contract is what permits the client's single replay of identical POST bytes;
the client denial predicate alone cannot establish the server's execution order. Both items
belong beside the separately owned server migration. This iOS change does not modify or deploy
the backend; there is no legacy fallback.

## Validation

Run the package XCTest suite with `xcodebuild test -scheme NovaAuth` on an iOS simulator;
`swift test` targets macOS and is inappropriate for these iOS dependencies. Its 12 tests run the
real client, bootstrap factory and settings identity store against one fake server: the profile-3
vectors, registration and recovery limits, token replay, cooldown scopes and exchange release.
The app tests cover the non-blocking availability read, delayed cache invalidation, Bittensor
flows through real NovaAuth and Max-APY termination. App/extension App Groups are development
for Debug/Dev and production for Staging/Release. Real App Attest, signed Keychain access-group
sharing, protected data and physical reboot behavior still require device validation.
