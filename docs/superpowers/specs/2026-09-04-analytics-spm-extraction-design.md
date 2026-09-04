# Analytics & App Attest — Local SPM Package Extraction

Status: design approved, not yet implemented
Branch: `feature/analytics` (head `c5b906fa7`)
Date: 2026-09-04

## 1. Why

The analytics feature landed as 22 tasks inside the app target, under
`Common/Services/{Analytics,Attestation,AppAttest}` (~4,300 LOC, 37+11 files).
Nothing about it is Nova-domain specific: it knows about events, a queue, a
gateway and a device attestation, and it never touches `ChainModel`,
`ChainAsset` or `MetaAccountModel`.

Two packages are extracted from it, staged in-repo now and intended for
publication later as standalone `novasamatech/*` repositories. That target sets
the constraint that drives every decision below: **no app type may cross the
boundary.**

`docs/code/project-layout.md` currently states "One Xcode project, no local SPM
packages." This change makes that false and the doc must be updated with it.

## 2. Goal and non-goals

**Goal.** Two local SPM packages under `Packages/`, each self-contained enough to
be lifted into its own repository without code changes.

**Non-goals.** No behaviour change to analytics, consent, opt-out or attestation,
with the single deliberate exception in §5.2. No new events, no new call sites,
no change to the gateway contract. No renaming of existing public types beyond
adding `public`.

## 3. Package layout

```
Packages/
  NovaAppAttest/        deps: Operation-iOS, Keystore-iOS, logger-ios, DeviceCheck
  NovaAnalytics/        deps: NovaAppAttest, Operation-iOS, Keystore-iOS,
                              Foundation-iOS, logger-ios, CoreData, UIKit
```

`swift-tools-version: 5.9`, `platforms: [.iOS(.v16)]`, `swiftLanguageVersion:
.v5` — matching the app.

`NovaAnalytics` depends on `NovaAppAttest`. The dependency is real and
compile-time: `AnalyticsUploader` consumes `BackendAttestationProviderProtocol`
and `AttestationHeaderKey`. It is not inverted, because the gateway attestation
flow is reusable "authenticate this install to a Nova backend" infrastructure,
not analytics-private glue.

### 3.1 `NovaAppAttest` (12 files)

| Source | Files |
|---|---|
| `AppAttest/` | `AppAttestError`, `AppAttestModel`, `AppAttestService`, `DeviceCheckAttesting` |
| `Attestation/` | `AttestationClientData`, `BackendAttestationIdentity`, `BackendAttestationModeResolver`, `BackendAttestationProtocols`, `BackendAttestationProvider`, `BackendAttestationRemoteFactory` |
| `Storage/` | `AppAttestKeySettings` (from `AppAttestLocalSettings.swift`), **new** `SettingsAppAttestKeyRepository` |

### 3.2 `NovaAnalytics` (34 moved + 2 pulled in + 4 new)

Everything under `Common/Services/Analytics` except `AnalyticsFacadeFactory` and
`Debug/`, plus:

- `AnalyticsPendingEventMapper` (from `Common/Storage/EntityToModel/`)
- the `analyticsEventsBySequence` sort descriptor (from `Common/Extension/Storage/`)
- **new**: `AnalyticsConfiguration`, `AnalyticsRemoteSettings`,
  `AnalyticsStorageFacade`, `CDAnalyticsEvent` (hand-written, see §5.1)
- `NoOpAnalyticsServiceFacade` — a null object belongs with its protocol

### 3.3 What stays in the app

| File | Reason |
|---|---|
| `Modules/AnalyticsConsent/*` | `R.string`, `MessageSheetViewFactory`, `LocalizationManager` |
| `AnalyticsFacadeFactory` | `#if F_ANALYTICS`, the `-UNITTEST` guard, the singleton, the remote-settings adapter |
| `Debug/AnalyticsDebugInspectorViewController` | `#if F_DEV`, UIKit, app singletons |
| `Debug/AnalyticsAttestationFixtureRecorder` | `#if F_DEV` — a package cannot read an app xcconfig flag, and debug code should not ship in a published binary |
| `Modules/Root/RootInteractor`, MainTabBar prompt | call sites, unchanged |

Deleted outright: `AppAttestKeyMapper`, `CDAppAttestKey`, `CDAnalyticsEvent`
(the app copies).

## 4. Crossing the boundary

Six app couplings, six resolutions.

| App dependency | Resolution |
|---|---|
| `ApplicationConfig.gatewayURL`, app version, store URL, `OperationManagerFacade.{sharedDefaultQueue,analyticsQueue}`, `isReleaseBuild` | injected `AnalyticsConfiguration` struct |
| `GlobalConfigProviding` (remote kill switch) | package protocol `AnalyticsRemoteSettings` + app-side adapter |
| `Logger` / `LoggerProtocol` | `SDKLoggerProtocol` from `logger-ios` — see §4.1 |
| `UserDataStorageFacade` | package-owned store — see §5.1 |
| `SettingsManagerProtocol`, `ApplicationHandler` | already SDK (`Keystore-iOS`, `Foundation-iOS`); no work |
| `F_ANALYTICS`, `F_RELEASE` | stay in `AnalyticsFacadeFactory`; `isReleaseBuild` becomes a config field |

`AnalyticsServiceFacade` loses `static let shared` and its `private init()`, and
becomes a plain type taking `AnalyticsConfiguration`. The singleton and the
build-flag gating move up into the app's `AnalyticsFacadeFactory`.

### 4.1 Logging

Both packages take `SDKLoggerProtocol` from **`logger-ios`** (module `SDKLogger`,
one file, zero transitive dependencies, `public` convenience extension).

No adapter is needed: `LoggerProtocol` and `SDKLoggerProtocol` declare identical
method sets, which is why the existing
`novawallet/Common/Extension/SubstrateSdk/Logger+Substrate.swift` conformance is
empty. The app passes `Logger.shared` directly.

Not taken from `SubstrateSdk`, for two reasons: it would make an analytics
package depend on the entire Substrate SDK, and on 4.5.2 that copy's convenience
extension is **internal**, forcing the four-argument
`error(message:file:function:line:)` form at every call site.

**Transitional wrinkle, self-clearing.** Until the substrate-sdk v5 migration
lands, two same-named `SDKLoggerProtocol`s coexist — SubstrateSdk's and
`SDKLogger`'s. `Logger` conforms to both (the existing extension plus one new
empty one), and any file importing both modules qualifies as
`SDKLogger.SDKLoggerProtocol`; in practice that is `AnalyticsFacadeFactory` only.
On v5, `substrate-sdk-ios` no longer defines the protocol and both it and
`Operation-iOS` consume `logger-ios`, so the duplicate conformance is deleted
then.

## 5. Storage

### 5.1 Analytics gets its own CoreData store

New `AnalyticsDataModel.xcdatamodeld`, a single version, one entity
`CDAnalyticsEvent` (`identifier`, `name`, `payload`, `sequence`, `timestamp`)
copied verbatim from `MultiassetUserDataModel21`. Shipped as a `.process`
resource in `NovaAnalytics` and loaded from `Bundle.module`.

A package-owned `AnalyticsStorageFacade` wraps `CoreDataService` over a separate
`AnalyticsDataModel.sqlite`. Two `CoreDataPersistentSettings` values differ from
`UserDataStorageFacade` deliberately, because this is a queue of unsent telemetry
rather than user data:

- `incompatibleModelStrategy: .removeStore` (vs `.ignore`) — a future
  incompatible model drops unsent events instead of crashing at launch
- `excludeFromiCloudBackup: true` — unsent analytics must not enter backups

The store directory is injected through `AnalyticsConfiguration`. The app passes
the same app-group CoreData directory it uses today, so the file lands beside
`UserDataModel.sqlite`. No migration exists or is needed: the store is new.

**SwiftPM gotcha.** SwiftPM compiles `.xcdatamodeld` with `momc` but does **not**
run Xcode's CoreData codegen. The entity must therefore be
`codeGenerationType="none"` and `CDAnalyticsEvent` becomes a hand-written ~15-line
`NSManagedObject` subclass inside the package. Missing this surfaces only as
"cannot find `CDAnalyticsEvent` in scope" after everything else is wired.

**Debug inspector.** `AnalyticsDebugInspectorViewController.createDefault()`
currently bypasses the facade and builds a *second* `CoreDataAnalyticsEventQueue`
directly off `UserDataStorageFacade.shared`. That cannot survive a package-owned
store. Rather than making the package expose its storage facade publicly to serve
a debug screen, `AnalyticsServiceFacade` grows a narrow read-only
`debugPendingEvents()`. This also removes an existing inconsistency: the facade's
own comment states it is "the only place in the app that touches `.shared`, so
every call site shares one lock, one call store, one session and one queue", which
the inspector violates today.

### 5.2 App-attest key row moves to `SettingsManager`

`CDAppAttestKey` and `AppAttestKeyMapper` are deleted. `AppAttestKeySettings`
(`identifier`, `keyId`, `isAttested`) is persisted through
`SettingsManagerProtocol` instead.

`SettingsManagerProtocol` offers no key enumeration, so per-row keys could not
implement `deleteAllOperation()`. Storage is therefore **one settings key holding
a `[String: AppAttestKeySettings]` map**, JSON-encoded via the protocol's existing
`Codable` convenience:

- `fetchOperation(by:)` — dictionary lookup
- `saveOperation` — merge
- `deleteAllOperation` — a single `removeValue`, which is more obviously correct
  than the CoreData "delete every row, not just this client's" version

The interface is preserved. A new
`SettingsAppAttestKeyRepository: DataProviderRepositoryProtocol` (modelled on the
app's existing `InMemoryDataProviderRepository`) is injected as
`AnyDataProviderRepository<AppAttestKeySettings>`, exactly as the CoreData
repository is today. **`BackendAttestationProvider` changes by zero lines**, so
every epoch guard, the mutex ordering, and the key-row/cache-window fix survive
untouched.

The repository holds its own `NSLock` around the read-modify-write of the map,
because the provider signs on a shared concurrent queue and UserDefaults gives
per-key atomicity only.

No security change: `keyId` is a Secure Enclave key *identifier*, never key
material, and the sqlite it leaves was equally unencrypted and equally backed up.

This is the **only behaviour change in the whole plan**. Everything else is a move
with a compiler proof.

### 5.3 `UserDataModel` stops changing

With both entities gone, `MultiassetUserDataModel21`'s only remaining delta from
v20 is dropping the already-dead `CDAppAttestBrowserSettings` — not worth a
migration for every install. Therefore:

- delete `MultiassetUserDataModel21.xcdatamodel`
- revert `UserStorageParams.modelVersion` to `.version21`
- delete the `UserStorageVersion.version22` case and its `nextVersion` transition
- delete `AnalyticsUserModel21MigrationTests`

`CDAppAttestBrowserSettings` stays as an unused entity in v20, where it already
is on every shipped install.

**Net effect: this branch's CoreData migration surface goes from one shipped
user-store migration to zero.**

## 6. Tests

Package test targets take **no external test dependencies** — plain XCTest and
hand-written doubles. Neither `Package.swift` gains a Cuckoo dependency and
neither package gets a `Cuckoofile.toml`. Cuckoo remains in the app test target
only.

XCTest is retained rather than Swift Testing so that test *bodies* — including
assertions produced by four adversarial review rounds — move verbatim, and the
diff stays confined to double construction and verification.

Of the 22 files under the three test directories:

- **20 move in full.** `AnalyticsAttestationFixtureRecorderTests` stays app-side with the
  recorder. `AnalyticsFacadeFactoryTests` is **split**: its two factory tests stay
  app-side, its `NoOpAnalyticsServiceFacade` test moves.
- **12 move verbatim** — they never imported Cuckoo.
- **8 need hand-written doubles**, converting 21 `stub` blocks, 40 `when(` and
  38 `verify(` call sites.

Nine protocols get doubles:

| Package | Protocols |
|---|---|
| `NovaAppAttest` | `AppAttestServiceProtocol`, `DeviceCheckAttesting`, `BackendAttestationIdentityProtocol`, `BackendAttestationRemoteFactoryProtocol`, `BackendAttestationProviderProtocol` |
| `NovaAnalytics` | `AnalyticsEventQueueProtocol`, `AnalyticsTrackingProtocol`, `AnalyticsUploadOperationFactoryProtocol`, `AnalyticsUploading`, plus its own double for `BackendAttestationProviderProtocol` |

Pattern: `final class XSpy: X` holding closure-shaped stubs
(`var enqueueStub: (String, Date, Data) -> CompoundOperationWrapper<Void>`) plus a
`private(set) var calls: [Call]` array. `when(...).thenReturn(x)` becomes a
closure assignment; `verify(...)` becomes `XCTAssertEqual` against the recorded
array — which reads more directly than `ArgumentCaptor` + `allValues`.

No other test infrastructure moves: every helper these files use is either a
generated Cuckoo mock (replaced), `InMemorySettingsManager` (Keystore-iOS,
SDK-provided), or `AnalyticsTestFixture` (a local helper that travels with them).
**Nothing depends on `novawalletTests/Mocks/`.**

The app-side `AnalyticsAttestationFixtureRecorderTests` keeps its Cuckoo mocks;
`Cuckoofile.toml` repoints at the package's now-`public` protocol sources with a
plain `imports` entry rather than `testableImports`.

## 7. Tooling

- **Lint/format**: no config change. `.swiftlint.yml` declares only `excluded:`
  and `Scripts/lint.sh` runs from the repo root, so `Packages/` is covered
  automatically. Add `Packages/*/Tests` to `excluded:` to match `novawalletTests`.
- **pbxproj**: two `XCLocalSwiftPackageReference` entries plus product
  dependencies on the app target, hand-edited. Never the `xcodeproj` gem.
- **R.swift**: unaffected — the consent strings stay app-side.
- **Privacy manifests**: the app already declares
  `NSPrivacyAccessedAPICategoryUserDefaults`, so §5.2 adds no app-level
  obligation. For standalone publication each package ships its own
  `PrivacyInfo.xcprivacy` — `NovaAnalytics` mirroring the analytics collection
  entries, `NovaAppAttest` declaring UserDefaults (CA92.1). Apple merges package
  manifests into the app's.

## 8. Sequencing

Six ordered steps, each independently green and separately committed.

1. Add `logger-ios`; add the second `Logger` conformance.
2. Create `NovaAppAttest`; move `AppAttest/` + `Attestation/` sources and tests;
   swap the logger type; wire pbxproj.
3. **Replace the CoreData attest repository with `SettingsAppAttestKeyRepository`**;
   delete `CDAppAttestKey` and `AppAttestKeyMapper`.
4. Create `NovaAnalytics`; move sources, the new model, the hand-written
   `CDAnalyticsEvent`, and the tests.
5. Facade takes `AnalyticsConfiguration`; app-side `AnalyticsFacadeFactory` and
   remote-settings adapter; inspector switches to `debugPendingEvents()`.
6. Delete `MultiassetUserDataModel21`, revert `modelVersion`, drop the
   `.version22` case and the migration test; update
   `docs/code/project-layout.md` and `docs/code/build-and-tooling.md`.

## 9. Verification

- Full unit suite green at every step (701 tests at `c5b906fa7`).
- Step 3 is the only behaviour change and gets its own review attention:
  **revert-verify** the locking and the delete-all semantics — confirm each new
  test fails when its fix is reverted.
- Steps 2, 4, 5 are moves; the compiler is the proof, and any test that needs its
  *assertions* changed (as opposed to its doubles) is a red flag to stop and
  explain why.
- Release build to confirm `#if F_ANALYTICS` / `#if F_DEV` gating still excludes
  the debug inspector and recorder.
- `GiftsSyncServiceTests` is pre-existing flaky; it is not a regression signal.

## 10. Risks

| Risk | Mitigation |
|---|---|
| Settings-backed attest store re-derives a hardened race | Interface preserved so `BackendAttestationProvider` is untouched; own `NSLock`; revert-verification |
| SwiftPM CoreData codegen absent | Hand-written `NSManagedObject` subclass, called out in §5.1 |
| Duplicate `SDKLoggerProtocol` until v5 | Two empty conformances; module-qualified in the one file that imports both; deleted on v5 |
| Hand-written doubles drift from protocols | Compiler enforces conformance; a protocol change breaks the double immediately |
| pbxproj hand-editing | Small, reviewable diff; build after each step |

## 11. Resolved decisions

Recorded so they are not relitigated:

1. Extraction target — **standalone published SPM repos**, hence no app type crosses.
2. Gateway attestation layer lives in **`NovaAppAttest`**, not analytics.
3. Attest key storage — **`SettingsManager`**, not a second CoreData model
   (chosen over the recommendation in §5.2's risk column).
4. Boundary shape — **full-stack packages**; the facade moves in behind injected config.
5. Logger — **`logger-ios` / `SDKLogger`**, not SubstrateSdk's copy.
6. Debug inspector reads via a **narrow facade method**, not an exposed store.
7. Package tests — **no external dependencies**; Cuckoo stays app-only.
8. App-side recorder test — **keeps Cuckoo**, pointed at the packages' public sources.

No open questions.
