# App Analytics for Nova Wallet iOS — Implementation Spec

**Status:** approved for planning (2026-09-02)
**Branch:** `feature/analytics`
**Baseline:** `b9a2b65c4`
**Risk tier:** high — privacy disclosure, App Store review, a new attested network channel, an irreversible CoreData model bump. No funds path is touched.

## 0. Scope

In scope: the complete analytics subsystem, its attestation channel, and the surfaces that let a user turn it on.

Out of scope: **call-site integration.** No presenter, interactor or wireframe outside Root / MainTabBar / Settings gains a `track()` call in this work. The 42-event catalog ships as types and factories with no consumers; the hooks in the draft's call-site table land in later PRs.

Concretely, when this work is done the app can: show the consent prompt, honour the Settings toggle, mint an install identity, attest a key against the gateway, record `app_opened` / `session_started` / `session_ended`, persist them, and upload them signed. Every other event in the catalog is constructible and correctly serialized, but nothing calls its factory.

Two prior artefacts are superseded by this document: `.claude/SPEC-analytics.md` (deleted with this commit) and the design artifact `ff2be6d9-997a-4896-b896-783c38a490eb`. Where this spec is silent on a detail those documents covered, they remain useful reading, but this file is authoritative.

Android parity source: novasamatech/nova-wallet-android PR **#2324**, head **`108899870`**. Paths in this document are repo-relative to that PR.

**Verification status (2026-09-02).** Checked directly against the Android source: the 42 event names, the 32 property keys, the ten Android-sourced enums, the envelope shape, `POST v1/analytics/events`, the queue operations and its 500/50 constants, the bucket boundaries *and* raw values, the classifier sets, and the three signing vectors. An earlier revision of this document carried **invented bucket raw values** and truncated digest vectors; both are corrected here from the source. Note also that GitHub's `search/code` API returns 0 results for the `infrastructure/…/attestation/` package although it exists on the PR head — verify with a direct `contents/` path lookup, not code search. Wire format, event names, property keys, bucket boundaries and the three attestation headers match Android byte-for-byte. `X-Signature` carries an App Attest assertion instead of a detached ECDSA signature — the one platform difference, isolated in the gateway's verifier (§7.6).

## 1. Principles

1. **Consent is one mechanical guard.** `AnalyticsService.track()` is the only entry point, and its first statement drops the event unless `isEnabled ∧ isAvailable`. Call sites never see a flag.
2. **Nothing exists before consent.** No queue row, no `install_id`, no attestation `client_id`, no App Attest key. Identity and key creation live inside the flush path, behind the same guard.
3. **Data minimisation is typed.** Event names, property keys and enumerated values are enums. Free-form strings enter only through the closed `AnalyticsContentValue` set; `String` deliberately does not conform to `AnalyticsPropertyConvertible`. Addresses, raw amounts, payloads and error messages have no representation.
4. **Process-scoped, Root-owned.** The facade is created once per process and set up from `RootInteractor.setup()`, not `ServiceCoordinator` — see §3.2.
5. **Fail silent.** No `Result` reaches a presenter, no alert, no retry loop. The persistent queue is the only retry.
6. **Operation-iOS only.** `CompoundOperationWrapper`, `execute`/`executeCancellable`, `CancellableCallStore`, `NSLock`. No `async`/`await`, actors, Combine or timers in the app target (`.claude/docs/code/concurrency.md:137`).
7. **Adding an event later is one static factory plus one `track()` call.**

## 2. Changes from the draft spec

Recorded here so review can focus on what moved. Everything not listed carries over.

1. **dApp attestation is deleted** (§7.1). It is wired but web-side dead; removing it leaves `AppAttestService` with exactly one consumer and frees us to shape it for the gateway.
2. **`AppAttestService` becomes a client-data-first DeviceCheck adapter** (§7.2). The draft's `createAttestationWrapper(clientDataClosure: () throws -> Data, using:)` cannot work: the attestation client data is `sha256(challenge ‖ clientId ‖ keyId)` and `keyId` is produced by `generateKey()` inside the wrapper. The closure takes the key id.
3. **`AppAttestClientHashing` is deleted.** It encoded the dApp backend's composition (`sha256(challenge)`, `sha256(challenge ‖ sha256(body))` over raw bytes). The gateway's composition is different and lives in `AttestationClientData`.
4. **New `DeviceCheckAttesting` seam** over `DCAppAttestService` (§7.2), which is the reason none of this is testable today.
5. **`BackendAttestationProvider` is written fresh, not copied** from `DAppAttestationProvider` (§7.3). Most of that type's 400 lines are UUID-keyed request coalescing for concurrent browser calls; the uploader is single-flight with serial batches and needs none of it.
6. **`CDAppAttestBrowserSettings` is renamed** to `CDAppAttestKey` in the same model bump (§5.1). It is analytics-only now and the old name is wrong.
7. **A fresh challenge is fetched per signed request** (§7.5). The draft promised the gateway reusable challenges in its own §5.6 while its wrapper chain fetched a new one every time. Fresh-per-request is the simpler contract and the stronger replay property.
8. **The `willTerminateNotification` observer is dropped** (§9). It enqueues asynchronously onto a serial operation queue and the process dies first; background-then-terminate has already emitted `session_ended`.
9. **`analyticsQueue` is serial with no claimed precedent.** `pendingMultisigQueue` (`Common/Operation/OperationManagerFacade.swift:50-53`) does not set `maxConcurrentOperationCount`; there is no serial queue in that file today.
10. **Persistence is wire-shaped, not lossless** (§4.3), stated as an invariant and tested as byte equality.

## 3. Architecture

### 3.1 Components

```
Root ──setup()──▶ AnalyticsServiceFacade (process-scoped)
                    ├── AnalyticsService            guard · collapse · flush policy
                    ├── AnalyticsConsentManager     Observable<Bool>, default off
                    ├── AnalyticsAvailabilityProvider
                    ├── AnalyticsIdentity           install_id (lazy) · session_id
                    ├── AnalyticsSessionTracker     ApplicationHandlerDelegate
                    ├── CoreDataAnalyticsEventQueue analyticsQueue (serial)
                    └── AnalyticsUploader           sharedDefaultQueue
                          └── BackendAttestationProvider
                                └── AppAttestService ──▶ DeviceCheckAttesting
```

MainTabBar reads the consent manager for the on-launch prompt; Settings reads and toggles it. Nothing else in the app references the facade in this work.

### 3.2 Ownership and lifetime

| Object | Owner | Lifetime |
|---|---|---|
| `AnalyticsServiceFacade.shared` | static | process; lazily built on first reference, never under `-UNITTEST` (`novawallet/AppDelegate.swift:20` returns before Root) |
| service, consent, identity, availability, session tracker, `ApplicationHandler` | facade | process |
| `CoreDataAnalyticsEventQueue` | facade | process; repository over `UserDataStorageFacade.shared` |
| `BackendAttestationProvider` | facade, handed to the uploader | process; `rejectedForProcess` in memory only |
| flush `CancellableCallStore` | `AnalyticsService` | one in-flight flush |

**Root, not `ServiceCoordinator`.** `ServiceCoordinator` is the aggregate "for the selected wallet" and is rebuilt on every `MainTabBarViewFactory.createView()`; its `setup()` runs from `MainTabBarInteractor.startServices()`, i.e. after the pincode gate. Registering there would lose every session before unlock and would throttle the facade on each main-flow rebuild. This is a documented exception to `.claude/docs/review/architecture-checklist.md:32` and is recorded in `.claude/docs/architecture/services-lifecycle.md` alongside `URLHandlingServiceFacade.shared` in the sanctioned-singletons table.

`RootInteractor.setup()` calls `analyticsFacade.setup()` **after `runMigrators()` and before `walletSettings.setup`** (`novawallet/Modules/Root/RootInteractor.swift:148-150`). `runMigrators()` is synchronous and `performMigration()` `fatalError`s on an unknown store version; a first consented enqueue any earlier would open `UserDataStorageFacade.shared` concurrently with it.

The facade still conforms to `ApplicationServiceProtocol` with a **real symmetric `throttle()`** — detach the handler delegate, cancel the flush store, `isActive = false` — used by the kill-switch transition (§10) and by tests. Nothing on the launch path calls it. `track()` depends on consent and availability only, never on `isActive`.

**`AnalyticsFacadeFactory.createDefault()` is an accessor, not a builder.** It returns `AnalyticsServiceFacade.shared` when `F_ANALYTICS` is defined and `NoOpAnalyticsServiceFacade.shared` otherwise, and it is the only place in the app that touches either `.shared`. Every call site receives the same object: one lock, one call store, one session, one `currentFeature`, one queue. Asserted by test (§12).

Consumers receive the protocol as a **required** init parameter from their ViewFactory, never as a defaulted `.shared` (`.claude/docs/code/naming-and-hygiene.md:80-82`, `viper.md:94-98`).

### 3.3 Threading

`track()` is callable from any thread. Under the facade `NSLock` it reads `isEnabled`/`isAvailable`, applies the `feature_opened` collapse, snapshots the date and a UUID, then adds the enqueue wrapper to the serial **`OperationManagerFacade.analyticsQueue`** (NEW, `maxConcurrentOperationCount = 1`). It never blocks and never touches CoreData on the caller's thread.

Two queues: CoreData enqueue/trim/peek/drop/clear on `analyticsQueue`; challenge/attest/register/POST on `sharedDefaultQueue`, ordered by `addDependency(wrapper:)`. An event is therefore persisted while a 15 s network call is in flight — tested in §12.

Flush is single-flight: `CancellableCallStore.hasCall` guard plus `executeCancellable(…, mutex:)` (`Common/Helpers/CancellableCallHelper.swift:4-19,72-98`; precedent `Web3AlertsSyncService.swift:38-40,54-59`). All `flushCallStore` access is under the facade lock — the store is not thread-safe.

`ApplicationHandler` delivers on main (`ApplicationHandler.swift:32-51`); the session tracker only calls `track`/`flush`.

Add the `analyticsQueue` row to the queue table in `.claude/docs/code/concurrency.md:97-115`.

### 3.4 Files

All NEW unless marked MOD.

`novawallet/Common/Services/Analytics/`
- `AnalyticsProtocols.swift` — one Cuckoo seam file holding `AnalyticsTrackingProtocol`, `AnalyticsServiceFacadeProtocol`, `AnalyticsConsentManagerProtocol`, `AnalyticsEventQueueProtocol`, `AnalyticsUploadOperationFactoryProtocol`, `AnalyticsIdentityProtocol`, `AnalyticsAvailabilityProviderProtocol`, `BackgroundTaskRunning`.
- `AnalyticsServiceFacade.swift`, `NoOpAnalyticsServiceFacade.swift`, `AnalyticsFacadeFactory.swift`
- `AnalyticsService.swift`, `AnalyticsUploader.swift`, `AnalyticsIdentity.swift`, `AnalyticsConsentManager.swift`, `AnalyticsSessionTracker.swift`, `AnalyticsAvailabilityProvider.swift`
- `Helpers/BackgroundTaskRunner.swift`

`AnalyticsExitTracker` — the presenter-owned `deinit` helper behind the five `*_abandoned` events — is **not** built here. It is a call-site mechanism with no consumers until integration, and it lands with the first PR that needs it.
- `Model/AnalyticsEvent.swift`, `AnalyticsEventName.swift`, `AnalyticsPropertyKey.swift`, `AnalyticsPropertyValue.swift`, `AnalyticsEnums.swift`, `AnalyticsBuckets.swift`, `AssetCategoryClassifier.swift`
- `Model/Events/AnalyticsEvent+{Lifecycle,Navigation,Onboarding,Swap,Send,Staking,Governance,DApp,Ramp,Misc}.swift` — each under 150 lines, no `switch`
- `Storage/AnalyticsPendingEvent.swift`, `Storage/CoreDataAnalyticsEventQueue.swift`
- `Network/AnalyticsEnvelope.swift`, `AnalyticsUploadOperationFactory.swift`, `ISO8601MillisFormatter.swift`
- `Debug/AnalyticsDebugInspector.swift` — `#if F_DEV` (§8.4)

`novawallet/Common/Services/Attestation/`
- `BackendAttestationProtocols.swift`, `BackendAttestationProvider.swift`, `BackendAttestationRemoteFactory.swift`, `BackendAttestationIdentity.swift`, `AttestationClientData.swift`, `BackendAttestationModeResolver.swift`

`novawallet/Common/Services/AppAttest/` — MOD `AppAttestService.swift` (reshaped, §7.2), MOD `AppAttestModel.swift`, NEW `DeviceCheckAttesting.swift`, MOD `AppAttestLocalSettings.swift` (`AppAttestBrowserSettings` → `AppAttestKeySettings`), **DELETE** `AppAttestClientHashing.swift`, MOD `AppAttestError.swift` (dApp-only cases removed).

Storage — NEW `Common/Storage/EntityToModel/AnalyticsPendingEventMapper.swift`; MOD `AppAttestBrowserSettingsMapper.swift` → `AppAttestKeyMapper.swift`; MOD `Common/Extension/Storage/SortDescriptor+Storage.swift`; MOD `Common/Storage/UserDataModel.xcdatamodeld`; MOD `Common/Migration/UserStorageVersion.swift`; MOD `Common/Storage/UserDataStorageFacade.swift:19`.

Config — MOD `Common/Extension/SettingsExtension.swift` (`SettingsKey` cases only; the file is 455 lines), NEW `Common/Extension/SettingsExtension+Analytics.swift` (accessors), MOD `Common/Configs/ApplicationConfigs.swift`, `Common/GlobalConfig/GlobalConfig.swift`, `Common/Operation/OperationManagerFacade.swift`, the four `novawallet/Configs/novawallet.*.xcconfig`, `novawallet/PrivacyInfo.xcprivacy`, `en.lproj/Localizable.strings`, `Cuckoofile.toml`.

Surfaces — NEW `Modules/AnalyticsConsent/AnalyticsConsentSheetFactory.swift`; MOD Root, MainTabBar and Settings module files (§8).

Deletions — `Modules/DApp/DAppBrowser/Attest/` in full (§7.1).

`novawallet.xcodeproj` is hand-managed: every new file is a manual target-membership edit and a `project.pbxproj` hunk. The data model is the exception — a new `.xcdatamodel` inside the existing `.xcdatamodeld` file reference needs no membership edit.

## 4. Event model

### 4.1 Types

```swift
struct AnalyticsEvent: Equatable {
    let name: AnalyticsEventName
    let properties: [AnalyticsPropertyKey: AnalyticsPropertyValue]

    init(name: AnalyticsEventName, properties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?] = [:]) {
        self.name = name
        self.properties = properties.compactMapValues { $0?.analyticsValue }   // nil ⇒ key omitted, never null
    }
}

enum AnalyticsEventName: String { /* exactly the 42 cases of §4.4 */ }
enum AnalyticsPropertyKey: String { /* exactly the 32 cases of §4.5 */ }

enum AnalyticsPropertyValue: Equatable, Codable {
    case bool(Bool)                     // is_first_launch, is_cross_chain, is_known_dapp
    case int(Int)                       // nft_count
    case enumerated(String)             // rawValue of a closed enum or bucket
    case content(AnalyticsContentValue) // the ONLY free-form strings
}

enum AnalyticsContentValue: Equatable {
    case assetSymbol(String), networkName(String), dappHost(String), providerId(String),
         bannerId(String), signingMethod(String), caip2Chain(String), raw(String)
}

protocol AnalyticsPropertyConvertible { var analyticsValue: AnalyticsPropertyValue { get } }
extension Bool: AnalyticsPropertyConvertible {}
extension Int: AnalyticsPropertyConvertible {}
extension AnalyticsContentValue: AnalyticsPropertyConvertible {}
extension RawRepresentable where RawValue == String, Self: AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { .enumerated(rawValue) }
}
// String deliberately does NOT conform. This is the privacy boundary.
```

Privacy is enforced by the closed value set, not by initializer visibility — a `fileprivate` init could not span the per-domain factory files. `.raw` exists only so persisted rows round-trip (§4.3); no factory produces it.

Adding a property later is one case in `AnalyticsPropertyKey`, one factory argument and one row in the encoding table test.

### 4.2 Encoding

`AnalyticsPropertyValue` needs an **explicit** `Codable` conformance over a single-value container — `bool` → JSON bool, `int` → JSON number, `enumerated`/`content` → JSON string; decode tries `Bool`, then `Int`, then `String` → `.content(.raw)`. The synthesized conformance would emit the keyed `{"bool":{"_0":true}}` shape and could never decode a persisted row.

An event serializes as `{ name, ts, props }` with explicit `CodingKeys`. Absent optionals are omitted from `props`, never emitted as `null`. Timestamps go through `ISO8601MillisFormatter` (`ISO8601DateFormatter`, `[.withInternetDateTime, .withFractionalSeconds]`, UTC) → `2026-09-02T10:00:00.123Z`, matching Android's `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`. The repo's `.iso8601` strategy drops milliseconds, hence the dedicated wrapper.

### 4.3 Persistence is wire-shaped, not lossless

The persisted payload **is** the wire `props` object. Decoding is therefore deliberately lossy: `.enumerated("swap")` comes back as `.content(.raw("swap"))`. This is correct because both encode to the same JSON string, so a row written by one app version uploads identically after being read by another.

The invariant is **byte stability, not value equality**: `encode(decode(encode(e))) == encode(e)`. It is tested as such (§12); no test asserts that decode returns the same enum case, because it does not and does not need to.

`AnalyticsPendingEvent` stores `name` as a `String`, so a row written by a newer build with an event name this build does not know still uploads correctly.

### 4.4 Event catalog (authoritative)

This table is the contract. `AnalyticsEventName` has exactly these 42 cases and every factory in `Model/Events/*` produces exactly these keys. Names and keys are verbatim from `analytics/src/main/java/io/novafoundation/nova/analytics/AnalyticsEvent.kt`, and were **diffed against it on 2026-09-02**: all 42 names and all 32 keys match exactly. Bare `.assetSymbol` / `.networkName` / … are `AnalyticsContentValue` cases; everything else is a closed enum, `Bool` or `Int`. "(omitted when nil)" means the key is absent from `props`, never `null`.

The **Trigger / dedupe** column is normative Android behaviour and is recorded here for the later integration PRs. In this work it constrains only the factory signatures — no call site implements a trigger except the three lifecycle rows.
| # | Wire name | Swift factory | Properties (`key: Swift value type`) | Trigger / dedupe |
|---|---|---|---|---|
| 1 | `app_opened` | `.appOpened(isFirstLaunch:)` | `is_first_launch: Bool` | once per process in `setup()`; always `false` on the wire (§9) |
| 2 | `session_started` | `.sessionStarted()` | — | foreground-period start: cold-start `setup()` and each `willEnterForeground` |
| 3 | `session_ended` | `.sessionEnded(duration:)` | `duration_bucket: DurationBucket` | `didEnterBackground`, only if a start was recorded; duration = `now − sessionStartedAt` |
| 4 | `onboarding_started` | `.onboardingStarted(source:)` | `source: OnboardingSource` | consent-checkbox change or Create tap, **once per presenter**; the Import tap alone does not fire it |
| 5 | `wallet_import_method_selected` | `.walletImportMethodSelected(method:)` | `method: WalletCreationMethod` | on tap, **before** any confirmation or backup-existence check |
| 6 | `wallet_creation_started` | `.walletCreationStarted()` | — | create-wallet entry screen `setup()` |
| 7 | `wallet_creation_completed` | `.walletCreationCompleted(method:duration:)` | `method: WalletCreationMethod`; `duration_bucket: DurationBucket` (omitted when nil) | create success only (mnemonic confirm + cloud create); imports/Ledger/Vault/cloud-restore emit **nothing**; Android never sets the duration |
| 8 | `wallet_creation_abandoned` | `.walletCreationAbandoned(lastStep:)` | `last_step: WalletCreationStep` | screen exit without `markProceeded()` (Android: `onCleared()` unless `proceededToNextStep`) |
| 9 | `feature_opened` | `.featureOpened(_:)` | `feature_id: FeatureId` | **collapse**: skip when the feature equals the current one; untracked screens leave the current value unchanged, so returning from a detail does not re-fire |
| 10 | `swap_screen_opened` | `.swapScreenOpened(source:)` | `source: SwapSource` | swap setup `setup()`, from the entry-point payload |
| 11 | `swap_initiated` | `.swapInitiated(source:assetIn:assetOut:amount:price:)` | `source: SwapSource`; `asset_in`/`asset_out: .assetSymbol`; `network_in`/`network_out: .networkName`; `asset_in_category`/`asset_out_category: AssetCategory`; `amount_bucket: AmountBucket` | Continue after validation; **requires a loaded quote AND a fiat rate for the pay asset** — otherwise skipped entirely |
| 12 | `swap_confirmed` | `.swapConfirmed(assetIn:assetOut:amount:price:slippage:)` | `amount_bucket: AmountBucket`; `slippage_bucket: SlippageBucket`; `asset_in`/`asset_out: .assetSymbol`; `network_in`/`network_out: .networkName` | immediately before submission; skipped without a fiat rate |
| 13 | `swap_completed` | `.swapCompleted(assetIn:assetOut:amount:price:duration:)` | `amount_bucket: AmountBucket`; `duration_bucket: DurationBucket`; `asset_in`/`asset_out: .assetSymbol`; `network_in`/`network_out: .networkName` | submit success (single-op) or execution Done (multi-step); duration from the confirm/execute stamp; skipped without a fiat rate |
| 14 | `swap_failed` | `.swapFailed(reason:)` | `reason: SwapFailureReason` | confirmation failure and execution failure |
| 15 | `swap_abandoned` | `.swapAbandoned(stage:)` | `stage: SwapStage` | setup exit without proceeding to confirm; confirm exit without confirming |
| 16 | `staking_flow_opened` | `.stakingFlowOpened(network:source:)` | `network: .networkName`; `source: StakingFlowSource` | start-staking tap; Android emits only `dashboard` |
| 17 | `staking_type_selected` | `.stakingTypeSelected(type:network:)` | `staking_type: StakingAnalyticsType`; `network: .networkName` | Apply in the staking-type picker |
| 18 | `staking_initiated` | `.stakingInitiated(type:network:amount:rate:)` | `staking_type: StakingAnalyticsType`; `network: .networkName`; `amount_bucket: AmountBucket` | Continue after validation, **new stake only** (never bond-more) |
| 19 | `staking_confirmed` | `.stakingConfirmed(type:network:amount:rate:)` | same as 18 | before submission, new stake only |
| 20 | `staking_completed` | `.stakingCompleted(type:network:amount:rate:)` | same as 18 | submission success, new stake only |
| 21 | `staking_failed` | `.stakingFailed(type:network:reason:)` | `staking_type: StakingAnalyticsType`; `network: .networkName`; `reason: TransactionFailureReason` | submission failure in the three confirm presenters (Android sends the exception class name) |
| 22 | `staking_abandoned` | `.stakingAbandoned(stage:)` | `stage: StakingStage` | exit without `flowContinued`/`flowCompleted`; the mythos/parachain providers return nil unless it is a new stake |
| 23 | `unstake_initiated` | `.unstakeInitiated(type:network:amount:rate:)` | `staking_type: StakingAnalyticsType`; `network: .networkName`; `amount_bucket: AmountBucket` | Continue after validation; mythos reports the **whole staked amount** (parity) |
| 24 | `unstake_completed` | `.unstakeCompleted(type:network:amount:rate:)` | same as 23 | submission success |
| 25 | `unstake_failed` | `.unstakeFailed(type:network:reason:)` | `staking_type: StakingAnalyticsType`; `network: .networkName`; `reason: TransactionFailureReason` | submission failure |
| 26 | `send_initiated` | `.sendInitiated(asset:destination:amount:rate:)` | `asset: .assetSymbol`; `network: .networkName`; `destination_network: .networkName` (omitted when nil — cross-chain only); `asset_category: AssetCategory`; `amount_bucket: AmountBucket`; `is_cross_chain: Bool` | on opening confirm, after validation; `is_cross_chain` = origin chain id ≠ destination chain id |
| 27 | `send_completed` | `.sendCompleted(asset:destination:amount:rate:)` | `asset: .assetSymbol`; `network: .networkName`; `amount_bucket: AmountBucket`; `destination_network: .networkName` (omitted when nil) | transfer submission success |
| 28 | `send_failed` | `.sendFailed(asset:destination:reason:)` | `asset: .assetSymbol`; `network: .networkName`; `reason: TransactionFailureReason`; `destination_network: .networkName` (omitted when nil) | transfer submission failure |
| 29 | `dapp_opened` | `.dappOpened(host:source:isKnown:)` | `dapp_host: .dappHost`; `source: DAppOpenSource`; `is_known_dapp: Bool` | after the not-in-catalog warning; known = catalog metadata present (`false` on error) or `isTrustedByNova` for search results |
| 30 | `governance_vote_cast` | `.governanceVoteCast(direction:network:amount:rate:conviction:)` | `vote_direction: VoteDirection`; `network: .networkName`; `amount_bucket: AmountBucket`; `conviction_level: ConvictionLevel` (omitted when nil) | vote success — one event per referendum, and **one event per basket item** for SwipeGov batch voting |
| 31 | `tab_switched` | `.tabSwitched(tab:)` | `tab: AnalyticsTab` | skip the first tab of the process; skip a re-select of the same tab; programmatic index writes count |
| 32 | `buy_initiated` | `.buyInitiated(provider:asset:network:)` | `provider: .providerId`; `asset: .assetSymbol`; `network: .networkName` | when the ramp integrator is created |
| 33 | `buy_completed` | `.buyCompleted(provider:asset:network:)` | same as 32 | operation finished successfully, and **only when the network is already resolved** |
| 34 | `sell_initiated` | `.sellInitiated(provider:asset:network:)` | same as 32 | as 32 |
| 35 | `sell_completed` | `.sellCompleted(provider:asset:network:)` | same as 32 | as 33 |
| 36 | `banner_clicked` | `.bannerClicked(id:screen:)` | `banner_id: .bannerId`; `screen: AnalyticsBannerScreen` | **only when the banner carries an action link**; Android's third key `banner_title` has no iOS source and is omitted |
| 37 | `nova_card_opened` | `.novaCardOpened()` | — | every entry into the card screen, **no collapse** |
| 38 | `nft_section_opened` | `.nftSectionOpened(count:)` | `nft_count: Int` | first non-empty NFT delivery of the screen, once |
| 39 | `sign_request_shown` | `.signRequestShown(source:method:chain:)` | `source: SignSource`; `method: .signingMethod`; `chain: .caip2Chain` | browser: after the chain-disabled check; WalletConnect: after a successful request parse |
| 40 | `sign_approved` | `.signApproved(source:method:chain:)` | same as 39 | response carries a signature |
| 41 | `sign_rejected` | `.signRejected(source:method:chain:)` | same as 39 | response carries no signature |
| 42 | `sign_failed` | `.signFailed(source:method:chain:reason:)` | same as 39 plus `reason: SignFailureReason` | signing failure (`signing_failed`) and the WalletConnect pre-rejections (`no_session`, `unsupported_request`) |

### 4.5 Property keys

`AnalyticsPropertyKey` has exactly 32 cases; `rawValue` is the wire key. Every key in §4.4 appears here and nowhere else.

```swift
enum AnalyticsPropertyKey: String {
    case isFirstLaunch = "is_first_launch"
    case durationBucket = "duration_bucket"
    case source
    case method
    case lastStep = "last_step"
    case featureId = "feature_id"
    case tab
    case asset
    case assetIn = "asset_in"
    case assetOut = "asset_out"
    case network
    case networkIn = "network_in"
    case networkOut = "network_out"
    case destinationNetwork = "destination_network"
    case assetCategory = "asset_category"
    case assetInCategory = "asset_in_category"
    case assetOutCategory = "asset_out_category"
    case amountBucket = "amount_bucket"
    case slippageBucket = "slippage_bucket"
    case isCrossChain = "is_cross_chain"
    case reason
    case stage
    case stakingType = "staking_type"
    case voteDirection = "vote_direction"
    case convictionLevel = "conviction_level"
    case dappHost = "dapp_host"
    case isKnownDapp = "is_known_dapp"
    case provider
    case bannerId = "banner_id"
    case screen
    case nftCount = "nft_count"
    case chain
}
```

Android's 33rd key, `banner_title`, has no case: `Banner` carries `id`, `background`, `image`, `clipsToBounds` and `actionLink`, and no title (`Modules/Banners/Model/Banner.swift:12-18`).

### 4.6 Enums

`Model/AnalyticsEnums.swift`. The ten Android-sourced enums below have `String` raw values verbatim from `analytics/src/main/java/io/novafoundation/nova/analytics/AnalyticsEvent.kt`, **verified case by case on 2026-09-02**:

`AssetCategory` (`native_token, stablecoin, wrapped_token, other`) · `WalletCreationMethod` (`create, import_mnemonic, import_seed, import_json, import_ledger, import_parity_signer, import_polkadot_vault, import_watch_only, cloud_backup`) · `SwapSource` (`asset_details, main_screen, operation_details, retry`) · `SwapFailureReason` (`network_error, execution_reverted, user_cancelled, unknown`) · `StakingStage` (`landing, setup, type_selection, confirm`) · `SwapStage` (`setup, confirm`) · `FeatureId` (`staking, governance, crowdloans, dapps, nft, swap, buy, send, receive, settings`) · `OnboardingSource` (`fresh_install, add_wallet`) · `WalletCreationStep` (`welcome, backup, confirm_mnemonic, pin_setup, seed_entry, json_upload, ledger_connect, other`) · `SignSource` (`dapp_browser, walletconnect`).

iOS-side closed sets: `AnalyticsTab` (`assets, vote, dapps, staking, settings`) · `StakingAnalyticsType` (`direct, pool, mythos, unsupported`) · `TransactionFailureReason` (`user_cancelled, network_error, unknown`) · `SignFailureReason` (`signing_failed, no_session, unsupported_request`) · `DAppOpenSource` (`catalog, favorites, search, manual_url`) · `VoteDirection` (`aye, nay, abstain`) · `ConvictionLevel` (`0.1x` … `6x`).

Two properties that are string literals on Android become closed enums here, because `String` does not conform to `AnalyticsPropertyConvertible`:

- **`StakingFlowSource`** (`dashboard`, `asset_details`). Android sends only `"dashboard"`; iOS has a second entry point, so the enum carries both and `dashboard` stays byte-identical.
- **`AnalyticsBannerScreen`** — mirrors the raw values of `Banners.Domain` verbatim: `dapps` (`case dApps = "dapps"`), `assets`, `ahm_kusama`, `ahm_polkadot` (`Modules/Banners/Model/BannersModuleConfiguration.swift:9-14`), plus `unknown` for Android's fallback. The enum lives in `Common`; the `Banners.Domain → AnalyticsBannerScreen` mapper lands with the integration PR in `Modules/Banners/Model/`, so no `Modules` raw value crosses into `Common` (`.claude/docs/code/project-layout.md:3-4`).

**Failure reasons are always closed enums on iOS.** Android sends the exception class simple name for staking and unstake; Swift type names would never match it and are unbounded, so the vocabulary is a closed set agreed jointly with Android.

### 4.7 Buckets and classifier

`Model/AnalyticsBuckets.swift`. Boundaries **and raw values** transcribed from
`analytics/src/main/java/io/novafoundation/nova/analytics/ValueBucketing.kt` in
novasamatech/nova-wallet-android PR #2324 at head `108899870`, and verified against it.
The raw values are the wire contract; the Swift case names are not.

| Bucket | Bounds | Raw values, in order |
|---|---|---|
| `AmountBucket(usd: Decimal)` | exclusive `<` at 1 / 10 / 100 / 1 000 / 10 000 / 100 000 | `under_1`, `1_to_10`, `10_to_100`, `100_to_1k`, `1k_to_10k`, `10k_to_100k`, `over_100k` |
| `DurationBucket(duration: TimeInterval)` | exclusive `<` at 5 / 15 / 30 / 60 / 300, applied to `Int(duration)` (truncating, equal to Android's `milliseconds / 1000`) | `under_5s`, `5s_to_15s`, `15s_to_30s`, `30s_to_60s`, `1m_to_5m`, `over_5m` |
| `SlippageBucket(percent: Decimal)` | **inclusive** `<=` at 0.5 / 1 / 3 | `low`, `medium`, `high`, `custom` |

Two things here are easy to get wrong and are load-bearing. **Slippage is not a range vocabulary** —
it is a qualitative one, so `0.5` maps to `low` rather than to a "0.5-to-1" bucket, and anything
above 3 is `custom`. And **slippage bounds are inclusive while the other two are exclusive**, so
`AmountBucket(usd: 1)` is `1_to_10` but `SlippageBucket(percent: 0.5)` is `low`.

Two amount initialisers, because Android treats swaps differently from everything else: `init(amount: Decimal, rate: Decimal?)` (missing rate ⇒ `0` ⇒ `under_1`) for send and staking, which call `amountToFiat` unguarded; and the failable `init?(amount:price: PriceData?)` used **only** by the three swap factories, because Android skips swap events without a fiat rate. `PriceData.decimalRate` is `Decimal?` (`Common/PriceProvider/Model/PriceData.swift:29`).

`AssetCategoryClassifier.classify(_ symbol: String) -> AssetCategory` upper-cases its input and
applies the rules in order — NATIVE → STABLE → WRAPPED → `W`+NATIVE → other — so `WDOT` is
`wrapped_token` and not `native_token`. Sets transcribed verbatim from
`analytics/src/main/java/io/novafoundation/nova/analytics/AssetCategoryClassifier.kt` at the same
commit:

- **native** — `DOT`, `KSM`, `ETH`, `BTC`, `BNB`, `AVAX`, `MATIC`, `SOL`, `FTM`, `GLMR`, `MOVR`, `ASTR`, `ACA`, `CFG`, `HDX`, `INTR`, `KINT`, `PHA`, `ZTG`, `NODL`, `RING`, `TEER`, `TUR`, `UNQ`, `AZERO`
- **stable** — `USDT`, `USDC`, `DAI`, `BUSD`, `TUSD`, `FRAX`, `LUSD`, `USDP`, `GUSD`, `USDD`, `CRVUSD`, `GHO`, `PYUSD`, `AUSD`, `IUSD`
- **wrapped** — `WETH`, `WBTC`, `WBNB`, `WAVAX`, `WMATIC`, `WFTM`, `WGLMR`, `WMOVR`, `WDOT`, `WKSM`

`ChainModel.name` and `AssetModel.symbol` are Android's `Chain.name` / `symbol.value`.

## 5. Storage

### 5.1 Model 21

`MultiassetUserDataModel21.xcdatamodel` is added inside the existing `Common/Storage/UserDataModel.xcdatamodeld`, and makes three changes:

- **adds** `CDAnalyticsEvent { identifier: String; sequence: Integer 64; name: String; timestamp: Date; payload: Binary }`
- **adds** `CDAppAttestKey { identifier: String; keyId: String; isAttested: Boolean }`
- **drops** `CDAppAttestBrowserSettings`

`UserStorageVersion` gains `case version22 = "MultiassetUserDataModel21"` with `version21 → .version22` (the case number runs one ahead of the model file number; `version21 = "MultiassetUserDataModel20"` is today's last). `UserStorageParams.modelVersion` moves to `.version22` (`UserDataStorageFacade.swift:19`).

An added entity and a dropped entity are both inferrable, so `UserStorageMigrator` needs no mapping model — it looks for a custom mapping first and falls back to inferred lightweight migration (`Common/Migration/StorageMigrator.swift:160-178`). The `KeystoreMigrator` and `SettingsMigrator` carried through the same step have nothing to do here. The dropped rows are dApp App Attest key ids, which are being discarded anyway (§7.1).

Swift-side, `AppAttestBrowserSettings` becomes `AppAttestKeySettings { identifier, keyId, isAttested }` and `AppAttestBrowserSettingsMapper` becomes `AppAttestKeyMapper`. The gateway's row is keyed by the gateway URL.

**Why the user store.** It already hosts the app's other user-owned, non-chain rows, and `.claude/docs/code/data-persistence.md:7` reserves the Substrate store for chain-derived data. The rows are disposable regardless — trimmed to 500, wiped on opt-out, cleared on permanent rejection. The payloads contain nothing the type system permits (§4.1), so an entity readable by the push extension leaks nothing.

**The model bump and the push extension.** The extension never runs the migrators — they run only from `RootInteractor.setup()`. Between installing the update and the first app launch, the extension opens a model-20 store file with the model-21 `.momd`:

- The model bundle reaches the extension automatically. `UserDataModel.xcdatamodeld` is one file reference with two `PBXBuildFile` entries, in both the extension's and the app's Sources phase, so a new `.xcdatamodel` inside it ships in both `.momd`s and the `modelURL!` force-unwrap in `UserDataStorageFacade.swift:57-78` stays safe. No target-membership edit is needed.
- The extension destroys nothing. `CoreDataService.setup()` passes `options: storeOptions`, `nil` unless persistent-history tracking is configured — which the user facade does not — and `incompatibleModelStrategy: .ignore` short-circuits the store-removal branch.
- Net effect: `addPersistentStore` throws `NSPersistentStoreIncompatibleVersionHashError`, `setup()` throws, and user-store repository calls fail. `NotificationService` maps a handler failure to `createUnsupportedResult`, so **the push is still delivered** with generic copy, the model-20 file is left intact, handlers needing no store are unaffected, and the window self-heals on first app launch.

This window is precedented — every prior model bump had it, including model 17 which added `CDAppAttestBrowserSettings` — but it is the first time the app pays it for disposable data. It is accepted knowingly. Step 1 asserts the throw and the intact file in a test, and the manual check is one push on an upgrade install before first launch.

The bump is **permanent once a build ships**: a model-21 store cannot be reopened by a model-20 `.momd`.

### 5.2 Queue

Requirements, from `analytics/src/main/java/io/novafoundation/nova/analytics/transport/AnalyticsEventQueue.kt` and the `ANALYTICS_QUEUE_MAX_SIZE = 500` / `ANALYTICS_BATCH_SIZE = 50` constants in its DI module, both **verified 2026-09-02**: persistent FIFO by insertion order, trim to newest 500, peek oldest 50, drop, count, clear. One deliberate divergence: Android drops by *count* (`deleteOldest`), iOS drops by *id*, so a concurrent enqueue can never cause iOS to delete an un-uploaded row.

**Ordering is by `sequence`, a monotonic `Int64`, not wall-clock time** — a clock correction must not reorder the trim (`.claude/docs/code/data-persistence.md:128-129`). The service seeds an in-memory counter once per process, from the newest row via `RepositorySliceRequest(offset: 0, count: 1, reversed: true)`, on its first enqueue. `identifier = String(format: "%019lld", sequence)`. NEW `NSSortDescriptor.analyticsEventsBySequence` in `SortDescriptor+Storage.swift`.

Operations map 1:1 onto `DataProviderRepositoryProtocol`:

```swift
protocol AnalyticsEventQueueProtocol {
    func enqueueWrapper(_ event: AnalyticsPendingEvent) -> CompoundOperationWrapper<Void>
    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>
    func dropOperation(ids: [String]) -> BaseOperation<Void>
    func countOperation() -> BaseOperation<Int>
    func clearOperation() -> BaseOperation<Void>
}
```

`enqueueWrapper` saves, then slices `(offset: 500, count: 50, reversed: true)` and deletes the overflow ids. `peekWrapper` slices `(offset: 0, count:, reversed: false)`. `dropOperation` is `saveOperation({ [] }, { ids })`. `clearOperation` is `deleteAllOperation()`.

`AnalyticsPendingEventMapper.transform` throws `CommonError.dataCorruption` on an undecodable payload. The uploader treats such a row as **poison**: deleted by id and logged, so the queue never wedges.

## 6. Flush policy and transport

### 6.1 One flush API

The facade exposes exactly one entry point:

```swift
func flush(reason: AnalyticsFlushReason)
enum AnalyticsFlushReason { case threshold, interval, launch, background, manual }
```

`threshold` (queue reached 50) · `interval` (≥ 5 min since the last flush) · `launch` (rows pending from a previous process, from `setup()`) · `background` (`didEnterBackground`) · `manual` (the `#if F_DEV` inspector).

The reason is a log line and one number: `AnalyticsService` maps it to a batch cap — `background ⇒ maxBatches: 1`, everything else `maxBatches: 10` (500 / 50) — and calls the internal `AnalyticsUploader.flushWrapper(maxBatches:)`. Nothing outside the facade sees `maxBatches`.

`track` → enqueue → `flushIfNeeded()` evaluates the threshold and interval rules and calls the same `flush(reason:)`. `lastFlushAt` starts at `.distantPast`, so the first consented event of a process flushes. No timer, no reachability check, no backoff (`.claude/docs/code/networking.md:114-115,124`). The current time comes from an injected `() -> Date` (§12).

### 6.2 Upload loop

`flushWrapper(maxBatches:)`: `peek(50)` → encode the envelope **once** into `Data` → `createSignedHeadersWrapper(bodyClosure:)` (§7) → `NetworkOperation` POST → `dropOperation(ids)` (dependent, on `analyticsQueue`) → next batch via `OperationCombiningService.compoundNonOptionalWrapper`, capped at `maxBatches`, stopping at the first error. `lastFlushAt` is set before the upload.

**The bytes signed are the bytes sent.** `httpBody = bodyData` — never a re-encode inside the request closure, which would race the signature against `JSONEncoder`'s non-deterministic key order. This is the single most consequential invariant in the transport and has its own test (§12).

Envelope (`Network/AnalyticsEnvelope.swift`): `{v: 1, platform: "ios", app_version, install_id, session_id, sent_at, events}`. The Swift property is `schemaVersion` mapped to `"v"` because a one-letter identifier fails SwiftLint's `identifier_name`. `app_version` is `CFBundleShortVersionString` only — `ApplicationConfig.version` appends the build number.

Request: `POST {gatewayURL}v1/analytics/events`, `timeoutInterval = 15`, `Content-Type: application/json`, plus the three attestation headers.

```swift
enum AttestationHeaderKey: String {
    case clientId = "X-Client-Id"
    case challenge = "X-Challenge"
    case signature = "X-Signature"
}
```

`HttpHeaderKey` in Operation-iOS carries only `contentType` and `authorization`, hence the new enum.

### 6.3 Status mapping

The result factory is a raw `AnyNetworkResultFactory(block:)`, because `successResponseBlock:` routes through `NetworkResponseError.createFrom` which collapses 403 into `unexpectedStatusCode`, and `processingBlock:` fails an empty 2xx body.

```swift
enum AnalyticsTransportError: Error {
    case rejected(statusCode: Int)      // 401 / 403
    case clientError(statusCode: Int)   // other 4xx
    case serverError(statusCode: Int)   // 5xx
}
```

| Outcome | Action | Android |
|---|---|---|
| 2xx | drop the batch, continue | same |
| 401 / 403 | **clear the queue**, `attestation.markUnattested()`, stop. The next flush attests a new key and re-registers | Android clears the queue and never re-registers; the recovery is iOS-only |
| `BackendAttestationError.rejected` (register 401/403 this process) | clear the queue, stop; every later flush short-circuits until relaunch | Android marks the process rejected on *any* register 4xx — same consequence, narrower trigger here |
| other 4xx | events: drop **this batch**, continue. Register: **not** permanent — keep the queue, retry next flush | a 409/422/429 from a challenge that expired during the Apple round-trip is not a rejected client |
| 5xx, transport, `AppAttestServiceError.serviceUnavailable`, decode failure | keep the queue, stop | same |

A batch is dropped only after its 2xx, so a kill between the 2xx and the drop re-sends it. Delivery is **at-least-once**; a per-event `id` for backend de-duplication is proposed in §7.6.

### 6.4 Identity

- **`install_id`** — lowercase dashed UUID under `SettingsKey.analyticsInstallId`, generated lazily inside `createEnvelope` on the first flush. **Opting out deletes the key; it never rotates it.** An opted-out install has no id at all, and a later opt-in generates a fresh one exactly as a brand-new install would — the two are indistinguishable on the wire. Android instead writes a fresh UUID on every launch while opted out.
- **`session_id`** — UUID per `AnalyticsIdentity` instance, i.e. per process. An iOS process can span days; the id is still per process.
- `install_id` lives in `UserDefaults` and therefore survives a device restore, so "install" is really "install lineage". This matches Android and is accepted; it is disclosed as `NSPrivacyCollectedDataTypeDeviceID` (§8.5).

### 6.5 Opt-out wipe

`consent.setEnabled(false)` runs under the lock, in this order:

1. `isEnabled = false`
2. **cancel the in-flight flush** — `flushCallStore.cancel()`, so a POST already in the air is abandoned and its batch is never dropped (tested, §12)
3. `identity.forgetInstallId()` — `settingsManager.removeValue(for: .analyticsInstallId)`, a delete and never a rotation
4. `queue.clearOperation()`
5. reset `lastFlushAt` and `currentFeature`
6. `attestation.forgetClient()` — delete the gateway's key row and `client_id`

The App Attest private key stays in the Secure Enclave, unreferenced and unusable without the gateway's record. Android keeps `attestation_client_id` forever, which would let `X-Client-Id` re-link envelopes across identity changes.

`analyticsPromptSeen` is never cleared. `removeAll()` is never called.

## 7. Attestation

### 7.1 Removing dApp attestation

dApp App Attest is fully wired but web-side dead: `DAppBrowserInteractor` injects a `window.IntegrityProvider` bridge into every browser tab and answers `requestIntegrityCheck` messages, but no dApp calls it. It is removed in full, as the first step and as its own commit so it can be reverted independently.

Deleted: `Modules/DApp/DAppBrowser/Attest/` in its entirety — `DAppAttestationProvider.swift`, `DAppAttestHandling.swift`, `DAppAttestVerificationFactory.swift`, `DAppAssertionCallFactory/` (3 files), `Model/` (4 files).

Modified: `DAppBrowserViewFactory.swift:93-112,128` drops the provider/handler construction and the `attestHandler:` argument; `DAppBrowserInteractor.swift` drops the `attestHandler` property, init parameter, assignment, the two message-routing sites, the transport-model contribution and the `DAppAttestHandlerDelegate` conformance (`:26,49,62,369,427-428,479-480,617-619`); `DAppBrowserTests.swift:74-112` drops its setup.

**Risk to confirm before merging step 0:** if any dApp still calls `window.IntegrityProvider.requestIntegrityCheck`, removing the global turns a silent no-op into a JS `TypeError`. Confirmed dead on the web side by the team.

**Not touched: `FirebaseAppCheckProviderFactory`.** It uses App Attest through Firebase App Check for FCM (`Common/Services/Web3AlertService/FirebaseAppCheckProviderFactory.swift`), with its own Firebase-managed key. It is unrelated to this work and must survive. The app will hold two App Attest keys — Firebase's and the gateway's — which Apple permits; `attestKey` rate limits are per-app and one attestation per install is far inside them.

### 7.2 `AppAttestService` becomes a DeviceCheck adapter

After §7.1 the service has exactly one consumer, so it is shaped for the gateway rather than carrying overloads.

```swift
// NEW DeviceCheckAttesting.swift — the seam that makes any of this testable
protocol DeviceCheckAttesting {
    var isSupported: Bool { get }
    func generateKey(completionHandler: @escaping (String?, Error?) -> Void)
    func attestKey(_ keyId: String, clientDataHash: Data,
                   completionHandler: @escaping (Data?, Error?) -> Void)
    func generateAssertion(_ keyId: String, clientDataHash: Data,
                           completionHandler: @escaping (Data?, Error?) -> Void)
}
extension DCAppAttestService: DeviceCheckAttesting {}

protocol AppAttestServiceProtocol {
    var isSupported: Bool { get }

    /// `clientData` receives the key id — generated here when `keyId` is nil — because the
    /// gateway's attestation client data is sha256(challenge ‖ clientId ‖ keyId).
    func createAttestationWrapper(
        using keyId: AppAttestKeyId?,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation>   // { keyId, attestation: Data }

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion>     // Data
}
```

The service SHA-256s the client data itself — DeviceCheck's `clientDataHash` is by contract a SHA-256 digest — and no longer composes anything. `AppAttestClientHashing.swift` is deleted: its two-part composition was the dApp backend's convention and dies with §7.1. `AppAttestError` keeps only the cases the gateway path uses; the hex-challenge and 16-byte-length cases go. `AppAttestModel` is replaced by `AppAttestAttestation`.

The existing `DCError` mapping (`createDCSpecificError`: `.invalidInput`/`.invalidKey` → `.invalidKeyId`, `.serverUnavailable` → `.serviceUnavailable`) is kept verbatim and gains its first tests.

### 7.3 `BackendAttestationProvider`

```swift
protocol BackendAttestationProviderProtocol: AnyObject {
    /// nil ⇒ mode .none — the request goes out unsigned (dev builds only).
    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?>

    func markUnattested()   // the gateway no longer knows this identity: drop the key row, re-attest with a NEW key
    func forgetClient()     // opt-out: drop the key row and the client id
}

protocol BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String>
    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void>
}

protocol BackendAttestationIdentityProtocol {
    func clientId() -> String
    func forgetClientId()
}

enum BackendAttestationError: Error {
    case rejected(statusCode: Int), clientError(statusCode: Int), serverError(statusCode: Int), unsupported
}
enum BackendAttestationMode { case appAttest, none, unavailable }
```

It is written fresh rather than generalised from `DAppAttestationProvider`. That type's `pendingRequests` / `pendingAssertions` UUID maps and per-request cancellation exist because the browser fires concurrent `verifySignature` calls; the uploader is single-flight with serial batches (§3.3), so the provider is a straight wrapper chain plus three pieces of state.

State, guarded by one `NSLock`: `attestedKeyId: AppAttestKeyId?` (in-memory cache of the persisted row), `rejectedForProcess: Bool`, `invalidKeyIdDiscardedThisLaunch: Bool`.

`createSignedHeadersWrapper(bodyClosure:)` chains:

1. short-circuit to `.createWithError(.rejected)` if `rejectedForProcess`
2. resolve the mode; `.none` ⇒ result `nil`; `.unavailable` ⇒ `.createWithError(.unsupported)`
3. `ensureAttestedWrapper()` → `AppAttestKeyId`
4. `remoteFactory.createChallengeWrapper()`
5. `appAttest.createAssertionWrapper(keyId:clientData:)` with `AttestationClientData.assertionClientData(challenge:clientId:body:)`
6. `ClosureOperation` building `[.clientId: clientId, .challenge: challenge, .signature: base64(assertion)]`

`ensureAttestedWrapper()` returns `.createWithResult(keyId)` when the row for the gateway URL says `isAttested`; otherwise it fetches a challenge, calls `createAttestationWrapper(using: existingKeyId, clientData:)` with `attestationClientData(challenge:clientId:keyId:)`, **saves the row with `isAttested: false` before the register POST** so a retry after a failed register reuses the same attested key, posts `register`, then saves the row with `isAttested: true`.

Apple asks apps to attest sparingly, so a key is attested once; recovery always means a **new** key, never a second attestation of the old one.

### 7.4 Identity, client data and recovery

**`client_id`** is per gateway URL and per consent cycle: a lowercase dashed UUID under `SettingsKey.gatewayAttestationClientId`, created lazily on the first signed request — never before the first consented flush — and deleted by `forgetClient()`. It is the gateway's lookup key for the registered credential, so two installs never share one and a re-consented user is a new client. It is independent of `install_id`. The provider clears the key row whenever it creates a client id, so the two cannot drift.

**`AttestationClientData`** — three pure functions, byte-for-byte Android's `AttestationSigning`
(`infrastructure/src/main/java/io/novafoundation/nova/infrastructure/attestation/AttestationSigning.kt`,
PR #2324 head `108899870`). Note that Android's `signingPayload` returns the **hashed** payload,
while `assertionClientData` below returns the unhashed string and `AppAttestService` applies the
SHA-256 — the two compose to the same digest:

```swift
func bodyDigestHex(_ body: Data) -> String                 // lowercase hex of sha256(body)
func assertionClientData(challenge: String, clientId: String, body: Data) -> Data
    // utf8(challenge ‖ clientId ‖ bodyDigestHex(body))
func attestationClientData(challenge: String, clientId: String, keyId: String) -> Data
    // utf8(challenge ‖ clientId ‖ keyId)
```

`AppAttestService` hashes these with SHA-256, giving exactly Android's `signingPayload` / `attestationPayload`.

**Recovery:**

| Trigger | Provider action | Next flush |
|---|---|---|
| events POST 401/403 | `markUnattested()` — delete the key row | new key, attest, register |
| register 401/403 | `rejectedForProcess = true`, queue cleared | short-circuits until relaunch |
| register other 4xx | keep the row (`isAttested: false`, same key), keep the queue | register again with a fresh challenge, same key |
| `AppAttestServiceError.invalidKeyId` on attest or assert | delete the row, **at most once per launch** | new key |
| `DCError.serverUnavailable` / transport | keep everything | retry |
| `isSupported == false` | mode `.none` (dev) or `.unavailable` (release) | — |

The app cannot delete App Attest keys; a discarded `keyId` simply goes unused. Nothing survives reinstall except the gateway's record, which a new install never references because it mints a new `client_id`.

### 7.5 Mode ladder

`BackendAttestationModeResolver.resolve(isReleaseBuild: Bool, isAppAttestSupported: Bool) -> BackendAttestationMode` — a pure function with injected inputs so the ladder is unit-tested; the flags are read at the factory (`.claude/docs/architecture/services-lifecycle.md:151-153`).

1. **`appAttest`** — supported. `appattest-environment` is `production` in all four entitlement files, so a Debug build on a real device exercises the production path; the dev and staging App IDs are on the gateway's allow-list.
2. **`none`** — `!isReleaseBuild ∧ unsupported` (Simulator): `createSignedHeadersWrapper` resolves to `nil`, requests go out **unsigned**, and the dev gateway accepts unattested traffic from dev bundle ids. Android's `UNATTESTED` mode sends no headers either. Android's third mode, `shared_secret`, is **not** implemented on iOS — it would reintroduce the software signing key this design does without, and no CI secret is therefore needed.
3. **`unavailable`** — `isReleaseBuild ∧ unsupported`: contributes `false` to `isAvailable`, so `track` drops, no prompt is shown and the Settings row is hidden.

**A fresh challenge is fetched per signed request.** Challenges are not cached or reused: the contract is simpler, replay protection does not lean on the counter alone, and the cost is one extra GET per batch. A full 500-event drain — 10 batches, 20 round-trips — is not a real workload; a typical flush is one or two batches.

### 7.6 Gateway contract

Shaped to keep the Android verifier unchanged and add one platform branch.

**`POST v1/attestation/challenges`** → `{ "challenge": "<opaque string>" }`. Opaque, **not** hex-decoded. Bound to the requesting client on first use, TTL 60 s — long enough for a `generateKey` + `attestKey` round-trip to Apple.

**`POST v1/attestation/register`**, iOS body:

```json
{ "client_id": "…", "platform": "ios", "app_package": "<bundle id>",
  "attestation_type": "app_attest", "key_id": "<App Attest keyId>",
  "challenge": "…", "integrity_token": "<base64 attestation object>" }
```

`public_key` is absent — the public key travels inside the attestation's certificate, and `key_id` (Apple's base64 SHA-256 of that public key) takes its place in the digest.

Verification: decode the CBOR attestation; validate the certificate chain to Apple's App Attest root; `nonce` extension `== sha256(authenticatorData ‖ clientDataHash)` with `clientDataHash = sha256(utf8(challenge ‖ client_id ‖ key_id))`; `key_id == base64(SHA-256(credential public key))`; `rpIdHash == sha256("<team id>.<bundle id>")` for an allow-listed App ID (`io.novafoundation.novawallet`, `.dev`, `.staging`); counter `== 0`; `aaguid == appattest` (production). Store `client_id → { platform, public key, key_id, counter: 0 }`. 401/403 mean "this client is refused"; anything else is transient.

**Every request** carries `X-Client-Id`, `X-Challenge`, `X-Signature`. For `platform == ios`: decode the CBOR assertion `{ signature, authenticatorData }`; `clientDataHash = sha256(utf8(challenge ‖ client_id ‖ hex(sha256(raw body bytes))))` — the same digest the Android branch signs; verify `signature` (ECDSA P-256) over `sha256(authenticatorData ‖ clientDataHash)` with the stored public key; `rpIdHash` matches the App ID; counter **strictly greater** than the stored counter (not necessarily +1 — network reordering); store the counter; the challenge must be fresh and issued to this client. 401/403 ⇒ the client re-registers with a new key.

**Environments:** the dev gateway accepts unattested requests from dev bundle ids (mode `none`, Simulator); production never does.

**Test fixture.** An App Attest attestation and assertion cannot be produced off-device, so the deliverable for the backend is a **recorded sample** from a Debug build on a device — `{ challenge, client_id, key_id, attestation object, body, assertion }` — written by the `#if F_DEV` inspector (§8.4). Two of the five vectors in Android's `AttestationSigningTest.kt` apply unchanged to iOS client data — `bodyDigestHex` and `signingPayload` (both reproduced in §12) — while `attestationPayload` and the `sharedSecretToken` HMAC vector do not: Android digests `publicKeyBase64` where iOS digests `keyId`, and iOS implements no shared-secret mode.

**What iOS cannot reproduce from the Android contract:** a detached ECDSA signature over arbitrary bytes (App Attest signs only through assertions), `public_key` at register, and the `shared_secret` dev mode.

## 8. Consent, availability and privacy

### 8.1 States

```
                     ┌──────────────┐
  install ──────────▶│  Not asked   │  default off · track() drops · no id · no rows
                     └──┬────────┬──┘
        "Enable Analytics"      "No Thanks" (promptSeen)
                        ▼        ▼
                 ┌───────────┐  ┌──────────────────┐
                 │  Enabled  │◀▶│ Declined/Disabled│
                 └───────────┘  └──────────────────┘
                   Settings on / Settings off (wipe, §6.5)
```

`isAvailable` is a separate gate: *attestation mode usable ∧ remote config enabled*. When false there is no prompt, no Settings row, and `track()` drops regardless of consent. It is a conjunction folded into the same guard, so "off" has exactly one meaning and there is no second upload-only switch.

`promptSeen` is never cleared — re-onboarding never re-asks, and the Settings switch is the way back.

### 8.2 Nothing before consent — the proof obligations

1. `isEnabled = settingsManager.isAnalyticsEnabled` = `bool(for:) ?? false`.
2. `track` line 1 is `guard isEnabled, availability.isAvailable else { return }` — no `Date()`, no UUID, no operation.
3. `install_id`, `client_id` and the App Attest key are created only inside the flush path, whose first line is the same guard.
4. Only `AnalyticsUploader` performs network requests, and the attestation provider is reachable only from it. The remote config comes from the app's existing GitHub raw JSON, which the analytics subsystem does not initiate and which carries no user data.
5. `session_started` / `app_opened` fire in `setup()` into the same guard — dropped, not buffered. Android behaves identically.
6. `isAvailable` is the single kill path shared by the attestation ladder and the remote config, so a disabled config is indistinguishable at the guard from an unattestable device.

These are asserted by `testNothingPersistedOrSentBeforeConsent` (§12), including after an enable → disable → re-track cycle.

### 8.3 On-launch prompt

`OnLaunchAction.AnalyticsConsent` is added to `Modules/MainTabBar/OnLauchAction.swift`, with `onLaunchProcessAnalyticsConsent(_:)` on `OnLaunchActionsQueueDelegate`.

**Position:** first element of `promptActions` in `startLaunchQueue` (`MainTabBarInteractor+OnLaunch.swift:20-33`), i.e. after `LegalConsent` and before `PushNotificationsSetup` — Android's order. It sits inside the `openedPendingScreen ? [] : promptActions` short-circuit, so a consent sheet never stacks on a WalletConnect or deep-link flow; it shows next launch instead.

**Gate** (`showAnalyticsConsentOrNextAction`, mirroring `showLegalConsentOrNextAction`): `walletSettings.hasValue ∧ !analyticsPromptSeen ∧ consent.isAvailable ∧ !consent.isEnabled ∧ !didPresentLegalConsentThisLaunch ∧ legal status is .notRequired`.

The prompt is skipped on a launch where legal consent was required. `consentRequiredWrapper()` returns `false` when the documents fetch fails, so a tri-state is needed: NEW `legalConsentStatusWrapper() -> CompoundOperationWrapper<LegalConsentStatus>` (`.required` / `.notRequired` / `.unavailable`) on `LegalConsentRepositoryProtocol` — `.unavailable` ⇒ no prompt. The legal completion immediately calls `requestNextOnLaunchAction()`, so a flag set in `showLegalConsentOrNextAction` before `didRequestLegalConsentOpen()` reproduces Android's skip.

Then `securedLayer.scheduleExecution` — **not** `scheduleExecutionIfAuthorized`, which drops its closure on `false` — with `runNext()` on `false`.

**Presentation:** `didRequestAnalyticsConsentOpen()` → `MainTabBarWireframeProtocol.presentAnalyticsConsent(from:onEnable:onDecline:)` → `AnalyticsConsentSheetFactory.createConsentSheet(…)`, built like `MultisigNotificationsSheetFactory` with `MessageSheetViewFactory.createNoContentView(viewModel:allowsSwipeDown: false)` and a `.notNowAction`-shaped secondary action, handler invoked after dismissal. The button decision is forced — a swipe-down cannot dismiss the sheet.

**Outcome:** `setAnalyticsConsent(enabled:)` → `consent.setEnabled(true)` only on Enable, `markPromptSeen()` on both, then `onLaunchQueue.runNext()`. Seen is persisted on decision under `SettingsKey.analyticsPromptSeen`, so re-onboarding does not re-prompt.

**Copy** (`en.lproj/Localizable.strings` only; the other 13 catalogs follow the translation sync):

| Key | English |
|---|---|
| `analytics.prompt.title` | Help Improve Nova Wallet |
| `analytics.prompt.message` | Share anonymous usage data to help us build a better wallet.\n\n• No personal data collected\n• No wallet addresses tracked\n• You can change this anytime in Settings |
| `analytics.prompt.enable` | Enable Analytics |
| `analytics.prompt.decline` | No Thanks |
| `settings.analytics.title` | Share Anonymous Usage Data |

**Locale threading.** Strings are read through R.swift with a mandatory language list — `R.string(preferredLanguages: locale.rLanguages).localizable.analyticsPromptTitle()`, never the bare form, because the app switches language in-app. The sheet factory takes **no** `Locale` parameter: it builds `LocalizableResource { locale in … }` closures that `MessageSheetViewController` resolves at display time through `LocalizationManager.shared` and re-resolves on a language change. No `LocalizationManagerProtocol` reaches the interactor or the consent manager.

### 8.4 Settings

`SettingsRow.analytics` is added after `.appearance`, with a NEW 24 pt `iconSettingsAnalytics` PDF in `Assets.xcassets/iconsSettings/`. `SettingsParameters.isAnalyticsOn: Bool?` — `nil` omits the row when analytics is unavailable, following the `isBiometricAuthOn: Bool?` + `.map` pattern.

**One extra edit that pattern requires:** it works in `.security` only because that array ends with `.compactMap { $0 }`. The `.preferences` array (`SettingsViewModelFactory.swift:48-53`) is a plain `[SettingsCellViewModel]` literal, so it must gain the same `.compactMap { $0 }` or the optional row will not type-check.

`SettingsInteractorInputProtocol.toggleAnalytics()` and `SettingsInteractorOutputProtocol.didReceive(analyticsEnabled:)` are added. The interactor injects `AnalyticsConsentManagerProtocol`, subscribes in `setup()` with `queue: .main` so the consent sheet is reflected, and re-provides after writing — the `updatePinConfirmationSettings` shape, not `toggleHideBalances`, which never re-emits. Toggling does not touch `analyticsPromptSeen` and requires no pincode confirmation. `SettingsViewController` needs no change.

**Debug inspector (`#if F_DEV`).** `SettingsRow.analyticsDebug` in the `.about` group opens `AnalyticsDebugInspector`: queue count, last flush status, attestation mode, "Flush now" / "Clear queue", "Emit sample event", and **"Record attestation fixture"** — the deliverable for the backend team (§7.6). Its title is a debug literal, not a localized key. This screen is also the only in-app consumer of the event factories in this work.

### 8.5 Privacy manifest and App Store

`novawallet/PrivacyInfo.xcprivacy` today declares only `NSPrivacyAccessedAPICategoryUserDefaults` (1C8F.1). This block is added, leaving the existing `NSPrivacyAccessedAPITypes` array untouched:

```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeProductInteraction</string>
        <key>NSPrivacyCollectedDataTypeLinked</key><false/>
        <key>NSPrivacyCollectedDataTypeTracking</key><false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array><string>NSPrivacyCollectedDataTypePurposeAnalytics</string></array>
    </dict>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeDeviceID</string>
        <key>NSPrivacyCollectedDataTypeLinked</key><false/>
        <key>NSPrivacyCollectedDataTypeTracking</key><false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array><string>NSPrivacyCollectedDataTypePurposeAnalytics</string></array>
    </dict>
</array>
```

`NSPrivacyCollectedDataTypeDeviceID` covers the app-generated `install_id` and the attestation `client_id` (Apple's "other device-level ID"). The purpose constant is `NSPrivacyCollectedDataTypePurposeAnalytics` — there is no bare `Analytics` value.

**The extension manifest needs no change**: the facade is built from Root, `NotificationService` never touches it, and the extension collects nothing new.

**Never** list the analytics host in `NSPrivacyTrackingDomains` — iOS would block it without ATT — which is why the key is present but empty. No ATT prompt: first-party analytics is not tracking in Apple's definition. No new required-reason APIs: durations use `Date()`, never `systemUptime` or `mach_absolute_time`. Bucketed amounts are not declared as `OtherFinancialInfo`. `Info.plist` has no `NSAppTransportSecurity` key, so ATS enforces TLS.

App Store label: "Product Interaction" and "Device ID" under *Data Not Linked to You → Analytics*. Review notes describe the opt-in sheet, the toggle and the wipe.

### 8.6 Never sent

Addresses, account and meta ids, public keys, mnemonics, wallet names, raw amounts, sign payloads and calldata, exception messages, full dApp URLs (host only), IDFV, IDFA, locale, IP-derived data. The type system has no case for any of them. One caveat, matching Android: `dapp_host` for a `manual_url` open is user-typed.

## 9. Lifecycle

```
AppDelegate.didFinishLaunching
  └─ RootInteractor.setup()
       ├─ runMigrators()            (synchronous)
       ├─ analyticsFacade.setup()   session_started · app_opened · flush(.launch)
       └─ walletSettings.setup
  └─ pincode gate (SecurityLayer)
  └─ MainTabBar launch queue: LegalConsent → AnalyticsConsent → PushNotificationsSetup → AHMInfoSetup → MultisigPromo
```

- **`app_opened`** — once per process in `setup()`, `is_first_launch = settings.isAppFirstLaunch`. On a genuine first launch no consent exists, so the event is dropped; every `app_opened` that reaches the backend is therefore `false`, identical on the wire to Android's hard-coded `false`. The value is truthful here because `AppDelegate` runs `loadOnLaunch()` before `markAppFirstTimeLaunchIfNeeded()` — the same ordering `URLHandlingServiceFacade.configure()` relies on.
- **Session = foreground period.** Start: `setup()` (cold start — `willEnterForeground` is not posted on launch) and each `didReceiveWillEnterForeground`. End: `didReceiveDidEnterBackground` → `session_ended(DurationBucket(now − sessionStartedAt))` → background flush. `willResignActive` / `didBecomeActive` are ignored: they fire for Control Centre, Face ID sheets and calls, and the security layer already uses them for the privacy overlay. This is the closest match to Android's `ProcessLifecycleOwner.onStart/onStop`.
- **The pincode gate.** The facade owns a **plain** `ApplicationHandler()`, not `SecurityLayerService.shared.applicationHandlingProxy`: the proxy forwards only when authorised and releases pending closures with `false` on `didEnterBackground`, which would drop `session_ended` while locked.
- **Background flush.** `BackgroundTaskRunning` (NEW; `UIApplicationBackgroundTaskRunner` wraps `beginBackgroundTask(expirationHandler:)`). Sequence: begin task → enqueue `session_ended` → `flush(reason: .background)` (the one place the uploader is capped at `maxBatches: 1`) → end task in the completion; expiration cancels the call store and ends the task. The provider never attests or registers in background — it is skipped unless the row is already attested. Assertion generation needs no Keychain access and is expected to work there, but it is **unverified on a locked device**; a `DCError` keeps the queue and the next foreground flush retries.
- **Terminate is not observed.** `ApplicationHandler` does not deliver `willTerminateNotification`, and an observer would not help: the enqueue is asynchronous onto a serial operation queue and the process dies first, while background-then-terminate has already emitted `session_ended`. At best it would duplicate.
- **Consent flip.** `setEnabled(true)` sets `sessionStartedAt = Date()` and tracks `session_started`. `setEnabled(false)` wipes (§6.5).

## 10. Configuration

- **`ApplicationConfig.gatewayURL`** — one host serving `v1/analytics/*` and `v1/attestation/*`. Production default `https://analytics.novawallet.io/`; a dev host under `!F_RELEASE`, following the `globalConfigURL` `#if F_RELEASE` split at `ApplicationConfigs.swift:204-210`. Android keeps `ANALYTICS_HOST` and `INFRASTRUCTURE_HOST` as two build-config values defaulting to the same host. No new CI secret — iOS has no `shared_secret` mode.
- **`F_ANALYTICS`** in `OTHER_SWIFT_FLAGS` of the four `novawallet/Configs/novawallet.*.xcconfig`. Absent ⇒ `AnalyticsFacadeFactory.createDefault()` returns `NoOpAnalyticsServiceFacade`, the consent step is skipped and the Settings row is hidden. Enabled for Debug and Dev in step 6; Staging and Release are a later, separate decision together with the App Store privacy label.
- **`GlobalConfig.analytics: AnalyticsRemoteConfig? { enabled: Bool; minVersion: String? }`** — an optional field, so today's `config.json` still decodes. It is the remote kill switch and an input to `isAvailable`, not a second upload-only "off": `enabled == false` means exactly what an unattestable device means. `GlobalConfigProvider` caches after one fetch per process, so the semantics are **"takes effect on next cold start"**; fetched once in `setup()`, fail-open on error (log `.info`, availability unchanged). The queue wipe is a **one-shot on the enabled→disabled edge** — rows left by a previous, still-enabled process are cleared once.
- **Debug-only `NSAllowsLocalNetworking`** in the Debug `Info.plist` ATS block, for the dev gateway. Release keeps no `NSAppTransportSecurity` key at all.
- **`SettingsKey` additions** — `analyticsEnabled`, `analyticsPromptSeen`, `analyticsInstallId`, `gatewayAttestationClientId`. Cases in `SettingsExtension.swift` (455 lines already), accessors in NEW `SettingsExtension+Analytics.swift`.
- **`OperationManagerFacade.analyticsQueue`** — serial, `maxConcurrentOperationCount = 1`.
- **`Cuckoofile.toml`** gains `Common/Services/Analytics/AnalyticsProtocols.swift`, `Common/Services/Attestation/BackendAttestationProtocols.swift`, `Common/Services/AppAttest/AppAttestService.swift`, `Common/Services/AppAttest/DeviceCheckAttesting.swift` and `Modules/MainTabBar/MainTabBarProtocol.swift`. `SettingsProtocols.swift` and `LegalConsentRepositoryProtocols.swift` are already listed and regenerate automatically.
- **`.claude/docs` updates ship with the code** — the Root-owned facade in the sanctioned-singletons table of `services-lifecycle.md`, and the `analyticsQueue` row in the queue table of `concurrency.md`. (The "tracking from presenters" exception in `viper.md` belongs to the later integration PRs, not this work.)

## 11. Test policy

The standard is: **a test must be able to fail for a reason that matters.** A test that restates a declaration, or that asserts a factory returned the arguments it was given, is not coverage — it is a second copy of the code with worse ergonomics. Two rules make that concrete.

**Rule 1 — mock only what cannot run.** Exactly three seams get doubles, and each has a physical reason:

| Seam | Reason | Double |
|---|---|---|
| `DeviceCheckAttesting` | `DCAppAttestService.isSupported` is `false` on Simulator. This is precisely why `DAppBrowserTests` proves nothing about attestation today — the whole state machine short-circuits before it starts. | Cuckoo |
| `AnalyticsUploadOperationFactoryProtocol` | real HTTP | Cuckoo, capturing bodies and returning canned statuses |
| `BackendAttestationRemoteFactoryProtocol` | real HTTP | Cuckoo |

Everything else runs for real:

- **CoreData is not mocked.** Queue tests drive the real `CoreDataAnalyticsEventQueue` over `UserDataStorageTestFacade`'s in-memory store, with the real mapper, real sort descriptors and real slice semantics. Mocking `AnalyticsEventQueueProtocol` in a queue test would test the mock.
- **Settings are real** — the existing `InMemorySettingsManager` (`SettingsTests.swift:101`).
- **The session tracker is not faked.** It *is* the `ApplicationHandlerDelegate`, so tests call `didReceiveDidEnterBackground(notification:)` on the real object. Nothing about `ApplicationHandler` needs a double, which is fortunate — it lives in Foundation-iOS and Cuckoo cannot generate from an SPM dependency.
- **Time is a `() -> Date` init parameter**, not a stubbed protocol. It has no maintenance surface, so it does not fall under Rule 2.

**Rule 2 — no hand-written protocol doubles.** Per the project rule: if Cuckoo can generate it, its file goes in `Cuckoofile.toml` and the test uses the generated mock. Convenience lives in a small extension on the generated type, following `novawalletTests/Mocks/MockApplicationService.swift` — e.g. `MockAnalyticsTrackingProtocol.recordingTracked()` returning a captured array. The draft's `RecordingAnalyticsService`, `InMemoryAnalyticsEventQueue`, `NoOpBackgroundTaskRunner` and `StubApplicationHandler` are all replaced by generated mocks or by real objects.

Wrappers run with `OperationQueue().addOperations(_, waitUntilFinished: true)` and `extractNoCancellableResultData()`.

## 12. The tests

Not an exhaustive list — these are the ones without which the design is unproven. Each names the failure it exists to catch.

**Consent and privacy**

- `testNothingPersistedOrSentBeforeConsent` — real queue, real settings, mocked transport and DeviceCheck. Fire 50 events and force both flush triggers; assert queue count is 0, the transport was never invoked, no `analyticsInstallId` key exists, and `generateKey` was never called. Then repeat every assertion after an enable → disable → 50-more-events cycle. *Catches: any code path that records, identifies or transmits before opt-in, including a regression that buffers instead of dropping.*
- `testOptOutWipesEverything` — enable, enqueue, start a flush, opt out mid-flight; assert the in-flight call store was cancelled, the queue is empty, `analyticsInstallId` and `gatewayAttestationClientId` are gone, the key row is deleted, and the abandoned batch was never dropped from a live queue. *Catches: a rotation-instead-of-delete regression, and a wipe that races an upload.*
- `testAvailabilityGateDropsRegardlessOfConsent` — consent on, `isAvailable` false; assert `track` drops. *Catches: a second, upload-only "off" creeping back in.*

**Event model**

- `testEventCatalogSerialization` — a **data-driven table** of `(factory invocation, expected serialized object)` across all 42 events. Asserts the output of code — factory, key mapping, value encoding, nil-omission, ISO-8601 with milliseconds — not that an enum has the cases it declares. *Catches: wire drift from Android and the backend, which is the only way this contract breaks.*
- `testPersistedPayloadIsByteStable` — `encode(decode(encode(e))) == encode(e)` across the catalog. Asserts byte equality, **not** value equality, because decoding is deliberately lossy (§4.3). *Catches: a payload written by one app version uploading differently after being read by another.*
- `testUnknownEventNameStillUploads` — a row whose `name` this build does not know serializes and uploads unchanged. *Catches: a downgrade or staged-rollout wedge.*
- `AnalyticsBucketsTests`, `AssetCategoryClassifierTests` — boundary values on both sides of every bucket edge, and the NATIVE → STABLE → WRAPPED → `W`+NATIVE → other ordering. *Catches: an off-by-one against Android's inclusive/exclusive bounds.*

**Queue** — against the real in-memory store

- FIFO order survives out-of-order timestamps (sequence, not clock)
- trim keeps the newest 500 and drops the oldest
- `peek(50)` returns the oldest 50 in order
- `drop(ids)` removes exactly those rows
- a poison row (undecodable payload) is deleted by id and the queue keeps draining
- the sequence counter reseeds correctly from the newest row on a fresh process

**Service**

- `feature_opened` collapse: same feature is skipped, an untracked screen leaves `currentFeature` unchanged, a different feature emits
- flush policy: threshold at 50, interval at 5 min against the injected clock, first consented event of a process always flushes (`lastFlushAt == .distantPast`), `background` caps at one batch
- `testEventPersistsWhileUploadInFlight` — a slow mocked upload, an event tracked during it, assert the row landed. *Catches: collapsing the two queues into one.*
- `testFacadeFactoryReturnsSameInstance` — `createDefault() === createDefault()`. *Catches: a second facade with its own lock, session and queue.*
- background flush brackets the work in a background task and ends it in the completion; expiration cancels the call store and still ends the task. *Catches: an expired task leaking, or a flush that outlives its assertion.*
- `testKillSwitchWipesOnce` — a queue holding rows from a previously-enabled process is cleared exactly once on the enabled→disabled edge, and a second disabled launch clears nothing. *Catches: a wipe that re-runs every launch, or one that never runs.*

**Transport**

- `testSignedBytesAreSentBytes` — capture the `Data` handed to the signer and the `httpBody` on the request; assert identity. *Catches: a re-encode inside the request closure racing the signature against `JSONEncoder`'s key order — a failure that breaks every request in production and is invisible in review.*
- one test per outcome row of §6.3: 2xx drops exactly the peeked ids and continues; 401/403 clears the queue and calls `markUnattested`; other 4xx drops one batch and continues; 5xx and transport errors keep everything and stop
- `maxBatches` is honoured and the loop stops at the first error
- the real request factory sets `httpBody` verbatim, the three attestation headers, `Content-Type` and a 15 s timeout

**Attestation**

- `AttestationClientDataTests` against the Android vectors, transcribed verbatim from
  `infrastructure/src/test/java/io/novafoundation/nova/infrastructure/attestation/AttestationSigningTest.kt`
  at PR #2324 head `108899870`. Inputs: challenge `TEST_CHALLENGE_abc123`, client id
  `6f2c1e4a-0000-4000-8000-000000000001`, body `{"v":1,"platform":"android","app_version":"10.9.1"}`
  as UTF-8. Expected, lowercase hex, unprefixed:

  | Function | Digest |
  |---|---|
  | `bodyDigestHex(body)` | `2c3d64eac83fc3f8bc8fe383d202bf4cc4b5b3c88328c87cc6695f8ecb49f4e7` |
  | `bodyDigestHex(Data())` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
  | `sha256(assertionClientData(challenge:clientId:body:))` | `4469fb60ce2ad38af216bc5ac89188071392af288cfaa99eb62532843d9c5c92` |

  *Catches: a UTF-8, hex-case or concatenation-order slip that no other test would see and that only manifests as a 401 from the gateway.*
- `BackendAttestationProviderTests` — attest-once-then-assert; the key row is saved with `isAttested: false` **before** register; `markUnattested` forces a *new* key id next time; register 400 keeps the row and reuses the same key; register 401 sets `rejectedForProcess` and later calls short-circuit without touching the network; `invalidKeyId` discards the row at most once per launch; `forgetClient` regenerates the client id; unsupported yields `nil` headers
- `BackendAttestationModeResolverTests` — all four input combinations
- `AppAttestServiceTests`, the first coverage this file has ever had: the `clientData` closure receives the generated key id; the hash passed to DeviceCheck is SHA-256 of that client data; `DCError.invalidKey` → `.invalidKeyId`; `DCError.serverUnavailable` → `.serviceUnavailable`

**Storage migration**

- `AnalyticsUserModel21MigrationTests` — build a real model-20 store, run `UserStorageMigrator`, assert it opens under model 21 and surviving entities keep their rows; separately, assert that opening a model-20 file with the model-21 `.momd` throws and leaves the file intact (the push-extension window, §5.1)

**Surfaces**

- MainTabBar prompt policy: no wallet, already seen, legal sheet shown this launch, legal status `.unavailable`, `isAvailable` false, already enabled — each suppresses the prompt; decline marks seen without enabling
- `SettingsTests` — toggle round-trip, and the row is absent when `isAnalyticsOn` is nil
- `RootTests` — the facade stub's `setup()` is called, and no storage access occurs before the migrators complete

**Deliberately not tested,** recorded so nobody adds them later as filler: settings accessor getters and setters; that `Observable` notifies its observers (framework code); that an enum case has the raw value it is declared with; that a factory returns a struct containing the arguments passed to it (`testEventCatalogSerialization` covers this where it means something); the consent sheet's view models; the Settings icon asset.

Anything shipped by this work that ends up with neither a direct test nor coverage through one of the above must be named in the PR description with a reason.

## 13. Delivery order

Seven steps, merging in order, each rebasing on the previous and verified by a build. `novawallet.xcodeproj` is hand-managed, so every step carries a `project.pbxproj` hunk.

**0 — Remove dApp attestation.** §7.1 in full, plus the `DAppBrowserTests` setup. No new code. Standalone and revertible.

**1 — Storage.** `MultiassetUserDataModel21` (adds `CDAnalyticsEvent` and `CDAppAttestKey`, drops `CDAppAttestBrowserSettings`), `UserStorageVersion.version22`, `UserStorageParams.modelVersion`, `AnalyticsPendingEvent` + mapper, `AppAttestKeySettings` + `AppAttestKeyMapper`, `SortDescriptor.analyticsEventsBySequence`, `CoreDataAnalyticsEventQueue`, `OperationManagerFacade.analyticsQueue`. Tests: the queue block and the migration block of §12. **The model bump is permanent once a build ships.**

**2 — Event model and catalog.** All of §4: names, keys, value types, enums, buckets, classifier, the ten `Model/Events/*` factory files, envelope encoding, `ISO8601MillisFormatter`. Tests: the event-model block of §12.

**3 — Service core.** `AnalyticsProtocols.swift`, consent manager, identity, availability provider, `AnalyticsService`, session tracker, `BackgroundTaskRunner`, facade + `NoOpAnalyticsServiceFacade` + `AnalyticsFacadeFactory`, the `SettingsKey` cases and accessors. The uploader is a protocol here; its implementation lands in step 5. Tests: the consent, service and session blocks of §12. Cuckoofile gains `AnalyticsProtocols.swift`.

**4 — App Attest reshape.** `DeviceCheckAttesting`, the client-data-first `AppAttestService`, deletion of `AppAttestClientHashing`, `AppAttestError` pruning, `AppAttestAttestation`. Tests: `AppAttestServiceTests`. Cuckoofile gains both files.

**5 — Attestation provider and transport.** `AttestationClientData`, `BackendAttestationIdentity`, `BackendAttestationRemoteFactory`, `BackendAttestationModeResolver`, `BackendAttestationProvider`, `AnalyticsUploader`, `AnalyticsUploadOperationFactory`, `AttestationHeaderKey`, `AnalyticsTransportError`, `ApplicationConfig.gatewayURL`. **The only step blocked on the gateway contract (§14).** Tests: the transport and attestation blocks of §12.

**6 — Consent surfaces.** Root wiring (`RootPresenterFactory`, `RootInteractor.setup()` after `runMigrators()`), `OnLaunchAction.AnalyticsConsent` with its delegate, gate and presentation, `LegalConsentStatus` + `legalConsentStatusWrapper()`, `AnalyticsConsentSheetFactory`, the five strings, the `iconSettingsAnalytics` asset, the Settings `.analytics` row plus the `.preferences` `compactMap`, the `#if F_DEV` inspector row, `GlobalConfig.analytics`, the privacy manifest block, and `F_ANALYTICS` for Debug and Dev. First build that can send anything. Tests: the surfaces block of §12.

If the gateway contract stalls, step 6 can land against a stubbed uploader rather than blocking — the consent surfaces, queue and identity are all independently verifiable.

Staging and Release enablement of `F_ANALYTICS`, and the App Store privacy label, are a separate decision after this work, taken together with the privacy sign-off.

## 14. Open items for the backend

Contractual values this document cannot fix on its own. Step 5 is blocked until they are confirmed.

1. The exact App ID allow-list contents for dev, staging and production.
2. The meanings of 401 vs 403, and which register status codes mean "client rejected" as opposed to transient.
3. Whether a per-event `id` (the enqueue UUID) is accepted for de-duplication — this work delivers at-least-once (§6.3).
4. That `nft_count` is read as an integer. Android's Gson round-trip through `Map<String, Any?>` sends `3.0`; iOS sends `3`.
5. The challenge TTL, if 60 s is not workable server-side. Note that this design fetches a **fresh challenge per signed request** and does not rely on reuse (§7.5).
6. Receipt of the recorded device fixture from the `#if F_DEV` inspector (§7.6), which is the only way the gateway's iOS verifier can be tested before the app ships.
