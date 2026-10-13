# NovaAuth

Operation-based, app-wide profile-3 authentication for iOS 16+. The host owns one `NovaAuth`
instance and injects its `NovaAuthClientProtocol` into analytics and Bittensor. One installation
and one persisted current bearer serve every approved consumer; renewal replaces that bearer.

`activate(origin:)` selects the exact HTTPS backend origin. `createAdmissionWrapper` checks a
network access. One origin/API-major bearer authorizes ordinary protected paths:
GET and HEAD reads and analytics POSTs. Auth validates transport syntax
and the selected HTTPS origin; each consumer and the server own business route/payload validation.
exact `WWW-Authenticate: Bearer error="invalid_token"`, plus a valid `invalid_token` envelope
for GET/POST. HEAD uses the status and header without a response body. A credential rejected by
usable bearer before domain caches, while `createResponseWrapper` checks again before native
URLCache or network access. GET/HEAD use the seven allowed `/v1/bittensor/profile-3` routes.
Analytics and operations search retain their existing POST paths and immutable request bodies.
Only conclusive pre-backend `invalid_token` allows a single replay. A credential rejected by
another request before sending permits one separate, bounded re-admission. Neither path
changes the POST body or allows more than two actual sends. Caller `beforeSend` runs before
each send, including an authorized retry; its errors are returned unchanged.

The main host supplies AppIdentifierPrefix + bundle identifier, the app version, settings and
separate owner/bootstrap/business queues. Keychain holds one atomic bearer record per installed
host app in the app's default Keychain access group, with continuous-clock/boot metadata;
preferences hold no bearer. Auth requires no App Group container, shared access group or
Info.plist namespace; each signed app variant owns its own record, so Release and Staging can
never read, overwrite or delete each other's bearer. All features within one host still share
its single current record; origin, consumer and client UUID never select separate token pools.
The owner caches a loaded record under its gate, so the Keychain is read again only while no
record is cached or after a write or removal. Store creation deletes the record an earlier
build kept under the App Group service `io.novawallet.novaauth.profile3.<bundle id>`.

Host `activate(origin:)` is the lifecycle authority. Accepted origin adoption or legacy reset
repair establishes an eligible context without creating a key or sending authentication.
A later ordinary demand, including consented Analytics, may initialize the installation.
This local product policy replaces the profile-3 protocol's user-driven re-creation
wording; it is an explicit eligibility change, not behavioral equivalence.
The package has no explicit reset API. Analytics consent/erasure and wallet changes do not
reset the shared identity. Requests carry a demand intent that only gates re-registration after a refusal.
Explicit reset or an origin change fences old work and requires a new user-initiated demand.
Analytics withdrawal/erasure only affects analytics state and never resets shared auth.
After an origin change or explicit reset, an install with analytics consent on and no Bittensor
use uploads nothing. Uploads can resume after a real Bittensor user action or a consent off/on
cycle, subject to normal admission and retry limits. Saved consent and automatic uploads do
not provide user intent.

NovaAuth has no HTTP cache: its single ephemeral session stores nothing, refuses redirects and
sends each authorized request to the network as one Operation-iOS `NetworkOperation`. Fresh, complete 200 reads carry `public, max-age=N,
must-revalidate`; POSTs and bootstrap use `no-store`.
Issuance commits to the canonical origin and API major 1 without a flow or scope. Renewal
obtains a fresh challenge and App Attest assertion; the server issues no refresh credential.

The host maps `infraUrl` to one endpoint per process and memoises it.
Native URLCache owns HTTP freshness. Domain caches retain decoded, explicitly stale display
seeds and coalesce admitted in-flight work; they never return a seed as a protected fetch result.
The host stamps each accepted endpoint with an invalidation revision. Bittensor carries it
through admission and checks the latest revision before cache participation, completion and
peek. Delayed invalidations cannot retire newer state; old work cannot restore retired seeds.

## Recovery and admission

A failed authentication attempt fails the caller's operation. NovaAuth schedules no retry and
owns no interaction or presentation policy. Every independently created later operation has
the same permission to try again after the short protocol cooldown. Concurrent demands join
one issuance flight, which attempts at most one new key generation. Retirement fails that
flight, except that a key found invalid at assertion time (for example after a backup restore)
is replaced by one fresh UUID/key within the same flight. Bearer replay preserves its original
client binding and cannot turn the same business operation into identity replacement.

Each request carries a `NovaAuthDemandIntent`: `.userDriven` (the default: screen loads, domain
retries, pull to refresh; admission is always user-driven) or `.background` (analytics flushes,
background syncs). A registration refused with any code-bearing 4xx other than 409 keeps the
client UUID, drops only the key and saves a refusal delay.
User-driven demands may re-register at once with a fresh key and challenge; background demands fail
with `cooldown` until the delay passes: 1 hour, then 6 hours, then 24 hours per consecutive refusal.
The delay is persisted, resets on an app version change or context replacement, and like every
other wait ends with a boot discontinuity.

| Situation | State retained or retired |
| --- | --- |
| Lost registration response, transport error or 5xx | Keep pending UUID/key/start; probe token challenge on a later demand. Never resend registration proof. |
| Pending token-challenge/issuance `401 unknown_client` before 120 seconds on the same boot | Keep pending state and its persisted probe backoff; fail this operation. |
| Confirmed absence outside that window or after boot discontinuity | Retire and fail; the next independent demand may replace. Transport/503 alone never prove absence. |
| Successful pending token challenge | Prove the same key; preserve the original pending window until a bearer is installed. |
| Ordinary token `401 invalid_proof` | Keep registered UUID/key/counter and fail. Later demand obtains a fresh challenge on the same binding. A contradictory `503 invalid_proof` is availability failure. |
| Token challenge/issuance `403 binding_not_allowed` or `403 app_not_allowed` | Keep registered UUID/key/counter, save the refusal delay and fail. A user-driven demand obtains a fresh challenge on the same binding at once; a background demand waits for the delay. |
| Any code-bearing registration 4xx except 409 and 429 (`401 attestation_failed`, `403 app_not_allowed`, `400 invalid_request`, `401 invalid_challenge`, …) | Keep the client UUID, drop the key, save the refusal delay and fail. A user-driven demand attests a fresh key at once; a background demand waits for the delay. |
| Codeless or non-JSON registration 4xx | Transport failure: keep pending UUID/key/start and the short cooldown; probe on a later demand. |
| Deferred attestation past its 40-second budget | Keep the key, take a fresh challenge and attest again in the same flight. |
| Interrupted, failed or timed-out attestation; stale or malformed attestation object | Drop the key, keep the client UUID and fail; a later demand attests a fresh key. |
| Platform invalid key at assertion | Retire and continue the same flight with one fresh UUID/key; a key generated in that flight is not replaced again. |
| Platform invalid key at attestation, registration `409 client_already_registered` | Retire and fail. Later demand may generate one fresh UUID/key. |
| Stored `retired` state | Loaded as is; the next demand replaces UUID/key and keeps the refusal counter. Legacy `policyRefused` keeps the client UUID and attests a fresh key under the refusal rules. |

Apple `serverUnavailable` saves `appleDeferred` for the same key/hash. Before saving
`appleInFlight`, and again after acquiring the native lease immediately before `attestKey`,
the current flight/context must match and the saved attempt must be on the same boot with
age in `0...40` seconds. After Apple's result, age must remain below 60 seconds. A deferred
attempt past its budget keeps the key and takes a fresh challenge in the same flight; expiry after
Apple's result drops the key, keeps the client UUID and fails the current operation. The 20-second
margin cannot guarantee native completion.

The shared session bounds every call with a 20-second request timeout (100 seconds for
registration) and a 100-second resource timeout and leaves authentication challenges to default
handling. A 110-second watchdog fails any call whose callback never arrives as a transport timeout,
so a flight always completes; native calls have their existing local timeout. Before invocation, a failed guard
releases the unused lease. Once called, only the actual DeviceCheck callback releases its
per-key lease, even after local timeout/cancellation. An assertion timeout preserves the
registered key. Busy keys fail before fetching a token challenge. If Apple never calls back,
that key stays busy until process restart. Irreversible commitment remains sticky across steps.

## Cooldowns, errors and storage

Short auth issuance and persisted pending-probe backoff use 1/2/4/8/16/30 seconds plus up to
one second of jitter. Numeric Retry-After is clamped to 1–905 seconds; 429 defaults to 30.
The pending probe reservation is saved before send, and a failed send does not charge it twice.
Ordinary business 5xx and transport failures pass to the caller's retry policy. Only 429 and
explicit `503 attestation_unavailable` protect the shared auth origin; generic business success
does not clear an active deadline. Usable bearer delivery precedes issuance waits, while each
actual business send checks origin protection. No timer automatically retries a refusal.
| Uncoded 502/503/504 and other 5xx, including coded domain 5xx except the explicit shared case above | Only the analytics or Bittensor family. |

Installation storage keeps its current key/version and validates surviving security fields.
Removed optional legacy policy fields are ignored, even if malformed; the next existing write
encodes only context, identity/registration, refusal delay and token-removal debt. Pending start/cooldown and
saved attestation inputs remain exact. Corrupt/reset repair replaces the context and cannot
adopt an old bearer. The active memory fence advances before I/O and survives a failed save;
staged writes and owed bearer deletion retry at host activation and on the next demand, blocking
admission until repaired.
Settings set/read-back checks the manager cache and cannot prove disk durability.

Keychain contains one atomic version-2 bearer record with origin, client, generation and
boot/continuous-clock metadata. Token persistence completes before delivery. Conditional
fingerprint deletion cannot remove a newer bearer. Only the sole writer under its gate may
fall back to removeAll after conditional removal fails and reload still equals the same legacy
record. Corrupt token reads do not delete unrelated data. Version-1 bearer records require fresh
issuance while preserving valid installation identity. Repeated denial suppresses rejected
credentials and applies issuance backoff before attempting deletion.
Bittensor maps bootstrap `401 attestation_failed` to device-bound `attestationRejected`, with
no user retry. `409 client_already_registered` is non-device-bound `bindingConflict`, also
without retry. `403 insufficient_scope` is generic `invalidRequest`, without retry, before the
generic 401/403 mapping. Invalid challenge, 503 and transport failures remain retryable.

Analytics retains batches silently for its normal later-flush policy; consent is checked before
every send and replay.
The max-APY walk ends on authentication-wide refusal, final token denial, unsupported device
or invalid auth configuration, preserving the error without caching nil or a partial maximum.
It does not start another outer retry for those errors. Route/data gaps retain their existing
per-target skip policy; transient failures retain bounded retries.

Failure diagnostics are asynchronous and redacted: a fixed step/category, numeric status,
allowlisted code and sanitized correlation ID. They never interpolate arbitrary Error,
requests, state, tokens, UUID/key, proof or body. Successful transitions are not narrated.
Ordinary issuance and shared-origin cooldowns remain memory-only; pending-probe cooldown and the
refusal delay are persisted. A restart can lose the memory-only delay. Boot-marker discontinuity ends boot-scoped waits.

Source walkthrough: [eight client views](../../.claude/docs/architecture/novaauth-client-diagrams.md),
[retirement](Sources/NovaAuth/Lifecycle/NovaAuthRecoveryService.swift),
[shared origin protection](Sources/NovaAuth/Authorization/NovaAuth+Authorization.swift),
[settings storage](Sources/NovaAuth/Storage/NovaAuthSettingsIdentityStore.swift), and
[native guard](Sources/NovaAuth/AppAttest/NovaAuthDeviceCheckService.swift).

## Clock limitation

The protocol mandates `kern.boottime` as the persisted boot marker. Apple adjusts that value
when correcting calendar time, so a clock correction can conservatively discard a usable
bearer, cause extra issuance, or reset boot-scoped cooldown checks. Token
deadlines still use continuous elapsed time; a correction cannot extend or revive a token.
`kern.bootsessionuuid` is unavailable to apps on iOS 18 and later and is not a supported
substitute. This implementation retains the mandated reboot detection and existing entitlements.
See [Apple's calendar-clock implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/clock.c)
and [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes).

## Protected requests

Ingress authenticates before protected business handlers execute. A conclusive token denial
therefore permits one replay preserving the original method, path, query and body. Other
401/403, 429, 5xx and uncertain transport outcomes do not authorize replay or reset identity.
Consumers grade business responses through `NovaAuthResponse.serverError` and `requestID`, the
package's own envelope parser: status, lowercase code up to 64 characters, sanitized
`X-Request-ID` and numeric Retry-After clamped to 905 seconds.
The server migration is owned separately. The client uses profile 3 exclusively for the seven
Bittensor GET/HEAD routes, **POST /v1/analytics/events** and
**POST /v1/bittensor/operations/search**, with the same existing `bittensor-read` issuance flow
and bearer. Release coordination must confirm server authorization for both existing POST
paths **and rejection of `invalid_token` before either POST reaches its business handler**.
That pre-handler contract is what permits the client's single replay of identical POST bytes;
the client denial predicate alone cannot establish the server's execution order. Both items
belong beside the separately owned server migration. This iOS change does not modify or deploy
the backend; there is no legacy fallback.

## Validation

exercise framing, operation recovery, same-binding refusal, pending registration, origin fencing,
bounded token replay, shared throttling and exchange release. Real App Attest,
Run the package XCTest suite with `xcodebuild test -scheme NovaAuth` on an iOS simulator;
`swift test` targets macOS and is inappropriate for these iOS dependencies. The app test suites
cover shared composition, revisioned origin changes, analytics consent, Bittensor routing and
presentation/coalescing behavior. App/extension App Groups are development for Debug/Dev and
production for Staging/Release. Real App Attest, signed extension Keychain sharing, protected
data and physical reboot behavior still require device validation.
