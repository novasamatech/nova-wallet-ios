# NovaAuth — client architecture

These diagrams describe the Swift client. “Backend” is only the HTTPS peer that the client calls; its internal behavior and deployed permissions are outside this document.

**Reading order:** ownership → first authentication → proof construction → registration recovery → token reuse/concurrency → protected requests → storage/replacement → analytics.

**Reading order:** ownership → first authentication → proof construction → registration recovery → token reuse/concurrency → protected requests → storage/reset → Bittensor → analytics.
The central invariant is **one main-app NovaAuth owner, one installation identity, and one current persisted bearer for the active backend context**. Bittensor and analytics receive the same client. Requests already in flight can still hold the preceding valid bearer during refresh. Wallet accounts do not supply authentication keys.

## 1. Ownership and app composition

The facade is the app’s composition boundary. It creates the package owner once, resolves the current backend, and exposes an endpoint containing **the shared client + `(origin, generation)` context**. Activation establishes context; the first credential demand starts authentication.

```mermaid
flowchart TB
  subgraph APP["Main iOS app"]
    ROOT["RootInteractor.setup()"] --> AF["AnalyticsServiceFacade<br/>injected via factory createDefault()"]
    AF --> AA["AnalyticsAuthAdapter"]
    BT["BittensorApiOperationFactory"] --> TR["BittensorAuthorizedTransport.shared"]
    AA --> F["NovaAuthFacade.shared<br/>one endpoint: client + context"]
    TR --> F
    CONFIG["GlobalConfigProvider<br/>revision + infraUrl"] --> F
    HOST["App identity + Keychain access group / host namespace<br/>SettingsManager set/read-back + three queues"] --> F
  end
  subgraph PACKAGE["Packages / NovaAuth"]
    F --> OWNER["ONE NovaAuth owner<br/>installation + issuance coordination"]
    OWNER --> APPLE["DeviceCheck adapter"]
    OWNER --> STATE["Settings identity store"]
    OWNER --> TOKEN["Shared Keychain token store"]
    OWNER --> HTTP["HTTP transport<br/>bootstrap / reads / POSTs"]
  end
  HTTP --> BACKEND["Configured HTTPS backend"]
  APPLE --> OS["DCAppAttestService"]
  subgraph EXT["Extension capability"]
    FACT["NovaAuthReaderFactory<br/>no production call site"] -.-> READER["NovaAuthReader<br/>cannot issue tokens"]
  end
  READER -. "loads same record" .-> TOKEN
```

- Root starts analytics before wallet setup. There is no `ServiceCoordinator → NovaAuth.setup` path; authentication is driven by consumer requests.
- The facade rejects unsupported App Attest, missing app identity, and real-client creation under `-UNITTEST`.
- Auth stores the bearer in the app's default Keychain access group; it requires no App Group container, shared access group or Info.plist namespace. Other host features still use the App Group container.
- Settings writes use the injected manager and verify cached read-back. The production manager calls synchronize internally, but neither operation proves durability or detects every refused disk write.
- `infraUrl` may have an empty path or a single root `/`; the facade converts it into a strict HTTPS origin. Credentials, query, fragment and non-root paths are rejected. The accepted endpoint is memoised for the process.
- `appID` is App Identifier Prefix + bundle ID. `F_DEV` selects the development App Attest environment; other builds select production. This is distinct from wallet identity.
- Package code depends on Operation-iOS, NovaOperationSupport, Keystore-iOS and SDKLogger, with Apple platform adapters. It does not depend on app types.

Sources: [facade and composition](../../../novawallet/Common/Network/Auth/NovaAuthFacade.swift) · [configuration conversion](../../../novawallet/Common/Network/Auth/NovaAuthFacade.swift) · [Root startup](../../../novawallet/Modules/Root/RootInteractor.swift) · [app identity](../../../novawallet/Common/Configs/ApplicationConfig+NovaAuth.swift) · [owner construction](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuth.swift) · [package dependencies](../../../Packages/NovaAuth/Package.swift) · [settings storage](../../../Packages/NovaAuth/Sources/NovaAuth/API/NovaAuthConfiguration.swift)

## 2. First authentication and subsequent issuance

This is the successful path for a new installation. All four backend calls are POSTs under `/v1/attestation/profile-3/`, with no bearer attached. Registration and token issuance are separate phases in the same coordinated flight.

```mermaid
sequenceDiagram
  autonumber
  participant C as Bittensor or analytics
  participant N as NovaAuth owner
  participant S as Persistent stores
  participant A as Apple DeviceCheck
  participant H as HTTPS backend
  C->>N: Demand credential for context + intent
  N->>S: Save client UUID, unregistered identity
  N->>A: generateKey()
  A-->>N: keyID
  N->>S: Save key reference
  N->>H: POST challenges — purpose register
  H-->>N: challenge + timestamps
  N->>N: Build registration clientDataHash
  N->>N: Check same boot and age 0...40 s
  N->>S: Save appleInFlight + exact attempt
  N->>A: Acquire lease and run beforeAttest guard
  A->>N: Recheck current flight, context and age 0...40 s
  N->>A: attestKey(keyID, hash)
  A-->>N: attestation object
  N->>N: Validate size, same boot, age below 60 s
  N->>S: Save registrationPending before send
  N->>H: POST register — identity + attestation
  H-->>N: 204, empty body
  N->>S: Save registered
  Note over N,H: Existing registered identity starts here on renewal
  N->>N: Busy key? Fail locally before token challenge
  N->>H: POST token-challenges — purpose token
  H-->>N: challenge + timestamps
  N->>N: Build issuance clientDataHash
  N->>A: generateAssertion(keyID, hash)
  A-->>N: assertion
  N->>N: Capture continuous-clock send time
  N->>H: POST tokens — clientID + challenge + assertion
  H-->>N: Bearer string + issued_at + expires_at
  N->>S: Save registered, replace current Keychain record
  N->>S: Clear recovery delays and background count
  N-->>C: Admission completes / authorized exchange proceeds
```

The caller never gets a newly issued bearer before the Keychain write succeeds. The package treats the bearer as an opaque validated string; it does not decode claims. Challenge responses must describe a 60-second lifetime. Bearer responses must describe a lifetime of 60–900 seconds.

Apple attestation/assertion wrappers have a bounded timeout of up to 100 seconds. Once a native call begins, timeout/cancellation does not release its per-key lease: only Apple's actual callback does. A different key can proceed independently. Issuance checks `isBusy(keyID:)` before creating a token challenge, avoiding network traffic while the key is leased. The registration HTTP request allows 100 seconds; the other HTTP requests allow 20 seconds.

Registration age starts before the challenge request. The early check requires the same boot and `0 <= age <= 40`, choosing a minimum 20-second margin on the 60-second challenge. Exactly 40 seconds passes; at 40.001 a deferred attempt keeps its key and takes a fresh challenge in the same flight, while a fresh attempt falls back to unregistered with the same key and fails the current operation. After Apple's result, same boot and `0 <= age < 60` remain authoritative: the 100-second local timeout means the margin cannot guarantee completion in time.

The early check runs before saving `appleInFlight` and building the wrapper. After acquiring the proof lease, the adapter invokes `beforeAttest` immediately before native `attestKey`; under the owner gate, this guard rechecks the current flight, context and the same inclusive 40-second budget. Queue delay therefore cannot use an earlier successful check to start an expired native attempt. Guard failure releases the **unused** lease without invoking Apple. The fenced completion drops the key of an age-expired current attempt once, keeping the client UUID; a detached/stale flight cannot mutate a replacement context. After invocation the lease is **called** and only Apple's callback releases it, never a local timer.

Sources: [registration service](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift) · [issuance and persistent installation](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) · [bootstrap endpoints](../../../Packages/NovaAuth/Sources/NovaAuth/HTTP/NovaAuthBootstrapOperationFactory.swift) · [response validation](../../../Packages/NovaAuth/Sources/NovaAuth/Wire/NovaAuthWire.swift) · [Apple adapter](../../../Packages/NovaAuth/Sources/NovaAuth/AppAttest/NovaAuthDeviceCheckService.swift) · [early and post-Apple age checks](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift) · [bearer installation](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) · [native execution guard](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift) · [unused lease release and native invocation](../../../Packages/NovaAuth/Sources/NovaAuth/AppAttest/NovaAuthDeviceCheckService.swift)

## 3. What the App Attest proof binds

Registration and issuance use different semantic commitments. Each commitment is hashed and included in an outer frame that binds the challenge to the exact bootstrap request. Ordinary Bittensor and analytics requests carry the bearer; they do not get an App Attest assertion for each business payload.

```mermaid
flowchart TB
  R["Registration commitment<br/>NOVA-REGISTRATION + version 3<br/>ios, appID, app_attest, keyID, environment"] --> RH["SHA-256 → bodyDigest"]
  T["Fresh challenge / assertion per issuance attempt<br/>NOVA-TOKEN-ISSUANCE + version 3 / marker 1<br/>canonical origin + bittensor-read"] --> TH["SHA-256 → bodyDigest"]
  RH --> FRAME["Outer NOVA-ATTESTATION frame<br/>version + purpose<br/>challenge + clientID<br/>POST + https + authority + effective port<br/>register or tokens path + content type<br/>bodyDigest"]
  TH --> FRAME
  FRAME --> HASH["SHA-256 → 32-byte clientDataHash"]
  HASH --> REG["attestKey<br/>registration proof"]
  HASH --> ASSERT["generateAssertion<br/>issuance proof"]
  REG --> RJSON["Registration JSON<br/>integrity_token = Base64 attestation"]
  ASSERT --> TJSON["Token JSON<br/>app_attest_assertion = Base64 assertion"]
```

- Text fields are ASCII with a 32-bit big-endian length prefix; domains have explicit NUL/version bytes. The semantic commitment is not a hash of the final JSON body containing the proof.
- `clientID` is a random installation UUID. `keyID` identifies the DeviceCheck-managed key. `appID` identifies the signed app. The context’s `generation` is a local invalidation fence; it is not included in these wire commitments.
- Issuance binds the canonical origin and API major 1. The bearer has no flow/scope; ordinary protected reads and POSTs share it. Renewal always obtains a fresh challenge/assertion; no refresh credential exists.
- `invalid_proof` at `/tokens` retains the key and assertion-counter continuity, fails the operation and retains short auth backoff before a later fresh challenge/assertion. An Apple-deferred registration instead retries the exact saved key/hash within the original age window.
- The source literally uses **`bittensor-read`** in issuance framing and token-record validation, even though the same bearer is attached to analytics and operations-search POSTs. This describes the client implementation; it does not establish which routes a deployed server accepts.

Sources: [exact binary framing](../../../Packages/NovaAuth/Sources/NovaAuth/Wire/NovaAuthFraming.swift) · [JSON fields](../../../Packages/NovaAuth/Sources/NovaAuth/Wire/NovaAuthWire.swift) · [identity types](../../../Packages/NovaAuth/Sources/NovaAuth/API/NovaAuthIdentity.swift) · [credential validation](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenValidation.swift) · [fresh proof retry classification](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift)

## 4. Persisted registration state and recovery

```mermaid
flowchart TB
  U["unregistered"] --> A["appleInFlight"]
  A -- "serverUnavailable: exact saved attempt" --> D["appleDeferred"]
  D -- "Same boot; age at most 40 s" --> A
  D -- "Budget expired: same key, fresh challenge" --> U
  A -- "Valid attestation; persist before send" --> P["registrationPending"]
  P -- "Register 204 or successful bearer installation" --> R["registered"]
  A -- "Invalid key" --> X["retired; current flight fails"]
  A -- "Interrupted, failed or stale attestation" --> G["key dropped; UUID kept"]
  G --> U
  P -- "Confirmed absence or 409" --> X
  P -- "Any other code-bearing 4xx verdict" --> F["key dropped; UUID kept; refusal delay saved"]
  F -- "User-driven demand, or background demand past the delay" --> U
  R -- "Invalid key or 401 unknown_client" --> X
  X -- "Invalid key at assertion: same flight" --> K["At most one fresh UUID/key in this flight"]
  X -- "Later independent demand; short backoff" --> K
  K --> U
  P -- "Inconclusive failure / unknown within 120 s" --> P
  R -- "401 invalid_proof" --> R
  R -- "403 binding_not_allowed: refusal delay saved, key kept" --> R
```

Retirement fails the current caller operation, except that a key found invalid at assertion time is
replaced by one fresh UUID/key within the same flight; no proof is resent and a flight never generates a
second key. Otherwise a later independently created demand may replace after short backoff. Concurrency joins one
issuance flight. There is no lifetime replacement quota; the only intent privilege is that user-driven
demands re-register at once after a refusal while background demands wait for the persisted
1 h / 6 h / 24 h delay, which resets on an app version or context change.

Pending probes preserve UUID/key/start and reserve persisted backoff before sending. A same-boot
token-challenge/issuance `401 unknown_client` before 120 seconds keeps pending state and fails. Outside that window or after
boot discontinuity, conclusive absence retires and fails. Transport/503 alone never prove absence.
There is no unknown-response counter. An intermediate token challenge preserves pending state and its
original window until successful bearer installation. A registered binding receiving conclusive
`401 unknown_client` at either token challenge or issuance retires and fails this flight.

A token-time `403 binding_not_allowed` additionally saves the refusal delay: background demands
wait for it while user-driven demands retry at once. Token `401 invalid_proof` and token challenge/issuance `403 binding_not_allowed` preserve the same
registered UUID/key/counter. Later operations obtain a fresh challenge; no proof is reused and no
key rotates to bypass policy. Status and code are considered together: `503 invalid_proof` is
availability failure. Stored retired states wait for later demand replacement and keep the refusal counter; legacy `policyRefused` keeps the client UUID and attests a fresh key.

Host activation, including accepted origin adoption and legacy-reset repair, authorizes demand-driven
bootstrap, including consented Analytics. It creates no key/request by itself. **This local lifecycle
policy replaces the profile-3 protocol's user-driven re-creation wording.**
The package exposes no reset API. Removed optional legacy quota/gate/delay fields are ignored.

Sources: [state](../../../Packages/NovaAuth/Sources/NovaAuth/Contracts/NovaAuthModels.swift) · [registration](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRegistrationService.swift) · [pending backoff](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthPendingRecovery.swift) · [retirement](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthRecoveryService.swift)

## 5. Token reuse, refresh and concurrency

Every admission consults the shared current record. Consumers wait on the same issuance flight when there is no usable bearer. When the bearer remains usable, a request can proceed immediately while an early refresh runs alongside it.

```mermaid
flowchart TB
  D["Credential demand<br/>context + ordinary protected request + waiter"] --> G["Owner queue + state lock<br/>check cancellation, generation, support, clock"]
  G --> VALID{"Current stored bearer usable?"}
  VALID -- yes --> RETURN["Return existing record immediately"]
  VALID -- no --> FL{"Any issuance flight exists?"}
  FL -- yes --> MATCH{"Flight context matches?"}
  MATCH -- no --> FAIL["Return typed error to this caller"]
  MATCH -- yes --> JOIN["Attach this waiter"]
  FL -- no --> IC["Check origin then issuance cooldown<br/>then pending cooldown<br/>Prepare installation identity"]
  IC -- error --> FAIL
  IC -- allowed --> START["Start one issuance flight"]
  JOIN --> DONE["Complete shared flight<br/>success: persisted token, then delivery<br/>failure: applicable backoff, then error"]
  START --> DONE
  RETURN -. "Near expiry + no flight + registered" .-> EARLY["Start sponsored early refresh<br/>only if origin / issuance waits allow"]
  EARLY --> DONE
```

**Validity:** matching version/context/clientID; no local rejection fingerprint; valid opaque token syntax; same boot; consistent monotonic timestamps; server lifetime 60–900 seconds. The effective deadline is:

`local token-POST send time + (expires_at − issued_at) − 5 seconds`

Early refresh begins on demand when effective remaining time reaches a stored, randomized threshold of approximately **20–26.67% of the original lifetime**. There is no scheduled refresh timer. Main-owner admission returns a valid bearer before origin, issuance, recovery or pending waits; refresh respects its applicable waits. Without a valid bearer, an existing flight is joined before starting a new one. Business sending separately checks shared-origin cooldowns, even when admission already returned a bearer.

Ordinary issuance Retry-After is in memory and restarting the owner loses that delay: this is an accepted limitation. Pending-registration probe cooldown is persisted. Boot discontinuity ends boot-scoped waits; no replacement quota or optional long-delay ladder survives.

| Execution lane | Responsibility |
| --- | --- |
| Feature queues | Compose wrappers and await results without blocking the owner’s work. |
| `nova.auth.owner` · serial | Credential demand, issuance coordination, state transitions and delivery; state also guarded by `NSLock`. |
| `nova.auth.bootstrap` · maximum 4 operations | Independently runnable Apple and bootstrap HTTP child operations. One logical issuance flight is coordinated above this queue. |
| `nova.auth.requests` · default concurrency | Parallel protected business requests. |
| Analytics persistence queue · serial | Event enqueue/trim/count and erasure; upload peek/drop execute on the configured general upload queue. |

Cancelling a consumer removes only its waiter. The last waiter cancels an issuance child only when the flight is **neither sponsored nor irreversible**. Irreversibility begins before Apple attestation or assertion. A cancelled analytics upload therefore does not abort another consumer’s issuance. Origin replacement detaches the old flight immediately; its late callback cannot affect the new context. Platform calls already started cannot be cancelled at the Apple API level; wrappers settle once, but the same key stays reserved until the actual callback. If Apple never calls back, that key remains busy until process restart.

`issue()` fails locally on a busy key before creating the token-challenge wrapper. It does not release a lease on a timer or consume another native attempt while the first call remains active.

Sources: [demand and token loading](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) · [early refresh and cancellation](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) · [validity checks](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenValidation.swift) · [queue composition](../../../novawallet/Common/Operation/OperationManagerFacade.swift) · [child scheduling and delivery](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuth.swift) · [busy-key short-circuit](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthTokenProvider.swift) · [issuance and pending backoff](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuthPendingRecovery.swift)

## 6. Protected requests, HTTP cache and bounded renewal

```mermaid
flowchart TB
  D["Immutable protected request"] --> A["Demand/join credential"]
  A --> F["Context + token + origin protection; caller beforeSend"]
  F --> S["Actual send"]
  S --> R{"Expected-origin 401 invalid_token?"}
  R -- "First denial only" --> N["Reject token; renew same binding with fresh proof"]
  N --> F
  R -- "Second denial" --> E["Fail authorizationDenied"]
  R -- "Other response" --> C["Return to caller grading/retry policy"]
```

NovaAuth has no HTTP cache.

Conclusive replay requires the exact expected HTTPS origin, status 401 and exact
`WWW-Authenticate: Bearer error="invalid_token"`; GET/POST also need a valid invalid-token body,
while HEAD has no body. Maximum one bearer replay preserves method/path/query/body bytes.
A credential rejected before an unsent request permits one bounded readmission. Each readmission
preserves the original client binding; retirement fails the original operation. The caller's
consent/cancellation guard runs before every actual send, including replay.

Only 429 (Retry-After or fallback 30 seconds) and explicit `503 attestation_unavailable` apply shared
auth-origin protection. Other business 5xx/transport failures pass to domain handling. Generic
business success does not clear a shared deadline. Short auth backoff is 1/2/4/8/16/30 seconds plus
up to one second of jitter; Retry-After is clamped to 1–905 seconds. Nothing schedules an auth retry.

Sources: [exchange](../../../Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuthAuthorizedOperationFactory.swift) · [send fences and protection](../../../Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuth+Authorization.swift) · [denial](../../../Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuthBearerDenial.swift)

## 7. Persistence and origin replacement

```mermaid
flowchart TB
  H["Host accepts new origin / repairs legacy reset"] --> M["Advance memory context fence"]
  M --> F["Detach old flight; clear old cache"]
  F --> P["Stage installation write + owed token deletion"]
  P --> O{"Storage repair succeeds?"}
  O -- "No" --> B["Block admission; keep new fence and repair obligations"]
  B -- "Next demand or activation" --> P
  O -- "Yes" --> D["Eligible context; later demand may authenticate"]
```

Settings keeps the current installation storage key/version, context, UUID/key/registration, exact
saved attestation attempt, pending start/cooldown and token-removal debt. Removed optional legacy
fields are ignored even when malformed; surviving security fields remain validated. The next
existing write encodes the reduced schema. A saved refusal delay survives relaunch and resets on an app
version or context change.

State adoption happens before I/O. A failed write never rolls back the active memory fence; staged
write and token deletion retry during activation or the next demand and block admission until repaired. Reset/corrupt
repair cannot adopt an old bearer. Settings read-back observes a manager cache and cannot prove
disk durability; no transaction/commit API is implied.

Keychain contains one atomic version-2 bearer with origin/client/generation and boot-bound continuous
deadline. Persistence precedes delivery. Conditional fingerprint deletion cannot erase a newer
record; the sole owner under its gate may remove an untagged legacy record only after reload still
matches. Corrupt token reads do not delete data. The default access group separates signed app variants, and the owner caches the loaded record under its gate.

The session's request/resource timeouts, the 110-second HTTP operation watchdog and the native watchdog remain. Called native leases release only on actual callback, even after
local timeout. The flight's irreversible commitment stays sticky independently of its current step.
Failure-only logs are asynchronous: fixed step/category, numeric status, allowlisted code and
sanitized correlation ID. Tokens, IDs, proofs, bodies and arbitrary Error/state are never logged.

Sources: [owner and repair](../../../Packages/NovaAuth/Sources/NovaAuth/Lifecycle/NovaAuth.swift) · [settings](../../../Packages/NovaAuth/Sources/NovaAuth/Storage/NovaAuthSettingsIdentityStore.swift) · [Keychain](../../../Packages/NovaAuth/Sources/NovaAuth/Storage/NovaAuthKeychainTokenStore.swift) · [redacted failures](../../../Packages/NovaAuth/Sources/NovaAuth/Authorization/NovaAuthDiagnostics.swift)

## 8. Analytics: shared authentication, separate consent and data
| Uncoded 502/503/504, other 5xx, and coded domain 5xx except the explicit shared case | Analytics or Bittensor family only. |
| GET / HEAD | `/v1/bittensor/profile-3/subnets` |
| GET / HEAD | `/v1/bittensor/profile-3/subnets/{netuid}/validators` |
| GET / HEAD | `/v1/bittensor/profile-3/yields/root` |
| GET / HEAD | `/v1/bittensor/profile-3/subnets/{netuid}/yields/alpha` |
| GET / HEAD | `/v1/bittensor/profile-3/recommendations` |
| GET / HEAD | `/v1/bittensor/profile-3/recommendations/subnets` |
| GET / HEAD | `/v1/bittensor/profile-3/recommendations/subnets/{netuid}/validators` |
| POST · JSON | `/v1/bittensor/operations/search` |
`netuid` must be canonical UInt16 text. GET/HEAD are package capabilities; the current Bittensor factory calls GET. Its current factory also does not expose the per-subnet recommendation-validators route. The table shows the package allowlist, not a claim that every route has an active caller.
**Separately owned server migration:** release coordination must confirm that both existing POST paths accept this same profile-3 `bittensor-read` bearer and that `invalid_token` is rejected **before either POST reaches its business handler**. This pre-handler contract permits the single replay of identical bytes. The client predicate cannot establish deployed server ordering. There is no legacy fallback or client backend migration here.

```mermaid
flowchart TB
  C["Consent enabled; normal session/track/flush"] --> Q["Persist batch under consent epoch"]
  Q --> A["NovaAuthFacade resolves the shared endpoint"]
  A --> N["NovaAuth decorates immutable analytics POST"]
  N --> G{"Consent + epoch valid before actual send?"}
  G -- "No" --> X["Stop upload"]
  G -- "Yes; also before replay" --> S["Send /v1/analytics/events"]
  S --> R{"Result"}
  R -- "Success or permanent payload refusal" --> D["Drop batch rows"]
  R -- "Auth / transient failure" --> K["Keep rows silently for normal later flush"]
  W["Consent withdrawal"] --> E["Persist erasure debt; cancel waiter; erase analytics data"]
```

Analytics owns consent, epoch/session, its content install identifier and persistent event queue.
These are separate from NovaAuth's installation UUID, key and bearer. Withdrawal and wallet changes
do not reset authentication. Consent enablement retains normal session start and tracking; there is
no separate admission/re-arm helper. Saved consent may permit ordinary later uploads after host
activation under the explicitly changed lifecycle policy in view 4.

Every upload checks current consent/epoch immediately before send; NovaAuth repeats that guard
before its single authorized replay. Auth failures retain batches silently for the existing later-flush
policy. No auth prompt, dialog or analytics notification is produced. Background flush sends at most
one batch; other flushes at most ten, with fifty-event batches and existing payload rejection rules.

Sources: [facade](../../../Packages/NovaAnalytics/Sources/NovaAnalytics/AnalyticsServiceFacade.swift) · [uploader](../../../Packages/NovaAnalytics/Sources/NovaAnalytics/AnalyticsUploader.swift) · [upload operation](../../../Packages/NovaAnalytics/Sources/NovaAnalytics/Network/AnalyticsUploadOperationFactory.swift)
5. Facade reset always notifies context observers, including on failure. Adoption compares the package invalidation ID around activation and also notifies on a failed replacement/repair if the memory fence changed. This works before the facade has published its first endpoint: cold origin replacement discards pending consent events and old Bittensor state. A later user-initiated demand can establish the next identity.
## 8. Bittensor: admission, two cache layers and presentation
Bittensor adds domain request sharing, decoded display seeds and typed error handling around NovaAuth. Its decoded cache never substitutes for native HTTP freshness. On-chain balances and chain enrichment use the chain connection separately from NovaAuth.
```mermaid
sequenceDiagram
  participant UI as Interactor /<br/>domain service
  participant F as Bittensor<br/>operation factory
  participant C as Decoded<br/>response cache
  participant T as Authorized<br/>transport
  participant N as Shared<br/>NovaAuth
  participant H as HTTP cache /<br/>backend
  UI->>F: Optional synchronous peek
  F->>C: Read seed with latest<br/>invalidation revision
  C-->>UI: Expired seed only, via factory
  UI->>F: Request with user/background intent
  F->>C: Create job: admit + fetch
  C->>T: Admit first
  T->>N: Resolve context,<br/>demand credential
  N-->>T: Admission succeeds
  T-->>C: Auth scope + shared endpoint<br/>with immutable invalidation revision
  C->>C: Reconcile invalidation floor<br/>then check negatives / join flight
  opt No negative result and no existing flight
    C->>T: Fetch with<br/>admitted endpoint
    T->>N: createResponseWrapper(request)
    N->>N: Demand again +<br/>pre-send fences
    N->>H: Authorized GET or<br/>operations-search POST
    H-->>N: Response, possibly native<br/>cache / revalidation
    N-->>T: Response or<br/>typed auth error
    T-->>C: HTTP grading + factory<br/>decode / wire validation
    C->>C: Reconcile invalidation floor,<br/>auth scope and dataset generation
  end
  C-->>UI: Result/error via factory and domain service
  Note over T,UI: bindingConflict / invalidRequest: generic, no retry<br/>attestationRejected: device-bound, no retry
  UI->>UI: Combine chain data,<br/>update Presenter on main
```
- Auth admission precedes negative-cache lookup and joining a request flight. Synchronous `peek` is only a stale display seed and makes no authentication request.
- Decoded cache keys include auth scope plus method/path/query/body digest. Route-unpublished negatives last 600 seconds; dataset-unavailable negatives last 60 seconds. There is no successful-response TTL shortcut here.
- Recommendation dataset ordering uses `(asOf, sourceBlockNumber)`. It is distinct from the authentication generation. An older dataset response returns `generationStale` without overwriting the newer seed.
- The facade stamps accepted endpoints with an invalidation revision; transport preserves it in each admission. The decoded cache reconciles the latest revision before admission, completion and peek. Delayed or duplicate notifications cannot retire current-revision state; old admissions and completions cannot restore retired results. Same-origin readiness does not advance this invalidation revision. Separate context observers invalidate max-APY resolution, cost-basis histories and validator directories, including cold replacement or failed reset/replacement after the memory fence changes.
- Cost basis/P&L reads **`POST /v1/bittensor/operations/search`** and computes the ledger locally. It is a history read, not transaction submission.
- Screen entry and explicit catalogue refresh carry user intent; automatic portfolio changes, pricing, cost-basis and max-APY work carry background intent. `withIntent` shares the same transport and cache.
- Errors are graded into Bittensor types. Raw network and malformed-protocol failures retain retryable availability meaning; generic business 401/403 are server errors after the scope-specific case below. Presentation depends on the consumer: portfolio catalogue failure supplies no catalogue and can show rates unavailable; validator flows use the typed device/retry properties. Live chain balances do not prove successful backend authentication.
| Response/error | Bittensor type | Device-bound | User retry |
| --- | --- | --- | --- |
| Bootstrap `401 attestation_failed` | `attestationRejected` | Yes | No |
| `409 client_already_registered`, bootstrap or business | `bindingConflict` | No | No |
| `403 insufficient_scope`, bootstrap or business | `invalidRequest` (generic presentation) | No | No |
| Bootstrap `401 invalid_challenge` or 503 | `attestationUnavailable` | No | Yes |
| Transport failure | `transport` | No | Yes |
These presentation mappings are separate from NovaAuth cooldown scope. For example, the Bittensor grader maps uncoded business 5xx to `attestationUnavailable`, while NovaAuth shares only uncoded 500; uncoded 502/503/504 remain family-scoped as in view 6.
The max-APY walk stops on registration refusal, binding conflict, final authorization denial, unsupported device, configuration failure or authentication backoff. It propagates that error without an outer retry or a successful partial result, so the one-hour result cache remains empty. Ordinary route/data gaps can still skip a target, and transient failures keep their bounded retry policy.
Sources: [shared domain composition](../../../novawallet/Modules/Staking/Model/StakingSharedState/StakingSharedStateFactory+Subtensor.swift) · [transport admission and send](../../../novawallet/Common/Network/Bittensor/Transport/BittensorAuthorizedTransport.swift) · [factory and decoding](../../../novawallet/Common/Network/Bittensor/BittensorApiOperationFactory.swift) · [decoded cache](../../../novawallet/Common/Network/Bittensor/BittensorApiResponseCache.swift) · [HTTP/auth error grading](../../../novawallet/Common/Network/Bittensor/Transport/BittensorAuthorizedResponseGrader.swift) · [portfolio refresh/failure](../../../novawallet/Modules/Staking/Subtensor/SubtensorPortfolio/SubtensorPortfolioInteractor.swift) · [device/retry properties](../../../novawallet/Common/Network/Bittensor/BittensorApiError+Recovery.swift) · [bootstrap error mapping](../../../novawallet/Common/Network/Bittensor/Transport/BittensorAuthorizedResponseGrader.swift)
Analytics owns event collection, its own installation/session identifiers, consent epochs, persistence and upload scheduling. None of those create a second authentication identity or bearer. The adapter resolves the same NovaAuth endpoint used by Bittensor.
```mermaid
flowchart TB
  ROOT["Root setup / app lifecycle / consent enable"] --> FACADE["AnalyticsServiceFacade<br/>session + schedule"]
  ENABLE["Actual consent false → true"] --> RECOVER["One in-memory pending consent event<br/>each user action gets an initial attempt"]
  RECOVER --> ADMIT["User-initiated admission<br/>bound to original event / context"]
  RECOVER -- "Retryable endpoint-resolution failure" --> PARK["Park unresolved opt-in<br/>no short polling deadline"]
  READY["Successful endpoint adoption<br/>invalidation delivered first"] --> PARK
  PARK -- "Accepted endpoint, only while still pending" --> ADMIT
  ADMIT -- "Admission cooldown" --> RETRY["Respect remaining cooldown<br/>at most 2 automatic re-arms per launch"]
  RETRY --> RECOVER
  INVALIDATE["Withdrawal / deactivation / context invalidation<br/>including cold or failed replacement"] --> DISCARD["Discard pending event, timer and waiter<br/>never move opt-in to a new generation"]
  EVENT["Event producer"] --> GATE{"Consent enabled + available?"}
  GATE -- yes --> QUEUE["CoreData event queue<br/>serial enqueue / erasure<br/>consent epoch on events"]
  GATE -- no --> IGNORE["Do not enqueue"]
  FACADE --> FLUSH["Flush gate<br/>owed erasure, consent, availability, schedule"]
  FLUSH --> ADAPTER["Gateway → AnalyticsAuthAdapter<br/>NovaAuthFacade.shared endpoint"]
  ADAPTER --> BATCH["Peek up to 50 events<br/>check epoch; serialize JSON envelope"]
  QUEUE --> BATCH
  BATCH --> SEND["Same NovaAuth client<br/>POST /v1/analytics/events<br/>background intent"]
  SEND --> CHECK{"Immediately before send<br/>consent enabled + same epoch?"}
  CHECK -- no --> CANCEL["Stop this upload"]
  CHECK -- yes --> RESULT{"Upload result"}
  RESULT -- "delivered / permanent payload failure" --> DROP["Drop batch rows"]
  RESULT -- "auth / transport / server failure" --> RETAIN["Keep rows for later flush"]
  OPT["Consent withdrawal"] --> ERASE["Persist erasure obligation first<br/>cancel analytics flush waiter<br/>forget analytics install ID; erase event queue"]
  ERASE -. "Shared auth and Bittensor remain independent" .-> SHARED["Same NovaAuth identity + bearer"]
```
**Accepted D3 limitation:** after an origin change or explicit reset, an install with analytics consent on and no Bittensor use uploads nothing. Uploads can resume after a real Bittensor user action or a consent off/on cycle, subject to admission and the bounded re-arm. An opt-in whose own initial resolution performs a cold origin replacement is discarded too; a later real action is required. Automatic uploads and restored consent do not re-authorize that context. Ordinary lost-key/interrupted recovery can run on background demand only within the persisted budget of two; registration refusal/abandonment and the legacy user-only states require user intent.
