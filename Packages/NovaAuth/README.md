# NovaAuth

Operation-based, app-wide profile-3 authentication for iOS 16+. The host owns one `NovaAuth`
instance and injects its `NovaAuthClientProtocol` into analytics. One installation
and one persisted current bearer serve every approved consumer; renewal replaces that bearer.

`activate(origin:)` selects the exact HTTPS backend origin. `createAdmissionWrapper` checks a
usable bearer before domain caches, while `createResponseWrapper` checks again before native
URLCache or network access. Analytics and operations search retain their existing POST paths and immutable request bodies.
Only conclusive pre-backend `invalid_token` allows a single replay. Other errors never replay
POSTs automatically. Caller `beforeSend` runs before each send, including an authorized retry.

The main host supplies AppIdentifierPrefix + bundle identifier, settings, the App Group
container/Keychain access group, a required stable host-app namespace, and separate
owner/bootstrap/business queues. Keychain holds one atomic bearer record per installed host
app with continuous-clock/boot metadata; preferences hold no bearer. The namespace is the
host app's bundle identifier, explicitly injected into both app and extension build metadata.
The notification extension constructs `NovaAuthReader` with that same namespace, group and
configured origin. It can only use an already persisted current bearer; it has no issuer or reset API.
Release and Staging share an App Group but use distinct Keychain services, so neither can
read, overwrite or delete the other's bearer. All features within one host still share its
single current record; origin, consumer and client UUID never select separate token pools.

Explicit reset or an origin change fences old work and requires a new user-initiated demand.
Analytics withdrawal/erasure only affects analytics state and never resets shared auth.
Native URLCache owns HTTP freshness.

Pending registration recovery persists its original uncertainty window, eight-probe budget,
and continuous-clock backoff before each probe leaves the process. A same-boot restart retains
those limits. Old timestamp-only pending records cannot prove their remaining budget and fail
closed as unavailable storage; other valid version-1 states retain their existing encoding.

## Clock limitation

The protocol mandates `kern.boottime` as the persisted boot marker. Apple adjusts that value
when correcting calendar time, so a clock correction can conservatively discard a usable
bearer, refuse a reader, cause extra issuance, or reset boot-scoped cooldown checks. Token
deadlines still use continuous elapsed time; a correction cannot extend or revive a token.
`kern.bootsessionuuid` is unavailable to apps on iOS 18 and later and is not a supported
substitute. This implementation retains the mandated reboot detection and existing entitlements.
See [Apple's calendar-clock implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/clock.c)
and [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes).

## Backend rollout requirement

This iOS change does not modify or deploy the backend. There is no legacy
profile fallback or auth bypass.

## Validation

Run the package XCTest suite with `xcodebuild test -scheme NovaAuth` on an iOS simulator;
`swift test` targets macOS and is inappropriate for these iOS dependencies. The app test suites
cover shared composition, revisioned origin changes, analytics consent routing and
presentation/coalescing behavior. App/extension App Groups are development for Debug/Dev and
production for Staging/Release. Real App Attest, signed extension Keychain sharing, protected
data and physical reboot behavior still require device validation.
