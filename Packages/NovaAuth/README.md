# NovaAuth

Operation-based, app-wide profile-3 authentication for iOS 16+. The host owns one `NovaAuth`
instance and injects its `NovaAuthClientProtocol` into analytics. One installation
and one persisted current bearer serve every approved consumer; renewal replaces that bearer.

`activate(origin:)` selects the exact HTTPS backend origin. `createAdmissionWrapper` checks a
usable bearer before domain caches, while `createResponseWrapper` checks again before native
URLCache or network access. Analytics and operations search retain their existing POST paths and immutable request bodies.
Only conclusive pre-backend `invalid_token` allows a single replay. A credential rejected by
another request before sending permits one separate, bounded re-admission. Neither path
changes the POST body or allows more than two actual sends. Caller `beforeSend` runs before
each send, including an authorized retry; its errors are returned unchanged.

The main host supplies AppIdentifierPrefix + bundle identifier, settings, the App Group
container/Keychain access group, a required stable host-app namespace, and separate
owner/bootstrap/business queues. Keychain holds one atomic bearer record per installed host
app with continuous-clock/boot metadata; preferences hold no bearer. The namespace is the
host app's bundle identifier, explicitly injected into both app and extension build metadata.
The notification extension includes a `NovaAuthReader` factory with that same namespace,
group and configured origin, but no current notification handler calls it. A reader can only
use an already persisted current bearer; it has no issuer or reset API.
Release and Staging share an App Group but use distinct Keychain services, so neither can
read, overwrite or delete the other's bearer. All features within one host still share its
single current record; origin, consumer and client UUID never select separate token pools.

Explicit reset or an origin change fences old work and requires a new user-initiated demand.
Analytics withdrawal/erasure only affects analytics state and never resets shared auth.
Ordinary key-loss/registration recovery works on later background demand, with a persisted
minimum of 60 seconds between identity-recreation attempts. An existing binding refused by
policy is retained for a later retry. App registration policy refusal requires user action.
Native URLCache owns HTTP freshness.

Pending registration recovery persists its original uncertainty window and continuous-clock
backoff before each probe leaves the process. Only observed `unknown_client` responses spend
the eight-response absence budget; offline, overloaded and interrupted probes do not. A valid
token challenge resets that count, while registration stays pending until bearer installation.
Legacy attempt counts migrate to zero conclusive responses while preserving their cooldown.

Authentication/edge refusal can back off all consumers. Business transport and service failures
back off only analytics, using the same shared bearer. Retry-After is capped at 905
seconds; token lifetime remains capped at 900 seconds.

Keychain writes atomically include a SHA-256 record fingerprint. Conditional deletion matches
that fingerprint in the Security query, so a late denial cannot remove a replacement record.
There is no cross-process file lock. Legacy untagged records remain readable and are replaced
on renewal; corrupt records are not deleted during a read. Identity-storage repair distinguishes
corruption from transient failure and completes owed bearer deletion before admitting work.

An assertion timeout keeps the registered key. A per-key lease lasts until the actual DeviceCheck
callback, even after local timeout/cancellation. If Apple never calls back, that key remains busy
until process restart. An uncertain one-time attestation still retires conservatively.

## Clock limitation

The protocol mandates `kern.boottime` as the persisted boot marker. Apple adjusts that value
when correcting calendar time, so a clock correction can conservatively discard a usable
bearer, refuse a reader, cause extra issuance, or reset boot-scoped cooldown checks. Token
deadlines still use continuous elapsed time; a correction cannot extend or revive a token.
`kern.bootsessionuuid` is unavailable to apps on iOS 18 and later and is not a supported
substitute. This implementation retains the mandated reboot detection and existing entitlements.
See [Apple's calendar-clock implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/clock.c)
and [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes).

## Backend rollout coordination

The server migration is owned separately. Release coordination must confirm server authorization for both existing POST
paths. This iOS change does not modify or deploy the backend; there is no legacy fallback.

## Validation

Run the package XCTest suite with `xcodebuild test -scheme NovaAuth` on an iOS simulator;
`swift test` targets macOS and is inappropriate for these iOS dependencies. The app test suites
cover shared composition, revisioned origin changes, analytics consent routing and
presentation/coalescing behavior. App/extension App Groups are development for Debug/Dev and
production for Staging/Release. Real App Attest, signed extension Keychain sharing, protected
data and physical reboot behavior still require device validation.
