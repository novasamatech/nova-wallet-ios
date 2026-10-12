---
task: Replace NovaAppAttest with shared NovaAuth profile-3 authentication
date: 2026-10-12
status: implemented
baseline: 7eea9a4018d15e526e30748327ceead1fbf8d305
branch: feature/nova-auth
backend_contract: novasamatech/nova-infrastructure@e712da6a71ae1111d4ef8378945c854a7e71329f
research: .claude/research/novaauth-profile3.md
seams_used:
  - Operation-iOS 2.1.2 wrappers and NovaOperationSupport
  - GlobalConfigProviding and app-owned shared facades
  - injected SettingsManagerProtocol and Security/DeviceCheck adapters
  - existing app-group container and Keychain access group
  - analytics consent epoch and immutable upload batch
  - Bittensor transport and domain generation/coalescing seams
must_not_touch:
  - shipped CoreData model versions and wallet/account Keychain records
  - FirebaseAppCheckProviderFactory and DApp signing
  - backend snapshot or backend production configuration
  - dependency versions and hand-edited generated files
  - research artifact, except a correction coordinated with its author
out_of_scope:
  - Android, JWE decryption/claims/codec, refresh credentials, new server scopes
  - new screens, a new notification feature, new auth/profile coexistence flags
  - live App Attest verification, deployment, signing/provisioning changes
---

## Goal and fixed decisions

Ship a complete iOS profile-3 package at `Packages/NovaAuth`, replacing and deleting
`Packages/NovaAppAttest`. One app-wide main-process owner holds one active installation
identity and one current bearer for the configured backend. Bittensor reads, operations
search and telemetry join its one renewal flight; extensions read the same persisted bearer
and cannot register or issue. No approval gate remains: implementation is already authorized.

The authoritative protocol is `/private/tmp/nova-infrastructure-pr32-e712da6/attestation/docs/contracts/profile-3-protocol.md`.
Read the research alongside this plan. The planner read the complete protocol and fixture,
the relevant repository routing documents, and representative implementation files. The
architect skill supplies the document structure; its generic exploration/clarification steps
are satisfied by the completed research and user decisions. Do not invoke Superpowers.

All bootstrap bytes remain profile 3, API major 1 and flow `bittensor-read`. Tokens are opaque
ASCII strings. The two server token places allow old in-flight requests to finish; the client
never retains a second current token or separate consumer token pools. No request signs its
business body with App Attest. Only registration and issuance use App Attest.

The two explicit additions to the pinned server allowlist are the EXISTING
`POST /v1/analytics/events` and `POST /v1/bittensor/operations/search`, using that same bearer.
The backend auth/ingress expansion is an external rollout prerequisite; the downloaded server
does not yet authorize them. Preserve their bodies and endpoints, and document that prerequisite.
Do not invent token scopes or disable operations search. Its existing Unknown cost-basis
presentation remains the failure behavior until the backend accepts the route.

## Ownership and execution order

Root coordinates three fresh implementers, then fresh reviewers, then separate fresh fixers
for findings surviving reviewer/implementer discussion. All requested agents use Astra Extra
High. There are at most three concurrent child agents; root occupies the fourth slot. No
implementer spawns another agent. Root owns the heavy build slot and serializes simulator work.

| Stage | Owner | Work and exit condition |
|---|---|---|
| 0 | A, foundations | Create package manifest, all `API/` and `Contracts/` declarations below, test fixture resource and a compiling skeleton. Inform root that the seam is frozen. This is the only initial prerequisite for B/C. |
| 1A | A | Implement wire/framing/validation, secure storage and file lock, clock, DeviceCheck and HTTP/bootstrap primitives with foundation tests. |
| 1B | B, auth lifecycle | After seam freeze, implement owner, registration recovery, current-token provider, reader and authorized transport with lifecycle/concurrency tests. |
| 1C | C, integration | After seam freeze, migrate analytics and app composition, Bittensor transport/domain cache/harness, extension configuration, project, CI and docs. Keep legacy package until migrated references build. |
| 2 | Root + original owners | Root runs suites serially; route compile/test failures to the owning implementer. Owners fix their implementation failures before review. C performs final old-package deletion and membership cleanup. |
| 3 | Fresh reviewers | Three orthogonal reviews: wire/platform/registration; storage/concurrency/cancellation; consumer/cache/consent/project integration. Run two reviewers at once, reserving the third child slot for original-implementer discussion, then run the third review. Report surviving actionable findings with evidence. |
| 4 | Fresh fixers + root | Distinct fresh fixer agents address surviving findings in assigned disjoint files. Root repeats affected suites, then required final app/extension and unit checks. |

No owner edits another owner's files without root explicitly transferring ownership. API
adjustments after stage 0 are proposals to A/root first; never silently change a signature and
leave the other owners to infer the change. Root is the sole editor of this plan after handoff.

### Exhaustive ownership by path

Directory scopes below include new, moved and deleted files beneath them; they are the exact
scope contract, so mechanically enumerating future test filenames is unnecessary.

**A exclusively owns:**

- `Packages/NovaAuth/Package.swift`.
- `Packages/NovaAuth/Sources/NovaAuth/API/` (all public protocols/value types/configurations/errors).
- `Packages/NovaAuth/Sources/NovaAuth/Contracts/` (internal shared model/protocol declarations).
- `Packages/NovaAuth/Sources/NovaAuth/{Wire,AppAttest,Storage,Clock,HTTP}/`.
- `Packages/NovaAuth/Sources/NovaAuth/Resources/PrivacyInfo.xcprivacy`.
- `Packages/NovaAuth/Tests/NovaAuthTests/{Wire,AppAttest,Storage,Clock,HTTP,Fixtures,TestSupport}/`.
- `Packages/NovaOperationSupport/` only if an exact existing app cancellation primitive port
  is necessary; obtain root agreement and preserve its documented semantics. Prefer a small
  NovaAuth-local cancellation registry instead of modifying support.

**B exclusively owns:**

- `Packages/NovaAuth/Sources/NovaAuth/{Lifecycle,Authorization}/`.
- `Packages/NovaAuth/Tests/NovaAuthTests/{Lifecycle,Authorization}/`; B-specific test doubles
  stay there, with unique names, instead of editing A's shared doubles.

**C exclusively owns:**

- All changes under `Packages/NovaAnalytics/`, including dependency, sources, README and tests.
- Deletion of `Packages/NovaAppAttest/`, and new `Packages/NovaAuth/README.md`.
- Replacement of `novawallet/Common/Network/Attestation/` with
  `novawallet/Common/Network/Auth/`; all changes under `Common/Network/Bittensor/` and relevant
  tests under `novawalletTests/Common/Network/{Attestation,Auth,Bittensor}/`.
- `novawallet/Common/Services/Analytics/` and matching analytics tests.
- `novawallet/Common/GlobalConfig/GlobalConfigProvider.swift` and its relevant test doubles/tests.
- `novawallet/Common/Configs/ApplicationConfigs.swift`, `novawallet/Configs/SharedContainerGroup.swift`,
  and named auth queues in `OperationManagerFacade`'s existing source file.
- `novawallet/Modules/Staking/Model/StakingSharedState/StakingSharedStateFactory+Subtensor.swift`;
  affected Subtensor factory/wiring/cache/cost-basis tests, and
  `novawalletTests/Modules/Staking/SubtensorStaking/Flows/` fixtures/harness/tests.
- `novawallet/Modules/Staking/Subtensor/Services/{SubtensorCostBasisWalk,SubtensorMaxApyWalk}.swift`
  for exhaustive handling of `generationStale`; `.swiftlint.yml` for the package exclusion rename.
- Bittensor presentation call sites only where needed to preserve seed semantics or propagate
  explicit request intent; no unrelated UI/domain changes.
- `NovaPushNotificationServiceExtension/` new auth reader composition helper only, configuration
  xcconfigs and entitlements for all four configurations, app Staging entitlement correction.
- `novawallet.xcodeproj/project.pbxproj`, affected shared schemes/test membership,
  `.github/workflows/pull_request.yml`, `.gitignore` if an explicit old package ignore needs replacement.
- `.claude/docs/architecture/{overview,services-lifecycle}.md`,
  `.claude/docs/code/{project-layout,build-and-tooling,concurrency,networking}.md`, and package/auth
  reference text found by the final residual search. Preserve historical research/migration text.
- Existing shared HTTP-cache utility/tests only if a now-unused helper can be removed without
  altering unrelated consumers; Bittensor must stop using it as its HTTP response cache.
- `Cuckoofile.toml` and generated mocks only through the existing generator if a listed protocol
  changes. Never manually edit generated mocks, R.swift outputs, CI keys or resolved versions.

If a necessary affected path is outside these scopes, report it to root for assignment rather
than treating the list as permission to edit unrelated code. Pure line-movement/membership
changes remain C's responsibility.

## Locked public contract

These are the names/signatures A scaffolds and B/C consume. Value types have explicit public
initializers where specified; stored bearer/key material is never public. Default closures
may be supplied by overloads, but do not change the core signatures. Swift language 5,
iOS 16, tools 5.9; dependencies retain Operation-iOS 2.1.2, Keystore-iOS 1.0.1,
SDKLogger 0.0.1 and local NovaOperationSupport. No async/await, actors or Combine.
The concrete class signatures below are the plan contract, not duplicate class declarations:
A does not create NovaAuth/NovaAuthReader source stubs in API. B adds those implementations
under Lifecycle. A's initial package can compile its protocols/value types without them;
full consumer compilation waits for B's implementation.

```swift
public struct NovaAuthOrigin: Hashable, Codable {
    public let value: String
    public init(_ value: String) throws
    public var url: URL { get }
}

public enum NovaAuthEnvironment: String, Codable { case development, production }
public struct NovaAuthAppIdentity {
    public let appID: String
    public let environment: NovaAuthEnvironment
    public init(appID: String, environment: NovaAuthEnvironment) throws
}

public struct NovaAuthContext: Hashable, Codable {
    public let origin: NovaAuthOrigin
    public let generation: UInt64
    // Internal initializer: callers cannot forge an admitted generation.
}

public enum NovaAuthRequestIntent { case userInitiated, background }
public enum NovaAuthMethod: String { case get = "GET", head = "HEAD", post = "POST" }
public struct NovaAuthRequest {
    public let context: NovaAuthContext
    public let method: NovaAuthMethod
    public let path: String
    public let queryItems: [URLQueryItem]
    public let body: Data?
    public let contentType: String?
    public let intent: NovaAuthRequestIntent
    public init(context: NovaAuthContext, method: NovaAuthMethod, path: String,
                queryItems: [URLQueryItem], body: Data?, contentType: String?,
                intent: NovaAuthRequestIntent) throws
}

public struct NovaAuthResponse {
    public let response: HTTPURLResponse
    public let body: Data
    public init(response: HTTPURLResponse, body: Data)
}

public protocol NovaAuthClientProtocol: AnyObject {
    var isSupported: Bool { get }
    func createAdmissionWrapper(in context: NovaAuthContext,
                                intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<Void>
    func createResponseWrapper(for request: NovaAuthRequest,
                               beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthResponse>
}

public struct NovaAuthSharedStoreConfiguration {
    public let accessGroup: String
    public let containerURL: URL
    public let hostAppNamespace: String
    public init(accessGroup: String, containerURL: URL, hostAppNamespace: String) throws
}
public struct NovaAuthConfiguration {
    public let appIdentity: NovaAuthAppIdentity
    public let settingsManager: SettingsManagerProtocol
    public let sharedStore: NovaAuthSharedStoreConfiguration
    public let ownerQueue: OperationQueue
    public let bootstrapQueue: OperationQueue
    public let requestQueue: OperationQueue
    public let logger: SDKLoggerProtocol?
    public init(appIdentity: NovaAuthAppIdentity, settingsManager: SettingsManagerProtocol,
                sharedStore: NovaAuthSharedStoreConfiguration, ownerQueue: OperationQueue,
                bootstrapQueue: OperationQueue, requestQueue: OperationQueue,
                logger: SDKLoggerProtocol?)
}

// B defines the concrete class in Lifecycle/NovaAuth.swift.
public final class NovaAuth: NovaAuthClientProtocol {
    public init(configuration: NovaAuthConfiguration)
    public var isSupported: Bool { get }
    public var currentContext: NovaAuthContext? { get }
    public func activate(origin: NovaAuthOrigin) throws -> NovaAuthContext
    public func reset() throws
    // Implements the two wrapper methods above.
}

public struct NovaAuthReaderConfiguration {
    public let origin: NovaAuthOrigin
    public let sharedStore: NovaAuthSharedStoreConfiguration
    public let requestQueue: OperationQueue
    public init(origin: NovaAuthOrigin, sharedStore: NovaAuthSharedStoreConfiguration,
                requestQueue: OperationQueue)
}
// B defines the concrete class in Lifecycle/NovaAuthReader.swift.
public final class NovaAuthReader: NovaAuthClientProtocol {
    public init(configuration: NovaAuthReaderConfiguration)
    public var isSupported: Bool { get }
    public func createContextWrapper() -> CompoundOperationWrapper<NovaAuthContext>
    // Implements the two wrapper methods above; no activate/reset/issuer API.
}
```

`isSupported` is platform/configuration capability, not consent and not a statement that a
bearer currently exists. Main construction must not touch the network, generate a key or
create an identity. Reader construction receives neither SettingsManager nor App ID/key ID/
DeviceCheck/issuer. Expose no token getters or service-specific provider constructors.

`activate` returns the existing context for the same origin. First activation initializes the
active context without registering. A different origin increments the generation, cancels and
fences old work, deletes only NovaAuth state/bearer, clears its native cache and requires a NEW
user-initiated demand for identity recreation. `reset` has the same generation/recreation
semantics while retaining the configured origin. A fresh wrapper marked `.background` cannot
recreate after reset/origin change; `.userInitiated` can. Wrappers capture their context when
constructed, so an old suspended wrapper cannot become a new demand after reset. Neither
analytics consent changes nor wallet changes call either method.

`createAdmissionWrapper` validates/obtains a usable current bearer but reveals none. It exists
so Bittensor can admit each logical fetch before domain coalescing/negative-cache decisions.
`createResponseWrapper` also performs admission, immediately before the native cache/session,
and revalidates generation, cancellation and `beforeSend` immediately before each task resume.
An earlier admission is never an exemption from the second check. All methods are thread safe.

Non-auth HTTP responses remain `NovaAuthResponse` for consumer grading, including generic
401, 400, 403, 404, 429 and 5xx. NovaAuth owns the strict invalid-token recovery and updates
cooldowns from responses. The second conclusive invalid-token fails with its typed auth error.

Public error cases in `API/NovaAuthError.swift` are fixed as:
`unsupported`, `invalidConfiguration`, `invalidRequest`, `invalidResponse`,
`credentialUnavailable`, `generationChanged`, `userActionRequired`, `storageUnavailable`,
`clockUnavailable`, `keyUnavailable`, `platformUnavailable`,
`authorizationDenied(requestID: String?)`, `cooldown(retryAfter: TimeInterval)`,
`bootstrap(NovaAuthServerError)`, `transport(URLError.Code)`, `cancelled`.
`NovaAuthServerError` exposes only `statusCode: Int`, `code: String?`, `requestID: String?`,
`retryAfter: TimeInterval?`. Never put response bodies, token values, UUIDs, proofs or generic
underlying NSError descriptions in public errors, logs, reflected descriptions or test failure
interpolation. Foundation integer JSON decoding alone is insufficient strict validation.

## Locked internal seams and models

A owns declarations; B uses them and injects fakes through an internal initializer.
Small model implementations can stay with their declaration; split files at cohesive bounds
and keep each file/type approximately below 400 lines. Do not turn the owner into a giant file.

```swift
struct NovaAuthTime: Codable, Equatable {
    let bootID: String
    let continuousSeconds: TimeInterval
}
protocol NovaAuthClockProtocol { func now() throws -> NovaAuthTime }
protocol NovaAuthRandomProtocol {
    func makeClientID() -> String          // canonical lowercase UUIDv4
    func unitInterval() -> Double          // finite 0...1
}
protocol NovaAuthAppAttestProtocol: AnyObject {
    var isSupported: Bool { get }
    func createKeyWrapper() -> CompoundOperationWrapper<String>
    func createAttestationWrapper(keyID: String, clientDataHash: Data)
        -> CompoundOperationWrapper<Data>
    func createAssertionWrapper(keyID: String, clientDataHash: Data)
        -> CompoundOperationWrapper<Data>
}
protocol NovaAuthIdentityStoreProtocol: AnyObject {
    func load() throws -> NovaAuthInstallationState?
    func save(_ state: NovaAuthInstallationState) throws
}
protocol NovaAuthTokenStoreProtocol: AnyObject {
    func load() throws -> NovaAuthTokenRecord?
    func replace(_ record: NovaAuthTokenRecord) throws
    @discardableResult func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool
    func removeAll() throws
}
protocol NovaAuthBootstrapProtocol: AnyObject {
    func createRegistrationChallengeWrapper(origin: NovaAuthOrigin, clientID: String,
                                             beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthChallenge>
    func createRegistrationWrapper(_ request: NovaAuthRegistrationRequest,
                                   beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<Void>
    func createTokenChallengeWrapper(origin: NovaAuthOrigin, clientID: String,
                                    beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthChallenge>
    func createTokenWrapper(_ request: NovaAuthTokenRequest,
                            beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthTokenResponse>
}
enum NovaAuthHTTPKind { case bootstrap, businessRead, businessPost }
protocol NovaAuthHTTPProtocol: AnyObject {
    func createResponseWrapper(for request: URLRequest, kind: NovaAuthHTTPKind,
                               beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthResponse>
    func clearReadCache()
}
```

Implementation seam correction: bootstrap operations accept `beforeSend` so generation and
cancellation are checked immediately before URLSession task resume, and token issuance start
is captured at that boundary. No-op convenience overloads may support foundation tests; the
lifecycle owner always supplies its gate. Public API is unchanged.

Additional shared declarations:

- `NovaAuthChallenge`: `challenge: String`, `issuedAt: Int64`, `expiresAt: Int64`.
- `NovaAuthTokenResponse`: `accessToken: String`, `issuedAt: Int64`, `expiresAt: Int64`;
  `Bearer` has already been validated by the wire decoder.
- `NovaAuthRegistrationRequest`: `origin`, `clientID`, `challenge` strings/typed origin,
  `appIdentity: NovaAuthAppIdentity`, `keyID: String`, `attestation: Data`,
  `contentType: String`. Its wire encoder emits exactly the iOS union, without signature.
- `NovaAuthTokenRequest`: `origin`, `clientID`, `challenge`, `assertion: Data`,
  `contentType: String`; no platform, purpose, app ID or key ID in JSON.
- `NovaAuthInstallationState`: `version: Int` (=1), `context: NovaAuthContext`,
  `requiresUserAction: Bool`, `identity: NovaAuthInstallationIdentity?`.
- `NovaAuthInstallationIdentity`: `clientID: String`, `keyID: String?`,
  `registration: NovaAuthRegistrationState`.
- `NovaAuthRegistrationAttempt`: challenge, exact content type, `clientDataHash: Data`,
  and `startedAt: NovaAuthTime`. It references its owning state's immutable context/identity.
- `NovaAuthRegistrationState`: `.unregistered`, `.appleInFlight(NovaAuthRegistrationAttempt)`,
  `.appleDeferred(NovaAuthRegistrationAttempt)`, `.registrationPending(NovaAuthTime)`,
  `.registered`, `.retired(NovaAuthRetirementReason)`.
- `NovaAuthRetirementReason`: `.lostKey`, `.unrecoverableRegistration`, `.policyRefused`.
  Policy refusal does not automatically rotate/retry; configuration correction or explicit
  reset is required. Other retirement reasons allow a new user demand, never an in-flight loop.
- `NovaAuthTokenRecord`: `version: Int` (=1), `context`, fixed `flow: String`, `clientID`,
  `accessToken`, `issuedAt`, `expiresAt`, `issuanceStart: NovaAuthTime`,
  `earlyRefreshSeconds: Int`. Compare all credential identity fields on removal.
- `NovaAuthDependencies`: internal struct grouping `appAttest`, `identityStore`, `tokenStore`,
  `clock`, `random`, `bootstrap`, `http`, `ownerQueue`, `bootstrapQueue`, `requestQueue`,
  `appIdentity` and `logger`. B supplies `init(dependencies:)` on `NovaAuth` for tests;
  production init assembles A's concrete adapters with no bootstrap side effects.
- Reader test dependencies are a separate `NovaAuthReaderDependencies` holding only origin,
  token store, clock, HTTP and request queue. No issuer or identity store, even in tests.
- `NovaAuthFraming.registrationPreimage(appIdentity:keyID:)`,
  `issuancePreimage(origin:)`, and `clientDataHash(challenge:clientID:origin:purpose:contentType:bodyDigest:)`
  throw on invalid inputs. Purpose is internal `.registration` or `.token`, mapping to exact
  path and byte; no generic arbitrary signing API. Each returns `Data`.

Concrete adapter names: `NovaAuthContinuousClock`, `NovaAuthSystemRandom`,
`NovaAuthDeviceCheckService`, `NovaAuthSettingsIdentityStore`, `NovaAuthKeychainTokenStore`,
`NovaAuthFileLock`, `NovaAuthBootstrapOperationFactory`, `NovaAuthHTTPTransport`.
Storage takes injectable Security calls and file-lock protocol in internal constructors.
Bootstrap factory takes HTTP and clock dependencies; decoder bounds are enforced before
materializing untrusted payloads. A may add private implementation helpers without changing
these cross-owner seams.

## Foundation implementation details (A)

### Wire and framing

Use the four exact bootstrap POST paths; no queries, redirects, null placeholders, alternate
profile or unknown members. Use `application/json` in production; support/test the protocol's
exact `application/json; charset=utf-8` spelling. Set one Content-Type and exact Content-Length;
bounded immutable Data body, no streaming/compression/TE/Trailer/cookies/credentials/proofs.

Strict origin validation occurs on the original string, before Foundation canonicalization can
hide a defect: exact lowercase `https`, lowercase ASCII DNS host, valid labels, at most 253
bytes, no IP/userinfo/trailing dot/path/query/fragment or explicit 443. Nonstandard valid ports
remain explicit. Validate composed business URL against the pinned origin again; query cannot
inject a new origin/fragment. Reject percent-encoded/noncanonical route aliases, dot segments,
duplicate slash and unexpected methods/bodies. GET/HEAD allow exactly the seven published
profile-3 routes (canonical UInt16 netuid); POST allows exactly the two approved existing paths.

Validate challenge 43-character canonical unpadded Base64url decoding to 32 bytes and exact
60-second lifetime. Key ID is canonical padded standard Base64, 32 bytes/44 chars. Attestation
max 49,152 bytes/65,536 chars; assertion nonempty max 6,144 bytes/8,192 chars. Encode once.
Token is nonempty opaque ASCII at most 3,072 bytes; do not split it on dots or decode claims.
Reject controls/whitespace that cannot safely occupy the single Authorization credential;
this is header-safety validation, not token claim or codec parsing.

Write a bounded strict JSON tokenizer/validator used before Codable: reject BOM, duplicate
keys, trailing content, nesting >4, invalid UTF-8, NaN/Infinity, and number lexical forms other
than JSON integers for UnixSeconds. `1.0`, `1e0`, boolean, string, overflow and negatives fail.
Validate exact top-level success response members/types and checked Int64 subtraction.
Bearer lifetime must be 60...900 seconds. Registration requires empty 204; challenge/token
requires 200. Calendar skew does not reject fresh valid responses. Error envelopes preserve
unknown code, ignore future members within `error`, and validate bounded Request-ID metadata.

Reproduce R3, T3, P3 and D3 from the research. iOS DeviceCheck receives D3 directly, exactly
once hashed; the adapter's argument is deliberately named `clientDataHash`. Copy ONLY the
`ios_registration` and `ios_issuance` vectors with provenance into
`Fixtures/profile-3-ios-vectors.json`; do not ship server root/codec material or Android code.
Assert complete preimages, digest and captured DeviceCheck input against fixture constants.

### Persistent state and security

Identity is one app-private SettingsManager blob under `novaAuth.profile3.state.v1`.
Use typed encoding, validation and read-after-write failure detection; preserve the repository's
SettingsManager convention, never direct UserDefaults or shared settings for key ID. Its
context generation survives reset even when identity is nil. Existing profile-2 UUID/key
records are not migrated into it. Cleanup may remove ONLY the exact obsolete auth setting
keys after package removal; never broad defaults/Keychain clearing or historic CoreData edits.

Bearer is one generic-password item per installed host app: dedicated service
`io.novawallet.novaauth.profile3.<hostAppNamespace>`,
account `current`, explicitly injected App Group `kSecAttrAccessGroup`, and
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Do not set synchronizable or broaden wallet
Keychain access. Scope EVERY read/add/update/delete query to class/service/account/access group.
Replace using SecItemUpdate, with narrowly handled item-not-found add; never delete-then-add.

The required validated host-app namespace is explicit build metadata shared by the main app
and its own extension. Release and Staging use distinct namespaces despite sharing an App Group;
no consumer, origin or client UUID creates another token namespace. This review correction prevents
two separately installed app variants from deleting each other's independently owned bearer.

All token-store load/replace/conditional-remove/removeAll and corrupt-record cleanup execute
inside the same short cross-process `flock` critical section at
`<appGroupContainer>/NovaAuth/profile3.lock`, in addition to safe within-process serialization.
Open with appropriate private permissions and close/unlock on every branch. Lock acquisition
is bounded; failure is `storageUnavailable`, never unlocked access. Never hold file lock across
Apple, network, operation waiting or callbacks. Conditional delete compares the record UNDER
the lock, so extension rejection of A cannot erase replacement B. Malformed-record deletion
also occurs under that same lock; unreadable/access-denied Keychain is a failure, not proof
that an item is absent. No writes can expose a memory-only credential after secure save fails.

Use `mach_continuous_time` with validated timebase conversion and actual `kern.boottime`
seconds/microseconds serialized stably. Throw on failures/nonfinite/negative values; never
fall back to Date or a launch UUID. Persist issuance start captured immediately before token
POST. Recompute `deadline = start + (expiresAt-issuedAt) - 5` after restart. Validate boot ID,
generation/origin/flow/client, future monotonic starts, arithmetic, lifetime and stored refresh
threshold. Boot mismatch/expired/corrupt record is conditionally removed, then ordinary main
issuance may proceed; reader fails. Boot-time API privacy reason 35F9.1 and SettingsManager
UserDefaults reason CA92.1 go in the package privacy manifest as applicable.

### Network primitives

Bootstrap and business sessions are distinct; neither uses automatic credentials/cookies,
redirects, request logging or automatic application retries. Reject ALL redirects including
same origin. Use per-task cancellation and bounded URLSession resource/request deadlines;
issuance/challenge 20s, registration100s. DeviceCheck error mapping distinguishes
serverUnavailable, invalid/missing key and unsupported without logging raw provider details.

Business read session owns a native URLCache and uses `.useProtocolCachePolicy` only AFTER
NovaAuth admission. Preserve server Cache-Control/Date/Age and native policy; don't synthesize
freshness, ETag or Last-Modified. Bootstrap and the two POST routes use no-cache sessions/
`.reloadIgnoringLocalCacheData`; no approved POST is cached. Reject cache admission for auth/
identity-bearing response headers or Vary on Authorization/Cookie/identity, so the cache is
public-data-only and does not vary with bearer rotation. Never add client UUID headers.

**Chosen cooldown behavior:** during protected-origin 429 cooldown, return a typed cooldown
before starting URLSession. Do this for both fresh and stale native cache entries. The contract
says fresh local cache *may* answer, so conservative refusal is permitted. Do not use
`.returnCacheDataDontLoad` as a freshness test—it may return stale data—and do not build a
second HTTP cache/freshness engine to provide this optional optimization.

## Lifecycle and authorization implementation (B)

Suggested cohesive files: `NovaAuth.swift`, `NovaAuthReader.swift`, `NovaAuthContextController.swift`,
`NovaAuthAppAttestOwner.swift`, `NovaAuthRegistrationService.swift`,
`NovaAuthRegistrationRecovery.swift`, `NovaAuthTokenProvider.swift`,
`NovaAuthTokenValidation.swift`, `NovaAuthCooldown.swift`, `NovaAuthWaiterOperation.swift`,
`NovaAuthAuthorizedOperationFactory.swift`, `NovaAuthBearerDenial.swift`.
No single file contains the entire state machine or all its test scenarios.

### Owner and cancellation

One owner mutex/generation gate serializes full key-affecting exchanges. A serial operation
queue alone is insufficient: its asynchronous orchestrator must NOT occupy the only slot
needed by its children. Use an explicit busy flight + independently cancellable waiter registry;
ownerQueue handles short transitions, bootstrapQueue runs Apple/network wrappers, requestQueue
runs business task work. Host queues are dedicated to these concerns, not the shared business
queue on which external wrappers may wait. Never wait synchronously for any child.

One flight covers registration when needed, then token challenge → D3 → assertion → token POST
→ completion/timeout → secure install. Each caller gets its own waiter operation; cancelling
one only detaches it. If all waiters leave before assertion/irreversible registration work,
cancel queued unused work. Once Apple irreversible work starts, keep its completion tracked;
once proof was sent, complete the bounded network attempt even if all waiters detach. Do not
release the gate because an outer cancelled operation reports finished. A late uncancellable
Apple callback cannot write/issue after reset: check context generation before each callback
transition, persistent write, send, install and public delivery. Reset and install share the
same process state gate; store mutations additionally use the file lock. Invoke subscriber
callbacks outside locks. Saturate request queues in tests to prove bootstrap remains runnable.

Business requests with usable tokens are never serialized by this gate. The only serialized
network work is issuance/registration for the installation key. All network hangs end under
the configured timeout. For an Apple call with no callback, a bounded local failure fences its
attempt; never reuse an ambiguously attested key or run two same-key calls after timeout.

### Registration state transitions

1. First admitted demand lazily creates/persists canonical UUIDv4, then creates a key and
   persists its validated ID before requesting/using an attestation. Preserve UUID/key on
   launch, token expiry, bearer rejection and ordinary proof error.
2. Fetch registration challenge; compute exact D3 and persist `.appleInFlight(attempt)` BEFORE
   calling `attestKey`. The attempt stores same-key retry input, monotonic start and boot.
3. On explicit Apple `serverUnavailable`, persist `.appleDeferred(attempt)`, keep UUID/key,
   apply shared bounded cooldown and fail the current demand. A later demand retries Apple
   with EXACTLY the same key AND clientDataHash. Never silently substitute a fresh challenge.
4. A successful App Attest object may be sent only for its original still-usable challenge;
   determine the local challenge limit conservatively from request start +60, using monotonic
   time, not calendar time. If Apple eventually succeeds after expiry, retire that registration
   and require a fresh UUID/key on a later user demand. While Apple keeps reporting unavailable,
   retain its key/input; do not churn registrations. Never retry an already-successful attestKey.
5. Before register send, persist `.registrationPending(start)` with the original send-start/boot.
   Keep the object only in the live attempt; never maintain a replayable disk proof queue.
   Empty204 confirms registration. Then request token challenge and issue normally.
6. Unknown register outcome/503/transport loss leaves pending state. Next attempt probes
   token-challenges, not register/attestKey. 200 permits same-key assertion and token issuance;
   only successful issuance confirms binding. `unknown_client` before 120s preserves pending
   identity and observes shared backoff; at most eight probes in that window, no timer-driven
   polling loop. After120s, unknown boot or final unrecoverable refusal, mark retired and let a
   NEW user demand create a new UUID/key. Do not recurse into registration in the failing call.
7. A crash/restart with `.appleInFlight` means the one-time Apple result is unknown. Do not
   repeat attestKey. Retire the incomplete registration for a later user demand (no server
   request could be sent before `.registrationPending` was persisted). A `.registrationPending`
   restart uses the probe path above. A `.appleDeferred` restart uses the retained exact input.
8. Missing/invalid key leads to retirement/new identity on later user demand. `invalid_proof`
   consumes that attempt and backs off without identity/counter reset. `app_not_allowed` and
   `binding_not_allowed` stop automatic bootstrap attempts, retaining any still-valid bearer
   when applicable. Never interpret a generic HTTP401 or bearer failure as registration loss.

### Token provider

Read and validate the shared CURRENT record before issuance. Persist the newly returned token
before satisfying any waiter. On arrival past its derived deadline fail the attempt once;
do not start another issuance loop. A lost token POST outcome uses a NEW challenge/assertion
on the next permitted demand; an uncertain server token may occupy a slot until expiry.

Choose `earlyRefreshSeconds = round(lifetime*0.20 + unitInterval*lifetime/15)` once and persist
it. A demand entering the window may start one shared refresh while immediately using the
current still-usable token. Refresh failure/429 does not forbid that token. An expired/rejected
token cannot bypass the cooldown. There is no idle keepalive or delayed automatic retry task.
An early-refresh flight has an explicit owner-held demand sponsor while the original caller
uses its old token; immediately delivering that caller must not accidentally detach the only
refresh waiter and cancel every early renewal before it starts. Keep this demand-bounded and
test cancellation before and after the irreversible boundary.
Only the persisted replacement is current; old in-flight request contexts may retain their
sent token solely until completion for compare-and-invalidate.

Keep issuance cooldown separate from protected-origin cooldown. Bootstrap429 honors bounded
valid Retry-After; malformed/missing values get conservative bounded backoff. For503/transport
and repeated invalid-token failure use 1,2,4,8,16,30 seconds plus0...1s jitter with saturation.
Use monotonic time; reset the corresponding failure sequence on relevant successful work.
Temporary business failures cannot erase the bearer or trigger issuer calls.

### Strict bounded recovery

Freeze original origin/method/path/query/body/content type once. For GET and approved POST,
recognize invalid_token ONLY with expected-origin HTTP401, exact Bearer invalid_token challenge
header and a valid envelope code `invalid_token`. HEAD requires status/header only and no body.
Reject ambiguous/multiple/combined authentication challenge values. Generic401, wrong-origin,
unknown/malformed envelope,403 insufficient_scope,400,429,503 and transport error never refresh.

On first conclusive denial, atomically remove the SENT record only if still current. Use a
newer usable record already installed; otherwise join/start the single issuer flight. Repeat
the original business operation at most once. A second conclusive denial conditionally removes
the retry record, enters shared backoff and fails; no third business request or second renewal.
If renewal fails, never resend the rejected bearer. On every first/retry send call `beforeSend`
immediately before task resume, after credential waits, so analytics consent can abort it.

The two POSTs have the same one-retry behavior ONLY for this conclusive pre-backend denial.
Their immutable body bytes are reused exactly. Unknown transport outcome,5xx,generic401 or
task cancellation gets no immediate POST replay. Analytics scheduling may later retry its
retained batch under existing policy; NovaAuth does not claim exactly-once server delivery.

The reader validates the same record/clock/context, permits still-usable credentials (including
the early window), and never renews. On invalid_token it conditionally removes the sent record;
it may retry once ONLY if the main app has already installed another usable record, otherwise
fails. On miss, expiry, reboot, unreadable record or stale context it sends no origin request.

## Consumer, cache and project integration (C)

### One composition identity

Replace the old holder with `NovaAuthFacade` in `Common/Network/Auth/`, whose `static let shared`
owns exactly one `NovaAuth`. It supplies `NovaAuthEndpoint { context: NovaAuthContext,
client: NovaAuthClientProtocol }` through `NovaAuthProvidingProtocol.createEndpointWrapper()`.
Both the analytics adapter and Bittensor adapter receive THIS object by injection. Tests assert
their `client` object identity with `===`; no feature factory constructs NovaAuth/AppAttest/
token stores. Remove `BackendAttestationExchangeGate` entirely. `isUnitTesting` and unsupported
capability gates occur before live endpoint requests; injectable test doubles remain usable.

Host creates dedicated named queues once: `novaAuthOwnerQueue` (short serial state work),
`novaAuthBootstrapQueue` (independently runnable children, >=2 capacity),
`novaAuthRequestQueue` (parallel business tasks). Add them to the existing operation facade.
App uses validated explicit AppIdentifierPrefix + bundle identifier, never assumed Team ID.

Resolve current GlobalConfig on every endpoint demand, rather than caching its first infra URL
forever. Add `GlobalConfigSnapshot { config: GlobalConfig, revision: UInt64 }` and
`createConfigSnapshotWrapper()` to the app's config protocol; keep existing config methods by
mapping snapshots. Publish snapshot revisions under one mutex and ignore late older fetches.
The auth facade records the latest accepted revision; a delayed old endpoint result cannot
reactivate its origin. After an accepted fresh origin update activate/fence the new context
and notify registered domain-cache invalidation callbacks. App-auth tests cover A→B, an old A
completion, already-created A request, and synchronous peeks after B publication. Config fetch
does not itself issue/register. Validate endpoint again when sending.

For explicit reset expose only the main facade's reset entry point, not analytics/feature
provider protocols. Preserve foreground demand intent through Bittensor adapters; classify
automatic refresh/scheduled work `.background`. Existing user-entered screen/explicit retry
work is `.userInitiated`. Do not label every operation user initiated merely to bypass the
post-reset gate. There is no new reset UI in this task.

### Analytics

Replace `AnalyticsAttestationProviding.swift` with `AnalyticsAuthProviding.swift` containing
`AnalyticsAuth { context: NovaAuthContext, client: NovaAuthClientProtocol }` and
`AnalyticsAuthProvidingProtocol.createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth>`.
Host `AnalyticsAuthAdapter` delegates to the same `NovaAuthFacade`; it owns no identity/token.
`AnalyticsConfiguration` replaces `attestationProvider` with `authProvider` and removes
`appAttestService`; inject `isAuthSupported: Bool` for current availability behavior. Preserve
other configuration fields and analytics consent/identity/storage protocols.

Remove exclusive exchange, signing/header closures and markUnattested. Gateway resolution
refreshes endpoint context per batch/flush instead of retaining an obsolete origin indefinitely.
Upload factory builds exact `POST /v1/analytics/events`, body once, `.background` intent and
calls shared `createResponseWrapper`. Pass a consent gate capturing the batch's epoch; check
the current consent state AND epoch immediately before each send. Withdrawal cancels only
that upload waiter and cleans analytics state; no NovaAuth reset/invalidation. Preserve50-event
batches, vetting, persistence, erasure-owed ordering, drop-on-accepted/permanent-payload-rejection,
retain-on-transient-auth/error, scheduler and `-UNITTEST` behavior. Log only safe enums/status/
bounded server code, never arbitrary underlying errors or bodies.

### Bittensor transport and domain state

Replace `BittensorAttested*` files with `BittensorAuthorizedTransport`, request builder and
response grader. Retain `BittensorApiTransportProtocol` as the domain seam; extend it to supply
an admitted context/cache scope before domain work. `BittensorApiRequest.Method` includes HEAD.
GET/HEAD uses `/v1/bittensor/profile-3` plus exact allowed suffix. Operations search uses the
existing `/v1/bittensor/operations/search`, existing sorted-key JSON and account/page validation.
Map NovaAuth failures to existing Bittensor unavailable/auth/rate-limit domain cases, preserve
request IDs and no fallback on responses. Explicitly selected debug fixture transport remains;
fixture paths/harness mirror profile3 where representing live requests. No flag disabling auth.

Reshape `BittensorApiResponseCache` into domain presentation/coalescing state, retaining its name
if that reduces unrelated call-site churn:

1. Every fetch first resolves/adopts current endpoint and completes `createAdmissionWrapper`.
   Only then may it join a domain in-flight fetch or consult endpoint-negative state. Each
   actual fetch always reaches the authorized transport/native cache. Remove the current
   immediate `.fresh` body delivery and HTTPResponseCacheStore response-reuse path.
2. Keep same-request coalescing with independent waiter cancellation. Include exact origin,
   crypto profile and auth generation in request/route/negative keys; clear on context changes.
   No result from an old context writes presentation state after invalidation.
3. Retain only already-decoded display seeds for synchronous `peek*`; label them expired/stale
   (never HTTP-fresh) and never complete a protected fetch with a seed. Preserve recommendation
   generation ordering and purge superseded generation seeds across endpoints.
4. Keep bounded route-not-published/dataset-unavailable negative entries (errors, not successful
   protected bodies). Preserve generation-aware coalescing/ordering tests. Auth admission still
   precedes these errors; negative entries never trigger re-registration.
5. Move origin429 and503/transport admission backoff to shared NovaAuth; remove the older
   competing 15...300-second auth/network backoff. Domain-only availability suppression may
   remain for actual Bittensor dataset errors. No per-service renewal or admission latch.
6. If a fetched recommendation generation is older than an already accepted generation,
   preserve the newer presentation seed and return a typed `generationStale` domain result.
   Do not add another public cache-bypass API or immediately repeat the same native cache hit.
   This deliberately replaces the old bespoke-cache retry while preserving its essential
   no-regression behavior: an older payload cannot overwrite newer accepted presentation.
   Test the error-to-presentation path so a failed fetch retains the newest seed, with correct
   stale marking and no added origin sends.

Do not change upstream freshness rules based on FULL/PARTIAL guesses: native response headers
are authoritative. No-store responses cannot become successful HTTP-cache hits. Keep raw
Cache-Control/Date/Age through transport grading, and native URLCache owns HTTP reuse.

### Extension, migration and packaging

Expose a small extension composition helper which builds `NovaAuthReader` from the SAME group/
configured origin, with no issuer/key store. No current notification handler needs Bittensor;
do not add network behavior to demonstrate the reader. Link the NovaAuth product to the
extension only as needed to compile this helper. Package role tests prove it cannot bootstrap.

Correct Staging: main app entitlement gains the production App Group selected by F_RELEASE;
extension Staging gains explicit matching entitlements/base xcconfig and F_RELEASE. Debug/Dev
use `group.novafoundation.novawallet.dev`; Staging/Release use `group.novafoundation.novawallet`.
Verify all four app/extension pairs by resolved build settings/entitlement inputs. Do not read
secrets, alter signing certificates or expand wallet groups. Signed sharing remains a device
validation item, not something unsigned simulator tests prove.

Update local package products/references/framework links and test membership in project.pbxproj,
CI package matrix NovaAppAttest→NovaAuth, package docs and architecture references. After all
consumers migrate, delete the complete old package and obsolete profile2 app/test types. Keep
the historical AppAttestBrowserSettings removal migration test and shipped model fixtures.
Firebase App Check is unrelated and remains untouched. No production/test source retains old
proof headers, old bootstrap endpoints, old signer/gate or profile2 fallback implementations.

## Requirements-to-tests matrix

Research requirement IDs are normative; grouped rows below cover every W/R/I/T/C/E/G/H item.
Use XCTest, controlled callbacks/URLProtocol, injected Security/file locking, clock/boot/random,
and expectations. No sleeps/live Apple/backend dependencies. Do not merely compare two new
helpers to one another; fixture constants and independently observed requests are oracles.

| IDs / behavior | Owner and test suite | Required evidence |
|---|---|---|
| W1-W4,W10-W12 | A `Wire/NovaAuthBootstrapTests` | Exactly four methods/paths/bodies/headers; no unknown/null union fields; empty204; correct body ceilings/content lengths; no cookies/credential bleed; strict status/shape/UTF8/duplicate/depth/number failures. |
| W5-W9,W13-W15 | A `Wire/NovaAuthValidationTests` | Full boundary table for encodings/limits/App ID/origin/ports/UnixSeconds/unknown error codes/request IDs; boolean,1.0,1e0,overflow and wrong lifetime rejected. |
| R1-R5,W14 | A `Wire/NovaAuthRouteTests`, `HTTP/NovaAuthHTTPTests` | Seven GET/HEAD routes plus exact approved POSTs; UInt16 endpoints0/65535; leading zero/sign/escape/foreign-origin/redirect rejection; no caller credential injection or GET body. |
| Exact R3/T3/P3/D3 | A `Wire/NovaAuthVectorTests` | Fixture full hex preimages and both known digests; captured DeviceCheck argument equals fixture D3; changing each context field changes/rejects framing; no double hash. |
| I1-I2,G1-G5 | B `Lifecycle/NovaAuthRegistrationTests`, `NovaAuthRegistrationRecoveryTests` | Lazy stable UUID/key; normal204; lost-success same-key probe; unknown_client120s and bounded probes; rebooted pending; same Apple key/hash after serverUnavailable; expired challenge eventual object; crash appleInFlight; no second attestKey after object; lost key/policy/invalid_proof distinctions. |
| T1-T5,I3 | A storage/clock + B `NovaAuthTokenValidationTests` | Secure exact attributes; atomic replacement; no preferences token; saved before first send; same-boot restart zero bootstrap; sleep/calendar/timezone/reboot; corrupt/future/inaccessible data; expired-on-arrival; save failure; threshold drawn once. |
| I2,C1-C5 | B `Lifecycle/NovaAuthConcurrencyTests`, A `Storage/NovaAuthTokenStoreTests` | Concurrent analytics+read misses/401s share one flight; no deadlock under saturated business queue; ordered assertions through POST completion; late401 old record preserves newer; explicit reset at every callback/write stage; actual cross-process lock/conditional-delete test where feasible, not just NSLock simulation. |
| C2-C4 | B `Lifecycle/NovaAuthCancellationTests` | Cancel queued work, one waiter, last waiter pre-assertion, Apple callback pending and post-send; no generation revival; owner retained until bounded network finish; finite hung task timeout; usable business reads parallel. |
| T6,E6-E7 | B `Lifecycle/NovaAuthCooldownTests` | Early renewal once, current usable bearer on two-token429, expired bearer fails during cooldown, exact retry delay bounds/jitter/no idle or timer loops; issuance and origin cooldowns independent. |
| E1-E5,R3-R5 | B `Authorization/NovaAuthRecoveryTests` | Exact GET/HEAD/POST invalid_token recognition; every missing/wrong signal negative; one original+one repeat only; second refusal removes only current; failed refresh never replays old token; generic401/400/403/429/503 do not refresh. |
| E2,R2,R4 | B authorized POST tests + C analytics/operations tests | Existing paths and exact immutable byte-equal bodies across permitted retry; no replay on unknown transport/5xx/cancel; consent revoked during initial admission or recovery stops next task resume. |
| H1-H2,E6,C4 | A HTTP + B authorization + C cache tests | Prepopulated fresh native cache still requires bearer admission; expired/rebooted token blocks/issues before body; Cache-Control/Date/Age/no-store preserved; fresh AND stale cache during cooldown yields zero sends; no token-dependent cache key; parallel business requests. |
| Domain preservation | C `BittensorApiResponseCacheTests`, factory/flow tests | Coalesced admitted fetches, independent cancellation, no fresh-body shortcut, stale presentation seeds, generation ordering, origin/profile/generation-separated state, old context writes ignored, negative routes, Unknown cost basis and explicit fixtures remain. |
| I3-I4,T2,C5 | B `Lifecycle/NovaAuthReaderTests`, C host/entitlement tests | Reader lacks issuer/key access; absent/expired/rebooted/read error => no bootstrap/origin send; shares persisted current bearer; old extension rejection cannot delete main replacement; four group pairs match. |
| App-wide composition | C `NovaAuthFacadeTests`, `AnalyticsAppWiringTests` and `AnalyticsFacadeFactoryTests` | `===` shared client for both consumers; parallel mixed demand one issuer; origin revisions cannot revert; reset user/background intent gate; unsupported/-UNITTEST no live setup; consent and erasure preserve shared identity/token. |
| Package replacement/privacy | C `PrivacyManifestTests` + static checks | New package app+extension compile; CI points to new suite; required-reason entries; no legacy package/import/path/header/mode; historical migration and Firebase AppCheck preserved. |
| Secret-free failures | A/B/C error/log tests | Token/key/UUID/assertion/body sentinel strings absent from public error descriptions and captured logs on all refusal paths. |

Existing suites must be migrated, not disabled: analytics uploader/request/response/consent/
identity/erasure/schedule tests; old holder/transport tests; Bittensor factory/cache tests;
Subtensor flow URLProtocol/harness/wiring/preset/cost-basis tests. Update their expected actual
bootstrap/Authorization traffic instead of replacing transport with an unconditional success.

## Validation and handoff

Root's unchanged baseline `NovaAnalytics` simulator suite passed46 tests with0 failures on
2026-10-12; log `/private/tmp/novaauth-baseline-analytics.log`. That is baseline evidence only.
Xcode26.5(17F42), iOS26.5 iPhone17Pro UUID
`A7A38DAB-F2A9-46E2-A4B8-4D0325304682` are already confirmed. Escalated simulator/build access
is necessary in this environment. Root schedules all heavy builds sequentially; other owners
do static checks and test authoring until assigned the build slot. Do not use `swift test`.

```sh
# Run from Packages/NovaAuth
RUN_IN_CI=true xcodebuild test -scheme NovaAuth \
  -destination 'platform=iOS Simulator,id=A7A38DAB-F2A9-46E2-A4B8-4D0325304682' \
  -derivedDataPath /private/tmp/dd-NovaAuth-profile3

# Run from Packages/NovaAnalytics
RUN_IN_CI=true xcodebuild test -scheme NovaAnalytics \
  -destination 'platform=iOS Simulator,id=A7A38DAB-F2A9-46E2-A4B8-4D0325304682' \
  -derivedDataPath /private/tmp/dd-NovaAnalytics-profile3

# Repository root: repeat only-testing for the migrated auth/cache/analytics/flow classes
RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj -scheme novawallet \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=A7A38DAB-F2A9-46E2-A4B8-4D0325304682' \
  -derivedDataPath /private/tmp/dd-novawallet-profile3 \
  -only-testing:novawalletTests/BittensorApiOperationFactoryTests
```

After targeted suites pass, run the full `novawalletTests` unit target (same command without
the class restriction, with `-only-testing:novawalletTests`), preserving scheme `-UNITTEST`
launch protection; this is the local equivalent of the repository fastlane unit lane. Build
app and `NovaPushNotificationServiceExtension`, inspect all four configuration entitlement/
package settings, and compile Staging as well because its sharing setup changes. Use isolated
`/private/tmp` DerivedData and save complete logs/xcresult. No live integration suite is required
for a transport-only change that does not modify chain/runtime behavior.

Run pinned SwiftLint/SwiftFormat on changed Swift files without reformatting unrelated files.
Check `git diff --check`, package/project references, generated-file cleanliness, file/type
lengths, and residual `NovaAppAttest`, `profile-2`, old bootstrap paths and proof header strings.
Allow only historical migration fixtures/research or explicit migration prose, and report the
reason for every residual production-looking hit. Avoid broad logs that could print secrets.

Completion evidence must list actual suite/build commands and outcomes, any pre-existing or
environment failures, and surviving limitations. Simulator tests do not prove real App Attest,
signed extension Keychain sharing, protected-data device behavior, physical-device reboot
continuity, or deployed backend POST authorization. Those remain named device/release checks;
never claim them passed. Backend POST rollout is an external dependency, not a reason to
preserve profile2, add a bypass or leave the iOS implementation incomplete.

## Review acceptance and maintainability

The implementation is ready for review when package and consumer behavior above is covered,
the old package is removed, and app/extension builds and required suites have real evidence.
Reviewers should focus on reachable failures, race interleavings, wire mismatches and missing
tests—not revisit the accepted backend architecture. Discuss each candidate finding with its
original owner; keep rejected findings and rationale in the review handoff. Fresh fixers own
only surviving findings. Root performs the final integration checks after fixes.

The resulting architecture has an app-owned singleton at the composition boundary, package
interfaces free of app types, operation-based asynchronous work, explicit role capabilities,
and domain code free of key/token lifecycle state. This follows the repository's dependency
direction and avoids speculative abstractions. Preserve concise cohesive files and typed
errors; the complexity belongs in tested lifecycle transitions, not consumer factories.

## Execution record — 2026-10-12

Research, planning, implementation, independent review with implementer discussion, and
separate fixes were completed by the requested Astra Extra High agents. All seven confirmed
findings were fixed and verified: persisted pending-registration recovery limits, file-metadata
privacy disclosure, reset before activation, permanent analytics payload rejection, per-demand
user intent, derived-cache context fencing, and host-app Keychain namespace isolation.

The final wiring regression verifies that background and interactive factory views share the
same auth client, transport and cache, with exactly one registration, assertion and token POST.

| Final check | Result |
|---|---|
| NovaAuth simulator suite | 107 tests passed. |
| NovaAnalytics simulator suite | 50 tests passed. |
| Targeted app integration | 117 tests passed after review fixes; all four final wiring tests also passed after strengthening shared-owner assertions. |
| Full app unit suite | 1,368 tests executed twice after the wiring fix. Each run had one failure in an unchanged Gifts test; all migration tests passed. |
| Debug app and extension | Built successfully; both contain the expected host namespace and all three NovaAuth required-reason privacy declarations. |
| Staging app and extension | Apple Silicon simulator build passed with `ONLY_ACTIVE_ARCH=YES`; both built products contain the correct host namespace and all three privacy declarations. |
| All four build configurations | Resolved app/extension namespaces, App Groups and compilation flags match. Staging and Release have separate credential namespaces. |
| Static checks | Pinned SwiftFormat passed for 138 changed Swift files. Pinned SwiftLint passed for 85 production files with four warnings and no errors. Diff checks passed; generated files and dependency pins are unchanged. |

The unrelated Gifts failures are an existing race in `GiftsSyncServiceTests` at lines 212 and
229: `setup()` asynchronously enqueues the subscription's initial repository fetch onto the
same queue whose operation count the tests compare. That fetch can arrive between the two
measurements even though the status callback creates no save. The line-229 test passed nine
of ten isolated repetitions. Its test, service, subscription helper, repository doubles and
dependency lockfile are unchanged from the baseline. No Gifts source or tests were modified.

The initial Staging simulator build attempted both arm64 and x86_64. Its Intel extension link
failed because the existing pinned `libsr25519c.a` and `hydra_dx.framework` simulator artifacts
contain only arm64; `lipo -info` confirmed both architectures. The native-simulator build uses
the same project and configuration with the command-line override `ONLY_ACTIVE_ARCH=YES`.
No dependency, project architecture setting or optimization setting was changed.

The implementation remains subject to the documented backend authorization rollout for the
two POST endpoints and physical-device validation of live App Attest, signed extension
Keychain sharing, protected data and reboot behavior. The contract-mandated `kern.boottime`
calendar-correction limitation is documented in `Packages/NovaAuth/README.md`.

Changes are retained on local child branch `feature/nova-auth` in separate package,
integration and documentation commits. Do not push this branch without a new user request.
