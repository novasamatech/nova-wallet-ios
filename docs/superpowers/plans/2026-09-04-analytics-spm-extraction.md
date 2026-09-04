# Analytics & App Attest SPM Extraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the analytics and app-attest subsystems out of the `novawallet` app target into two local SPM packages that could be lifted into standalone repositories without code changes.

**Architecture:** `Packages/NovaAppAttest` holds the DeviceCheck wrapper and the Nova gateway register/sign flow. `Packages/NovaAnalytics` depends on it and holds the event catalogue, queue, uploader, session tracker, consent and the facade. No app type crosses the boundary: app singletons become an injected `AnalyticsConfiguration`, the remote kill switch becomes a package protocol with an app-side adapter, and logging comes from the standalone `logger-ios` SDK. Analytics gets its own CoreData store; the app-attest key row moves to `SettingsManager` behind the unchanged repository interface.

**Tech Stack:** Swift 5 language mode, iOS 16, SwiftPM local packages, CoreData (Operation-iOS `CoreDataService`), XCTest, Keystore-iOS `SettingsManagerProtocol`, `logger-ios` `SDKLogger`.

**Spec:** `docs/superpowers/specs/2026-09-04-analytics-spm-extraction-design.md`

## Global Constraints

- Packages live under `Packages/`. `swift-tools-version: 5.9`, `platforms: [.iOS(.v16)]`, `swiftLanguageVersion: .v5`.
- **No app type may cross into a package.** Not `Logger`, `ApplicationConfig`, `GlobalConfig`, `UserDataStorageFacade`, `OperationManagerFacade`, `R.string`, `SettingsKey`, `ApplicationServiceProtocol`.
- **Package test targets take no external test dependencies.** Plain XCTest and hand-written doubles. Never add Cuckoo to a `Package.swift`. Cuckoo stays in the app test target only.
- Keep XCTest; do not migrate to Swift Testing. Test *bodies* move verbatim — only double construction and verification change.
- `project.pbxproj` is hand-edited. Never use the `xcodeproj` gem.
- Logger dependency: `.package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")`, product `SDKLogger`.
- Build/test destination must be pinned by simulator **id**, not name. Discover with `xcrun simctl list devices available`.
- Set `RUN_IN_CI=true` on xcodebuild invocations to skip the SwiftLint/SwiftFormat build phases.
- **Never edit any file while a background `xcodebuild` is in flight** — it fails the build with "modified during the build". Wait for completion.
- `GiftsSyncServiceTests` is pre-existing flaky. It is not a regression signal; do not investigate it.
- Commit messages: lowercase imperative subject, body explaining *why*, ending with:
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`

## Spec Addenda

Discovered while writing this plan; they extend §4 of the spec and are implemented in Task 5 unless noted.

| Crossing | Resolution | Task |
|---|---|---|
| `AnalyticsServiceFacadeProtocol: ApplicationServiceProtocol` (app-defined) | Declare `setup()` / `throttle()` directly on the package protocol, drop the inheritance. `RootInteractor.analyticsFacade.setup()` still compiles unchanged. | 4 |
| `settingsManager.isAppFirstLaunch` (app extension, `Common/Extension/SettingsExtension.swift`) | `AnalyticsConfiguration.isFirstLaunch: () -> Bool`, supplied by the app factory. | 5 |
| `GlobalConfig` / `AnalyticsRemoteConfig` (app models) | `AnalyticsRemoteSettings.createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool>` returns the resolved flag, never the config object. | 5 |
| `Bundle(for: AnalyticsServiceFacade.self)` for `CFBundleShortVersionString` | **Trap**: inside a package this resolves to the *package* bundle and returns `""`. `appVersion` comes from `AnalyticsConfiguration`. | 5 |
| `logger: LoggerProtocol = Logger.shared` default arguments | Become required `SDKLoggerProtocol` parameters — a package cannot reference `Logger.shared`. | 2, 4 |

## File Structure

```
Packages/NovaAppAttest/
  Package.swift
  Sources/NovaAppAttest/
    AppAttest/       AppAttestError, AppAttestModel, AppAttestService, DeviceCheckAttesting
    Attestation/     AttestationClientData, BackendAttestationIdentity,
                     BackendAttestationModeResolver, BackendAttestationProtocols,
                     BackendAttestationProvider, BackendAttestationRemoteFactory
    Storage/         AppAttestKeySettings, SettingsAppAttestKeyRepository
    Resources/       PrivacyInfo.xcprivacy
  Tests/NovaAppAttestTests/
    Doubles/         AppAttestServiceSpy, DeviceCheckAttestingSpy,
                     BackendAttestationIdentitySpy, BackendAttestationRemoteFactorySpy
    AppAttestServiceTests, AttestationClientDataTests, BackendAttestationIdentityTests,
    BackendAttestationModeResolverTests, BackendAttestationProviderTests,
    SettingsAppAttestKeyRepositoryTests

Packages/NovaAnalytics/
  Package.swift                        depends on NovaAppAttest
  Sources/NovaAnalytics/
    Model/ Network/ Storage/ Helpers/  (moved wholesale)
    Configuration/   AnalyticsConfiguration, AnalyticsRemoteSettings
    Storage/         AnalyticsStorageFacade, CDAnalyticsEvent, AnalyticsPendingEventMapper,
                     NSSortDescriptor+Analytics
    Resources/       AnalyticsDataModel.xcdatamodeld, PrivacyInfo.xcprivacy
    AnalyticsServiceFacade, AnalyticsService, AnalyticsUploader, ... NoOpAnalyticsServiceFacade
  Tests/NovaAnalyticsTests/
    Doubles/         AnalyticsEventQueueSpy, AnalyticsTrackingSpy, AnalyticsUploadingSpy,
                     AnalyticsUploadOperationFactorySpy, BackendAttestationProviderSpy
    (20 moved test files + AnalyticsTestFixture)

novawallet/  (retained)
  Common/Extension/SDKLogger/Logger+SDKLogger.swift          new, Task 1
  Common/Services/Analytics/AnalyticsFacadeFactory.swift     rewritten, Task 5
  Common/Services/Analytics/AnalyticsRemoteSettingsAdapter.swift  new, Task 5
  Common/Services/Analytics/Debug/*                          retargeted, Task 5
```

---

### Task 1: Add `logger-ios` and the second `Logger` conformance

Both packages log through `SDKLoggerProtocol`. It must be the **`logger-ios`** copy, not
`SubstrateSdk`'s: a package must not depend on the whole Substrate SDK, and SubstrateSdk's
convenience extension is `internal`, so outside that module only the four-argument
`error(message:file:function:line:)` form is visible.

Until the substrate-sdk v5 migration lands, two same-named `SDKLoggerProtocol`s coexist.
`Logger` conforms to both. This is deliberate and self-clearing.

**Files:**
- Modify: `novawallet.xcodeproj/project.pbxproj` (add remote package reference + product dependency)
- Create: `novawallet/Common/Extension/SDKLogger/Logger+SDKLogger.swift`
- Test: `novawalletTests/Common/Logger/LoggerSDKConformanceTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `Logger` conforms to `SDKLogger.SDKLoggerProtocol`, so Tasks 2 and 4 can pass `Logger.shared` into package types typed as `SDKLoggerProtocol`.

- [ ] **Step 1: Write the failing test**

Create `novawalletTests/Common/Logger/LoggerSDKConformanceTests.swift`:

```swift
import XCTest
import SDKLogger
@testable import novawallet

final class LoggerSDKConformanceTests: XCTestCase {
    func testLoggerSatisfiesSDKLoggerProtocol() {
        let logger: SDKLogger.SDKLoggerProtocol = Logger.shared

        // The one-argument convenience form is `public` in logger-ios and `internal` in
        // SubstrateSdk. If this compiles, the conformance resolved against logger-ios.
        logger.info("conformance probe")

        XCTAssertTrue(logger is Logger)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" \
  -only-testing:novawalletTests/LoggerSDKConformanceTests 2>&1 | xcbeautify --quiet
```

Expected: FAIL — `no such module 'SDKLogger'`.

- [ ] **Step 3: Add the package reference**

Hand-edit `novawallet.xcodeproj/project.pbxproj`. Add to `XCRemoteSwiftPackageReference` section
(copy the shape of the existing `Cuckoo` entry at the `repositoryURL` key):

```
		0CAA10012E7A0001007E41C4 /* XCRemoteSwiftPackageReference "logger-ios" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/novasamatech/logger-ios";
			requirement = {
				kind = exactVersion;
				version = 0.0.1;
			};
		};
```

Add to `XCSwiftPackageProductDependency`:

```
		0CAA10022E7A0002007E41C4 /* SDKLogger */ = {
			isa = XCSwiftPackageProductDependency;
			package = 0CAA10012E7A0001007E41C4 /* XCRemoteSwiftPackageReference "logger-ios" */;
			productName = SDKLogger;
		};
```

Then reference `0CAA10012E7A0001007E41C4` in the project's `packageReferences` array and
`0CAA10022E7A0002007E41C4` in the app target's `packageProductDependencies` array, plus a
`PBXBuildFile` entry in the app target's Frameworks phase — mirroring exactly how `Cuckoo`
is wired at `project.pbxproj:1428`, `13217`, `30943`, `39113`.

- [ ] **Step 4: Add the conformance**

Create `novawallet/Common/Extension/SDKLogger/Logger+SDKLogger.swift`:

```swift
import SDKLogger

/// `Logger` already conforms to `SubstrateSdk.SDKLoggerProtocol` in
/// `Common/Extension/SubstrateSdk/Logger+Substrate.swift`. Until the substrate-sdk v5
/// migration lands, that module ships its own identically-named protocol, so `Logger`
/// must satisfy both. Both extensions are empty because `LoggerProtocol` already declares
/// the same five methods.
///
/// On v5, `substrate-sdk-ios` stops declaring the protocol and consumes `logger-ios`
/// instead. Delete `Logger+Substrate.swift` then and keep this file.
extension Logger: SDKLogger.SDKLoggerProtocol {}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" \
  -only-testing:novawalletTests/LoggerSDKConformanceTests 2>&1 | xcbeautify --quiet
```

Expected: PASS. `Package.resolved` gains a `logger-ios` pin during resolution — commit it.

- [ ] **Step 6: Commit**

```bash
git add novawallet.xcodeproj/project.pbxproj \
  novawallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  novawallet/Common/Extension/SDKLogger/Logger+SDKLogger.swift \
  novawalletTests/Common/Logger/LoggerSDKConformanceTests.swift
git commit -m "$(cat <<'MSG'
take the sdk logger protocol from logger-ios

The analytics and app attest packages log through SDKLoggerProtocol, and
it has to come from somewhere a package can depend on. SubstrateSdk
carries a copy, but depending on the whole Substrate SDK for a logging
protocol is the wrong shape, and that copy's convenience extension is
internal, so outside the module only the four argument form is visible.

logger-ios is the same protocol as a standalone package: one file, no
transitive dependencies, public convenience extension. It is also where
the ecosystem has landed, since on v5 substrate-sdk stops declaring the
protocol and both it and Operation-iOS consume logger-ios.

Logger needs no adapter because LoggerProtocol declares the identical
method set, which is why both conformances are empty. The duplicate goes
away with the v5 migration.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

> **Ordering note — this plan reorders spec §8.** The spec put package creation (step 2)
> before the storage swap (step 3). That is not buildable: `BackendAttestationProviderTests`
> constructs a real `CoreDataRepository<AppAttestKeySettings, CDAppAttestKey>`, and a package
> cannot see the app's CoreData entity, so the test cannot move until the swap has happened.
> Doing the behaviour change first — in the app target, against the full suite — is also
> safer: the only risky step runs in familiar territory and every later step is a pure move.

### Task 2: Move the app-attest key row to `SettingsManager`

The **only behaviour change in this plan.** Everything after it is a move the compiler
checks. Give it its own review pass.

The interface is deliberately preserved: `BackendAttestationProvider` keeps taking
`AnyDataProviderRepository<AppAttestKeySettings>` and **changes by zero lines**, so its epoch
guards, mutex ordering and the key-row/cache-window fix survive untouched.

**Files:**
- Create: `novawallet/Common/Services/AppAttest/SettingsAppAttestKeyRepository.swift`
- Create: `novawalletTests/Common/Services/AppAttest/SettingsAppAttestKeyRepositoryTests.swift`
- Modify: `novawallet/Common/Services/Analytics/AnalyticsServiceFacade.swift:65-69`
- Modify: `novawalletTests/Common/Services/Attestation/BackendAttestationProviderTests.swift:177-300`
- Delete: `novawallet/Common/Storage/EntityToModel/AppAttestKeyMapper.swift`
- Delete: the `CDAppAttestKey` entity from `MultiassetUserDataModel21.xcdatamodel/contents`

**Interfaces:**
- Consumes: `AppAttestKeySettings` (`identifier: String`, `keyId: String`, `isAttested: Bool`; `Codable`, `Equatable`, `Identifiable`).
- Produces: `SettingsAppAttestKeyRepository(settingsManager: SettingsManagerProtocol)` conforming to `DataProviderRepositoryProtocol` with `Model == AppAttestKeySettings`. Task 3 moves it into the package unchanged.

- [ ] **Step 1: Write the failing test**

Create `novawalletTests/Common/Services/AppAttest/SettingsAppAttestKeyRepositoryTests.swift`:

```swift
import XCTest
import Operation_iOS
import Keystore_iOS
@testable import novawallet

final class SettingsAppAttestKeyRepositoryTests: XCTestCase {
    private let operationQueue = OperationQueue()

    private func makeRow(_ id: String, attested: Bool = true) -> AppAttestKeySettings {
        AppAttestKeySettings(identifier: id, keyId: "key-\(id)", isAttested: attested)
    }

    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }

    func testSavedRowIsFetchedBackById() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())
        let row = makeRow("gateway|client-a")

        _ = try run(repository.saveOperation({ [row] }, { [] }))

        let fetched = try run(
            repository.fetchOperation(by: { "gateway|client-a" }, options: RepositoryFetchOptions())
        )

        XCTAssertEqual(fetched, row)
    }

    func testMissingIdentifierFetchesNil() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        let fetched = try run(
            repository.fetchOperation(by: { "absent" }, options: RepositoryFetchOptions())
        )

        XCTAssertNil(fetched)
    }

    func testSaveMergesRatherThanReplacingTheMap() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        _ = try run(repository.saveOperation({ [self.makeRow("a")] }, { [] }))
        _ = try run(repository.saveOperation({ [self.makeRow("b")] }, { [] }))

        XCTAssertEqual(try run(repository.fetchCountOperation()), 2)
    }

    /// The opt-out wipe. `forgetClient()` must clear rows belonging to *every* client id,
    /// not just the current one: a cycle whose delete failed has left one behind.
    func testDeleteAllClearsEveryClientsRow() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        _ = try run(repository.saveOperation({ [self.makeRow("a"), self.makeRow("b")] }, { [] }))
        _ = try run(repository.deleteAllOperation())

        XCTAssertEqual(try run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [])
    }

    func testSaveDeleteIdsBlockRemovesNamedRowsOnly() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        _ = try run(repository.saveOperation({ [self.makeRow("a"), self.makeRow("b")] }, { [] }))
        _ = try run(repository.saveOperation({ [] }, { ["a"] }))

        let remaining = try run(repository.fetchAllOperation(with: RepositoryFetchOptions()))

        XCTAssertEqual(remaining.map(\.identifier), ["b"])
    }

    /// A relaunch: rows persist in the settings store, every in-memory latch is gone.
    func testRowsSurviveANewRepositoryOverTheSameSettings() throws {
        let settings = InMemorySettingsManager()
        let first = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(first.saveOperation({ [self.makeRow("a")] }, { [] }))

        let second = SettingsAppAttestKeyRepository(settingsManager: settings)
        let fetched = try run(
            second.fetchOperation(by: { "a" }, options: RepositoryFetchOptions())
        )

        XCTAssertEqual(fetched?.keyId, "key-a")
    }

    /// The provider signs on a shared *concurrent* queue and UserDefaults gives per-key
    /// atomicity only, so an unguarded read-modify-write of the map loses writes.
    func testConcurrentSavesDoNotLoseRows() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())
        let concurrent = OperationQueue()
        concurrent.maxConcurrentOperationCount = 8

        let operations = (0 ..< 64).map { index in
            repository.saveOperation({ [self.makeRow("row-\(index)")] }, { [] })
        }

        concurrent.addOperations(operations, waitUntilFinished: true)

        XCTAssertEqual(try run(repository.fetchCountOperation()), 64)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" \
  -only-testing:novawalletTests/SettingsAppAttestKeyRepositoryTests 2>&1 | xcbeautify --quiet
```

Expected: FAIL — `cannot find 'SettingsAppAttestKeyRepository' in scope`.

- [ ] **Step 3: Implement the repository**

Create `novawallet/Common/Services/AppAttest/SettingsAppAttestKeyRepository.swift`:

```swift
import Foundation
import Operation_iOS
import Keystore_iOS

/// Persists the app attest key rows as one JSON-encoded `[String: AppAttestKeySettings]`
/// map under a single settings key.
///
/// One map rather than a key per row because `SettingsManagerProtocol` offers no key
/// enumeration: `deleteAllOperation()` must clear every client's row, and with per-row keys
/// there would be no way to find them. As one map it is a single `removeValue`.
///
/// The lock is not optional. `BackendAttestationProvider` signs on a shared *concurrent*
/// queue and UserDefaults gives per-key atomicity only, so an unguarded read-modify-write
/// of the map drops concurrent saves.
final class SettingsAppAttestKeyRepository {
    static let storageKey = "appAttestKeys"

    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - Private

private extension SettingsAppAttestKeyRepository {
    /// Callers must hold `mutex`.
    func loadMap() -> [String: AppAttestKeySettings] {
        settingsManager.value(of: [String: AppAttestKeySettings].self, for: Self.storageKey) ?? [:]
    }

    /// Callers must hold `mutex`. An empty map removes the key outright rather than storing
    /// `{}`, so an opt-out leaves nothing behind in the settings dump.
    func storeMap(_ map: [String: AppAttestKeySettings]) {
        if map.isEmpty {
            settingsManager.removeValue(for: Self.storageKey)
        } else {
            settingsManager.set(value: map, for: Self.storageKey)
        }
    }

    func withMap<T>(_ body: (inout [String: AppAttestKeySettings]) -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        var map = loadMap()
        let result = body(&map)
        storeMap(map)

        return result
    }

    func readMap() -> [String: AppAttestKeySettings] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return loadMap()
    }

    /// Stable order so slice requests and `fetchAllOperation` are deterministic. The
    /// provider never depends on it; the tests do.
    func sortedRows() -> [AppAttestKeySettings] {
        readMap().values.sorted { $0.identifier < $1.identifier }
    }
}

// MARK: - DataProviderRepositoryProtocol

extension SettingsAppAttestKeyRepository: DataProviderRepositoryProtocol {
    typealias Model = AppAttestKeySettings

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<AppAttestKeySettings?> {
        ClosureOperation { [weak self] in
            let identifier = try modelIdClosure()

            return self?.readMap()[identifier]
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[AppAttestKeySettings]> {
        ClosureOperation { [weak self] in
            self?.sortedRows() ?? []
        }
    }

    func fetchOperation(
        by request: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[AppAttestKeySettings]> {
        ClosureOperation { [weak self] in
            let rows = self?.sortedRows() ?? []
            let ordered = request.reversed ? rows.reversed().map { $0 } : rows

            guard request.offset < ordered.count else {
                return []
            }

            let end = min(request.offset + request.count, ordered.count)

            return Array(ordered[request.offset ..< end])
        }
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [AppAttestKeySettings],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            // Evaluated before the lock is taken: these closures carry the provider's epoch
            // guards and may throw, and a throw must not leave the map half-written.
            let updated = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            self?.withMap { map in
                for row in updated {
                    map[row.identifier] = row
                }

                for identifier in deletedIds {
                    map[identifier] = nil
                }
            }
        }
    }

    func replaceOperation(
        _ newModelsBlock: @escaping () throws -> [AppAttestKeySettings]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            let rows = try newModelsBlock()

            self?.withMap { map in
                map = rows.reduce(into: [:]) { accumulator, row in
                    accumulator[row.identifier] = row
                }
            }
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.readMap().count ?? 0
        }
    }
}
```

`deleteAllOperation()` comes free from Operation-iOS's protocol extension over
`replaceOperation { [] }` — do not implement it.

- [ ] **Step 4: Run the new tests to verify they pass**

```bash
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" \
  -only-testing:novawalletTests/SettingsAppAttestKeyRepositoryTests 2>&1 | xcbeautify --quiet
```

Expected: PASS, all 7.

- [ ] **Step 5: Revert-verify the lock**

Temporarily delete the `mutex.lock()` / `defer { mutex.unlock() }` pair from `withMap`, rerun
`testConcurrentSavesDoNotLoseRows`, confirm it **fails**, then restore the lock. A test that
still passes with its fix reverted is not testing the fix.

- [ ] **Step 6: Repoint the two call sites**

In `novawallet/Common/Services/Analytics/AnalyticsServiceFacade.swift`, replace the
`attestKeyRepository` block (lines 65-69) with:

```swift
        let attestKeyRepository = SettingsAppAttestKeyRepository(settingsManager: settingsManager)
```

and keep passing `AnyDataProviderRepository(attestKeyRepository)` to
`BackendAttestationProvider`. `BackendAttestationProvider` itself is not edited.

In `novawalletTests/Common/Services/Attestation/BackendAttestationProviderTests.swift`:
move `let settings = existing?.settings ?? InMemorySettingsManager()` (currently line 295)
**above** the repository construction, delete `let facade: UserDataStorageTestFacade` from
`Fixture`, delete the `existing?.facade ?? UserDataStorageTestFacade()` line and the whole
`coreDataRepository` block, and replace them with:

```swift
        // A second fixture over the same settings is what a relaunch looks like: the rows
        // survive, every in-memory latch is gone.
        let realRepository = AnyDataProviderRepository(
            SettingsAppAttestKeyRepository(settingsManager: settings)
        )
```

Also drop `facade: facade` from the `Fixture(...)` construction and the `facade` field.

- [ ] **Step 7: Delete the CoreData entity and its mapper**

```bash
git rm novawallet/Common/Storage/EntityToModel/AppAttestKeyMapper.swift
```

Remove the `<entity name="CDAppAttestKey" …>` element (3 attributes) from
`novawallet/Common/Storage/UserDataModel.xcdatamodeld/MultiassetUserDataModel21.xcdatamodel/contents`,
and remove its `PBXBuildFile`/`PBXFileReference` entries for the mapper from `project.pbxproj`.
Leave `CDAnalyticsEvent` — Task 4 removes it.

- [ ] **Step 8: Run the full unit suite**

```bash
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" 2>&1 | xcbeautify --quiet
```

Expected: PASS. `GiftsSyncServiceTests` may fail; pre-existing flaky, not a regression.

- [ ] **Step 9: Commit**

```bash
git add -A novawallet novawalletTests novawallet.xcodeproj/project.pbxproj
git commit -m "$(cat <<'MSG'
store the app attest key row in settings rather than core data

The key row is three scalars keyed by gateway and client id, with no
relationship to anything else in UserDataModel, and it is about to move
into a package that must own its own persistence. A whole CoreData model
for it would be ninety lines of stack for one row.

SettingsManagerProtocol has no key enumeration, so a key per row could
not implement deleteAllOperation, and that wipe has to clear every
client's row rather than the current one. Storing a single JSON encoded
map under one key makes the wipe a single removeValue and the lookup a
dictionary read.

The repository interface is unchanged, so BackendAttestationProvider is
not edited at all and its epoch guards, mutex ordering and the key row
cache window fix all survive as they are. The lock is load bearing: the
provider signs on a shared concurrent queue and UserDefaults gives per
key atomicity only.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: Create `NovaAppAttest` and move the sources and tests into it

A pure move. Every behaviour change already happened in Task 2, so if any test needs its
**assertions** changed here (as opposed to its double construction), stop and explain why.

**Files:**
- Create: `Packages/NovaAppAttest/Package.swift`
- Create: `Packages/NovaAppAttest/Sources/NovaAppAttest/{AppAttest,Attestation,Storage}/…` (12 files, moved)
- Create: `Packages/NovaAppAttest/Sources/NovaAppAttest/Resources/PrivacyInfo.xcprivacy`
- Create: `Packages/NovaAppAttest/Tests/NovaAppAttestTests/Doubles/…` (4 files, new)
- Create: `Packages/NovaAppAttest/Tests/NovaAppAttestTests/…` (6 test files, moved)
- Delete: `novawallet/Common/Services/{AppAttest,Attestation}/` entirely
- Delete: `novawalletTests/Common/Services/{AppAttest,Attestation}/` entirely
- Modify: `novawallet.xcodeproj/project.pbxproj`, `Cuckoofile.toml`, `.swiftlint.yml`

**Interfaces:**
- Consumes: `SDKLoggerProtocol` (Task 1), `SettingsAppAttestKeyRepository` (Task 2).
- Produces: module `NovaAppAttest` exporting `AppAttestServiceProtocol`, `AppAttestService`, `AppAttestKeyId`, `AppAttestAssertion`, `AppAttestAttestation`, `AppAttestServiceError`, `DeviceCheckAttesting`, `AppAttestKeySettings`, `SettingsAppAttestKeyRepository`, `BackendAttestationProviderProtocol`, `BackendAttestationProvider`, `BackendAttestationIdentityProtocol`, `BackendAttestationIdentity`, `BackendAttestationRemoteFactoryProtocol`, `BackendAttestationRemoteFactory`, `BackendAttestationModeResolver`, `BackendAttestationMode`, `BackendAttestationError`, `BackendAttestationRegisterRequest`, `AttestationHeaderKey`, `AttestationClientData`. Task 4 consumes `BackendAttestationProviderProtocol` and `AttestationHeaderKey`; Task 5 consumes `AppAttestService`, `BackendAttestationModeResolver`, `BackendAttestationRemoteFactory`, `BackendAttestationIdentity`.

- [ ] **Step 1: Create the package manifest**

Create `Packages/NovaAppAttest/Package.swift`:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAppAttest",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAppAttest", targets: ["NovaAppAttest"])
    ],
    dependencies: [
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")
    ],
    targets: [
        .target(
            name: "NovaAppAttest",
            dependencies: [
                .product(name: "Operation-iOS", package: "Operation-iOS"),
                .product(name: "Keystore-iOS", package: "Keystore-iOS"),
                .product(name: "SDKLogger", package: "logger-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NovaAppAttestTests",
            dependencies: ["NovaAppAttest"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
```

Verify the product names against `novawallet.xcodeproj/project.pbxproj` — the app already
links `Operation_iOS` and `Keystore_iOS`, whose SPM **product** names use hyphens while the
**module** names use underscores.

- [ ] **Step 2: Move the sources and make them public**

```bash
mkdir -p Packages/NovaAppAttest/Sources/NovaAppAttest/{AppAttest,Attestation,Storage,Resources}
git mv novawallet/Common/Services/AppAttest/AppAttestError.swift \
       novawallet/Common/Services/AppAttest/AppAttestModel.swift \
       novawallet/Common/Services/AppAttest/AppAttestService.swift \
       novawallet/Common/Services/AppAttest/DeviceCheckAttesting.swift \
       Packages/NovaAppAttest/Sources/NovaAppAttest/AppAttest/
git mv novawallet/Common/Services/Attestation/*.swift \
       Packages/NovaAppAttest/Sources/NovaAppAttest/Attestation/
git mv novawallet/Common/Services/AppAttest/AppAttestLocalSettings.swift \
       novawallet/Common/Services/AppAttest/SettingsAppAttestKeyRepository.swift \
       Packages/NovaAppAttest/Sources/NovaAppAttest/Storage/
```

Then in every moved file:

1. Add `public` to each type, protocol, `enum`, `struct`, initialiser and member listed in
   the **Produces** block above. Protocol *requirements* need no `public`, but the protocol
   itself and every conforming type's implementations do.
2. Replace `import Foundation`-adjacent `LoggerProtocol` with `SDKLoggerProtocol`, adding
   `import SDKLogger`.
3. **Delete every `= Logger.shared` default argument** — a package cannot reference the
   app's `Logger`. In `BackendAttestationProvider.init` and `AppAttestService`, `logger`
   becomes a required parameter.
4. `Bundle = .main` default arguments stay: `.main` is the *app's* bundle at runtime even
   from inside a package, which is what `BackendAttestationProvider` wants for the app id.

- [ ] **Step 3: Add the privacy manifest**

Create `Packages/NovaAppAttest/Sources/NovaAppAttest/Resources/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Write the hand-written doubles**

Create `Packages/NovaAppAttest/Tests/NovaAppAttestTests/Doubles/AppAttestDoubles.swift`:

```swift
import Foundation
import Operation_iOS
@testable import NovaAppAttest

/// Replaces `MockDeviceCheckAttesting`. Cuckoo is deliberately absent from package test
/// targets: these packages are staged for publication, and a consumer's CI must not have to
/// pull a code-generation plugin to run their tests.
final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    var isSupported: Bool = true

    var generateKeyResult: Result<String, Error> = .success("key-id")
    var attestKeyResult: Result<Data, Error> = .success(Data("attestation".utf8))
    var generateAssertionResult: Result<Data, Error> = .success(Data("assertion".utf8))

    private let mutex = NSLock()
    private var recordedClientDataHashes: [Data] = []

    var clientDataHashes: [Data] {
        mutex.lock()
        defer { mutex.unlock() }
        return recordedClientDataHashes
    }

    private func record(_ hash: Data) {
        mutex.lock()
        defer { mutex.unlock() }
        recordedClientDataHashes.append(hash)
    }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        switch generateKeyResult {
        case let .success(keyId): completionHandler(keyId, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    func attestKey(
        _: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        record(clientDataHash)

        switch attestKeyResult {
        case let .success(data): completionHandler(data, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    func generateAssertion(
        _: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        record(clientDataHash)

        switch generateAssertionResult {
        case let .success(data): completionHandler(data, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }
}

/// Replaces `MockAppAttestServiceProtocol`.
final class AppAttestServiceSpy: AppAttestServiceProtocol {
    var isSupported: Bool = true

    /// Set to throw from inside the wrapper rather than at composition time — the provider's
    /// epoch guards run at execution time and the tests depend on that ordering.
    var attestationResult: Result<AppAttestAttestation, Error> =
        .success(AppAttestAttestation(keyId: "key-id", attestation: Data("attestation".utf8)))
    var assertionResult: Result<AppAttestAssertion, Error> = .success(Data("assertion".utf8))

    private let mutex = NSLock()
    private var recordedAssertionKeyIds: [AppAttestKeyId] = []

    var assertionKeyIds: [AppAttestKeyId] {
        mutex.lock()
        defer { mutex.unlock() }
        return recordedAssertionKeyIds
    }

    func createAttestationWrapper(
        using keyId: AppAttestKeyId?,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        let result = attestationResult

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            // Calling clientData is what exercises the digest construction and the epoch
            // gate the provider installs inside that closure.
            _ = try clientData(keyId ?? "key-id")

            return try result.get()
        })
    }

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion> {
        let result = assertionResult

        mutex.lock()
        recordedAssertionKeyIds.append(keyId)
        mutex.unlock()

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try clientData()

            return try result.get()
        })
    }
}

/// Replaces `MockBackendAttestationRemoteFactoryProtocol`.
final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    var challengeResult: Result<String, Error> = .success("challenge")
    var registerError: Error?

    /// Records requests that actually reached the transport. Counting
    /// `createRegisterOperation` calls would not do: the operation is *constructed* before
    /// an opt-out lands, and what must not happen is its request closure producing a value.
    var onRegisterRequest: ((BackendAttestationRegisterRequest) -> Void)?

    /// Runs before the challenge wrapper resolves — the hook the opt-out tests fire.
    var onChallenge: (() -> Void)?

    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        let result = challengeResult
        let hook = onChallenge

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            hook?()

            return try result.get()
        })
    }

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        let error = registerError
        let onRequest = onRegisterRequest

        return ClosureOperation {
            let request = try requestClosure()

            onRequest?(request)

            if let error {
                throw error
            }
        }
    }
}

/// Replaces `MockBackendAttestationIdentityProtocol`. Prefer the real
/// `BackendAttestationIdentity` over an `InMemorySettingsManager` where a test only needs
/// working behaviour; this spy is for asserting the mint/forget call pattern.
final class BackendAttestationIdentitySpy: BackendAttestationIdentityProtocol {
    var consentEpoch: Int = 0
    var storedClientId: String? = "client-id"

    private(set) var clientIdCallCount = 0
    private(set) var forgetCallCount = 0
    private(set) var allowCreationCallCount = 0

    func clientId() -> String? {
        clientIdCallCount += 1

        return storedClientId
    }

    func forgetClientId() {
        forgetCallCount += 1
        storedClientId = nil
        consentEpoch += 1
    }

    func allowCreation() {
        allowCreationCallCount += 1
        storedClientId = "client-id"
    }
}
```

- [ ] **Step 5: Move the tests and convert their doubles**

```bash
mkdir -p Packages/NovaAppAttest/Tests/NovaAppAttestTests/Doubles
git mv novawalletTests/Common/Services/AppAttest/AppAttestServiceTests.swift \
       novawalletTests/Common/Services/AppAttest/SettingsAppAttestKeyRepositoryTests.swift \
       novawalletTests/Common/Services/Attestation/*.swift \
       Packages/NovaAppAttest/Tests/NovaAppAttestTests/
```

In each moved file replace `@testable import novawallet` with
`@testable import NovaAppAttest`, delete `import Cuckoo`, and convert:

| Cuckoo | Replacement |
|---|---|
| `let m = MockDeviceCheckAttesting()` | `let m = DeviceCheckAttestingSpy()` |
| `stub(m) { $0.isSupported.get.thenReturn(false) }` | `m.isSupported = false` |
| `stub(m) { $0.generateKey(completionHandler: anyClosure()).then { ... } }` | `m.generateKeyResult = .failure(error)` |
| `verify(m, times(1)).generateAssertion(...)` | `XCTAssertEqual(m.assertionKeyIds.count, 1)` |
| `verify(m, never()).createRegisterOperation(any())` | `XCTAssertTrue(recorder.recorded.isEmpty)` |

`BackendAttestationProviderTests` keeps its existing hand-written `SaveHookRepository`,
`OneShotHook` and `RegisterRecorder` — they were never Cuckoo-generated (the file's own
comment notes `DataProviderRepositoryProtocol` has an associated type and Cuckoo cannot
generate it). Wire `RegisterRecorder` to `BackendAttestationRemoteFactorySpy.onRegisterRequest`.

- [ ] **Step 6: Wire the package into the project**

Hand-edit `novawallet.xcodeproj/project.pbxproj`:

1. Add an `XCLocalSwiftPackageReference` with `relativePath = Packages/NovaAppAttest;` and
   list it in the project's `packageReferences`.
2. Add an `XCSwiftPackageProductDependency` with `productName = NovaAppAttest;` (no
   `package` key for local references) and list it in the app target's
   `packageProductDependencies` plus a `PBXBuildFile` in its Frameworks phase.
3. Remove every `PBXBuildFile` and `PBXFileReference` for the 12 moved source files and the
   6 moved test files, and their `PBXGroup` children entries.

In `Cuckoofile.toml`, delete the three moved entries at lines 135-137 (`AppAttestService`,
`DeviceCheckAttesting`, `BackendAttestationProtocols`) and re-add them pointing at the
package, so the app-side `AnalyticsAttestationFixtureRecorderTests` still gets its mocks:

```toml
sources = [
    # …
    "Packages/NovaAppAttest/Sources/NovaAppAttest/AppAttest/AppAttestService.swift",
    "Packages/NovaAppAttest/Sources/NovaAppAttest/Attestation/BackendAttestationProtocols.swift",
]
```

Add `"NovaAppAttest"` to the `imports` array — **not** `testableImports`: these protocols
are `public` now, so a plain import suffices.

Add to `.swiftlint.yml` `excluded:`:

```yaml
  - Packages/NovaAppAttest/Tests
```

- [ ] **Step 7: Add `import NovaAppAttest` to the remaining app consumers**

`novawallet/Common/Services/Analytics/AnalyticsServiceFacade.swift`,
`novawallet/Common/Services/Analytics/AnalyticsUploader.swift`,
`novawallet/Common/Services/Analytics/AnalyticsProtocols.swift`,
`novawallet/Common/Services/Analytics/Network/AnalyticsUploadOperationFactory.swift`,
`novawallet/Common/Services/Analytics/Debug/AnalyticsDebugInspectorViewController.swift`,
`novawallet/Common/Services/Analytics/Debug/AnalyticsAttestationFixtureRecorder.swift`,
and `novawalletTests/Common/Services/Analytics/AnalyticsAttestationFixtureRecorderTests.swift`.

Pass `logger: Logger.shared` explicitly wherever a `= Logger.shared` default was deleted.

- [ ] **Step 8: Run the package tests, then the full app suite**

```bash
swift test --package-path Packages/NovaAppAttest
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" 2>&1 | xcbeautify --quiet
```

Expected: both PASS. If `swift test` fails to resolve, run the package tests through
xcodebuild instead — the app project pins the same dependency versions.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'MSG'
move app attest and gateway attestation into a local spm package

The DeviceCheck wrapper and the gateway register and sign flow know
nothing about the wallet domain, and they are the half of the analytics
stack another Nova backend call could reuse. Lift them into
NovaAppAttest, staged in the repository now and shaped so it can become a
standalone novasamatech package without further edits.

Nothing changes behaviourally: the sources move, gain public, and take
SDKLoggerProtocol instead of the app's LoggerProtocol. The Logger.shared
default arguments go, because a package cannot reach the app's logger,
so callers pass it explicitly.

Package test targets take no external test dependencies, so the Cuckoo
mocks become hand written spies. The app side fixture recorder test
keeps its generated mocks, with Cuckoofile pointed at the package's now
public protocol sources through a plain import.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 4: Create `NovaAnalytics` with its own CoreData store

Moves the analytics mechanism and gives it a package-owned store. The facade stays in the
app for one more task — it needs `AnalyticsConfiguration`, which Task 5 introduces — so at
the end of this task the app's `AnalyticsServiceFacade` implements a *package* protocol.
That intermediate state builds and passes.

**Files:**
- Create: `Packages/NovaAnalytics/Package.swift`
- Create: `Packages/NovaAnalytics/Sources/NovaAnalytics/…` (34 moved + 2 pulled in + 4 new)
- Create: `Packages/NovaAnalytics/Sources/NovaAnalytics/Resources/AnalyticsDataModel.xcdatamodeld/`
- Create: `Packages/NovaAnalytics/Tests/NovaAnalyticsTests/…`
- Delete: `CDAnalyticsEvent` from `MultiassetUserDataModel21.xcdatamodel/contents`
- Delete: `novawallet/Common/Storage/EntityToModel/AnalyticsPendingEventMapper.swift`, the
  `analyticsEventsBySequence` member of `novawallet/Common/Extension/Storage/SortDescriptor+Storage.swift`

**Interfaces:**
- Consumes: `NovaAppAttest` (`BackendAttestationProviderProtocol`, `AttestationHeaderKey`), `SDKLoggerProtocol`.
- Produces: module `NovaAnalytics` exporting `AnalyticsEvent` and its factories, `AnalyticsServiceFacadeProtocol`, `AnalyticsTrackingProtocol`, `AnalyticsConsentManagerProtocol`, `AnalyticsConsentManager`, `AnalyticsIdentity`, `AnalyticsAvailabilityProvider`, `AnalyticsService`, `AnalyticsUploader`, `AnalyticsSessionTracker`, `AnalyticsFlushReason`, `AnalyticsPendingEvent`, `CoreDataAnalyticsEventQueue`, `AnalyticsStorageFacade`, `UIApplicationBackgroundTaskRunner`. Task 5 consumes all of these.

- [ ] **Step 1: Write the failing store test**

Create `Packages/NovaAnalytics/Tests/NovaAnalyticsTests/AnalyticsStorageFacadeTests.swift`:

```swift
import XCTest
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageFacadeTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Proves the .xcdatamodeld actually compiled into the package bundle. SwiftPM runs
    /// `momc` on it, but only if it is declared as a resource — and if it is not, this is
    /// the only place that surfaces before a device crash.
    func testModelLoadsFromThePackageBundle() throws {
        let facade = AnalyticsStorageFacade(storeDirectory: directory)

        let repository = facade.createEventRepository()
        let operation = repository.fetchCountOperation()

        let queue = OperationQueue()
        queue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), 0)
    }

    func testEventRoundTripsThroughTheStore() throws {
        let facade = AnalyticsStorageFacade(storeDirectory: directory)
        let repository = facade.createEventRepository()
        let queue = OperationQueue()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 0, unique: "u"),
            sequence: 0,
            name: "app_opened",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            payload: Data("{}".utf8)
        )

        let save = repository.saveOperation({ [event] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try save.extractNoCancellableResultData()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)

        XCTAssertEqual(try fetch.extractNoCancellableResultData(), [event])
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
swift test --package-path Packages/NovaAnalytics
```

Expected: FAIL — the package does not exist yet.

- [ ] **Step 3: Create the package manifest**

Create `Packages/NovaAnalytics/Package.swift`:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAnalytics",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAnalytics", targets: ["NovaAnalytics"])
    ],
    dependencies: [
        .package(path: "../NovaAppAttest"),
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/Foundation-iOS", exact: "1.2.0"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")
    ],
    targets: [
        .target(
            name: "NovaAnalytics",
            dependencies: [
                "NovaAppAttest",
                .product(name: "Operation-iOS", package: "Operation-iOS"),
                .product(name: "Keystore-iOS", package: "Keystore-iOS"),
                .product(name: "Foundation-iOS", package: "Foundation-iOS"),
                .product(name: "SDKLogger", package: "logger-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NovaAnalyticsTests",
            dependencies: ["NovaAnalytics"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
```

- [ ] **Step 4: Create the CoreData model and the privacy manifest**

Create the directory
`Packages/NovaAnalytics/Sources/NovaAnalytics/Resources/AnalyticsDataModel.xcdatamodeld/AnalyticsDataModel.xcdatamodel/`
containing a file named exactly `contents`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="24299" systemVersion="25A362" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
    <entity name="CDAnalyticsEvent" representedClassName="CDAnalyticsEvent" syncable="YES" codeGenerationType="none">
        <attribute name="identifier" optional="YES" attributeType="String"/>
        <attribute name="name" optional="YES" attributeType="String"/>
        <attribute name="payload" optional="YES" attributeType="Binary"/>
        <attribute name="sequence" attributeType="Integer 64" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="timestamp" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    </entity>
</model>
```

And `AnalyticsDataModel.xcdatamodeld/.xccurrentversion`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>_XCCurrentVersionName</key>
	<string>AnalyticsDataModel.xcdatamodel</string>
</dict>
</plist>
```

`codeGenerationType` is **`none`**, not `class`. SwiftPM compiles the model with `momc` but
does not run Xcode's CoreData code generator, so the subclass must be written by hand.

Create `Packages/NovaAnalytics/Sources/NovaAnalytics/Resources/PrivacyInfo.xcprivacy`,
mirroring the analytics entries already in `novawallet/PrivacyInfo.xcprivacy`. Apple merges
package manifests into the host app's, so a standalone consumer inherits the declaration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeProductInteraction</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<false/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
			</array>
		</dict>
	</array>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

Copy the exact `NSPrivacyCollectedDataType` entries from `novawallet/PrivacyInfo.xcprivacy`
rather than trusting the sample above — the app declares 13 and only the analytics-related
ones belong here.

- [ ] **Step 5: Hand-write the managed object subclass**

Create `Packages/NovaAnalytics/Sources/NovaAnalytics/Storage/CDAnalyticsEvent.swift`:

```swift
import Foundation
import CoreData

/// Written by hand because SwiftPM does not run Xcode's CoreData code generator — it only
/// compiles the model with `momc`. The model therefore declares
/// `codeGenerationType="none"`, and this must stay in step with it.
@objc(CDAnalyticsEvent)
final class CDAnalyticsEvent: NSManagedObject {
    @NSManaged var identifier: String?
    @NSManaged var name: String?
    @NSManaged var payload: Data?
    @NSManaged var sequence: Int64
    @NSManaged var timestamp: Date?
}
```

- [ ] **Step 6: Implement the storage facade**

Create `Packages/NovaAnalytics/Sources/NovaAnalytics/Storage/AnalyticsStorageFacade.swift`:

```swift
import Foundation
import CoreData
import Operation_iOS

/// The analytics queue's own store, separate from the app's `UserDataModel.sqlite`.
///
/// Two settings differ from the app's user store deliberately, because this holds unsent
/// telemetry rather than user data: an incompatible future model drops the queue instead of
/// crashing at launch, and unsent events must not enter iCloud backups.
public final class AnalyticsStorageFacade {
    public static let databaseName = "AnalyticsDataModel.sqlite"

    private let databaseService: CoreDataServiceProtocol

    public init(storeDirectory: URL) {
        guard let modelURL = Bundle.module.url(
            forResource: "AnalyticsDataModel",
            withExtension: "momd"
        ) else {
            fatalError("AnalyticsDataModel.momd missing from the package bundle")
        }

        let settings = CoreDataPersistentSettings(
            databaseDirectory: storeDirectory,
            databaseName: Self.databaseName,
            incompatibleModelStrategy: .removeStore,
            excludeFromiCloudBackup: true
        )

        databaseService = CoreDataService(
            configuration: CoreDataServiceConfiguration(
                modelURL: modelURL,
                storageType: .persistent(settings: settings)
            )
        )
    }

    public func createEventRepository() -> AnyDataProviderRepository<AnalyticsPendingEvent> {
        let repository = CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent>(
            databaseService: databaseService,
            mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper()),
            filter: nil,
            sortDescriptors: [NSSortDescriptor.analyticsEventsBySequence]
        )

        return AnyDataProviderRepository(repository)
    }
}
```

If `Bundle.module.url(forResource:withExtension: "momd")` returns nil at runtime, the model
was not declared as a resource — re-check `resources: [.process("Resources")]`.

- [ ] **Step 7: Run the store tests to verify they pass**

```bash
swift test --package-path Packages/NovaAnalytics --filter AnalyticsStorageFacadeTests
```

Expected: PASS, both tests. Complete Steps 4-6 first; the sources move in Step 8.

- [ ] **Step 8: Move the remaining sources**

```bash
git mv novawallet/Common/Services/Analytics/{Model,Network,Helpers} \
       Packages/NovaAnalytics/Sources/NovaAnalytics/
git mv novawallet/Common/Services/Analytics/Storage/AnalyticsPendingEvent.swift \
       novawallet/Common/Services/Analytics/Storage/CoreDataAnalyticsEventQueue.swift \
       Packages/NovaAnalytics/Sources/NovaAnalytics/Storage/
git mv novawallet/Common/Storage/EntityToModel/AnalyticsPendingEventMapper.swift \
       Packages/NovaAnalytics/Sources/NovaAnalytics/Storage/
git mv novawallet/Common/Services/Analytics/{AnalyticsProtocols,AnalyticsService,AnalyticsUploader,AnalyticsIdentity,AnalyticsConsentManager,AnalyticsAvailabilityProvider,AnalyticsSessionTracker}.swift \
       Packages/NovaAnalytics/Sources/NovaAnalytics/
```

Move the `analyticsEventsBySequence` member out of
`novawallet/Common/Extension/Storage/SortDescriptor+Storage.swift` into a new
`Packages/NovaAnalytics/Sources/NovaAnalytics/Storage/NSSortDescriptor+Analytics.swift`:

```swift
import Foundation
import CoreData

extension NSSortDescriptor {
    /// FIFO order for the pending-event queue.
    static var analyticsEventsBySequence: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAnalyticsEvent.sequence), ascending: true)
    }
}
```

Then in the moved sources:

1. Add `public` per the **Produces** block. `AnalyticsEvent`, its factory extensions, and
   every event-name/property enum must be public — the app emits events.
2. `import NovaAppAttest` in `AnalyticsProtocols.swift`, `AnalyticsUploader.swift` and
   `Network/AnalyticsUploadOperationFactory.swift` (they use `AttestationHeaderKey` and
   `BackendAttestationProviderProtocol`).
3. Swap `LoggerProtocol` → `SDKLoggerProtocol` (`import SDKLogger`) and delete every
   `= Logger.shared` default argument.
4. In `AnalyticsProtocols.swift`, change

   ```swift
   protocol AnalyticsServiceFacadeProtocol: AnalyticsTrackingProtocol, ApplicationServiceProtocol {
   ```

   to

   ```swift
   public protocol AnalyticsServiceFacadeProtocol: AnalyticsTrackingProtocol {
       var consent: AnalyticsConsentManagerProtocol { get }

       /// `ApplicationServiceProtocol` is app-defined and cannot cross the boundary, so the
       /// two members are declared here directly. `RootInteractor` calls `setup()` on the
       /// concrete facade type and is unaffected.
       func setup()
       func throttle()

       func flush(reason: AnalyticsFlushReason)
   }
   ```

- [ ] **Step 9: Write the analytics doubles**

Create `Packages/NovaAnalytics/Tests/NovaAnalyticsTests/Doubles/AnalyticsDoubles.swift`
with `AnalyticsEventQueueSpy`, `AnalyticsTrackingSpy`, `AnalyticsUploadingSpy`,
`AnalyticsUploadOperationFactorySpy` and `BackendAttestationProviderSpy`, following the same
shape as Task 3's doubles — a settable `…Result`/`…Stub` per method, a mutex-guarded
recorded-calls array, and a public accessor. For example:

```swift
import Foundation
import Operation_iOS
import NovaAppAttest
@testable import NovaAnalytics

final class AnalyticsEventQueueSpy: AnalyticsEventQueueProtocol {
    struct Enqueued: Equatable {
        let name: String
        let timestamp: Date
        let payload: Data
    }

    var peekResult: [AnalyticsPendingEvent] = []
    var countResult: Int = 0
    var enqueueError: Error?

    private let mutex = NSLock()
    private var recordedEnqueued: [Enqueued] = []
    private var recordedDroppedIds: [[String]] = []
    private(set) var clearCallCount = 0

    var enqueued: [Enqueued] {
        mutex.lock()
        defer { mutex.unlock() }
        return recordedEnqueued
    }

    var droppedIds: [[String]] {
        mutex.lock()
        defer { mutex.unlock() }
        return recordedDroppedIds
    }

    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void> {
        let error = enqueueError

        return CompoundOperationWrapper(targetOperation: ClosureOperation { [weak self] in
            if let error { throw error }

            self?.mutex.lock()
            self?.recordedEnqueued.append(Enqueued(name: name, timestamp: timestamp, payload: payload))
            self?.mutex.unlock()
        })
    }

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        let rows = Array(peekResult.prefix(count))

        return CompoundOperationWrapper(targetOperation: ClosureOperation { rows })
    }

    func dropOperation(ids: [String]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.mutex.lock()
            self?.recordedDroppedIds.append(ids)
            self?.mutex.unlock()
        }
    }

    func countOperation() -> BaseOperation<Int> {
        let value = countResult

        return ClosureOperation { value }
    }

    func clearOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.clearCallCount += 1
        }
    }
}
```

And the cross-package one, which `AnalyticsUploaderTests` needs:

```swift
/// Replaces `MockBackendAttestationProviderProtocol`. Lives in the analytics test target
/// because that is where it is consumed, even though the protocol belongs to NovaAppAttest.
final class BackendAttestationProviderSpy: BackendAttestationProviderProtocol {
    /// `nil` models mode `.none` — the request goes out unsigned.
    var headersResult: Result<[AttestationHeaderKey: String]?, Error> =
        .success([.clientId: "client-id", .challenge: "challenge", .signature: "signature"])

    private let mutex = NSLock()
    private var recordedBodies: [Data] = []
    private(set) var markUnattestedCallCount = 0
    private(set) var forgetClientCallCount = 0
    private(set) var allowClientCallCount = 0

    /// The bodies the uploader actually asked to sign. Asserting on these is how the tests
    /// prove the envelope was built before signing, not after.
    var signedBodies: [Data] {
        mutex.lock()
        defer { mutex.unlock() }
        return recordedBodies
    }

    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let result = headersResult

        return CompoundOperationWrapper(targetOperation: ClosureOperation { [weak self] in
            let body = try bodyClosure()

            self?.mutex.lock()
            self?.recordedBodies.append(body)
            self?.mutex.unlock()

            return try result.get()
        })
    }

    func markUnattested() {
        markUnattestedCallCount += 1
    }

    func forgetClient() {
        forgetClientCallCount += 1
    }

    func allowClient() {
        allowClientCallCount += 1
    }
}
```

- [ ] **Step 10: Move the tests**

```bash
git mv novawalletTests/Common/Services/Analytics/{AnalyticsBucketsTests,AnalyticsConsentGateTests,AnalyticsConsentManagerTests,AnalyticsEnvelopeTests,AnalyticsEventCatalogTests,AnalyticsEventQueueTests,AnalyticsIdentityTests,AnalyticsKillSwitchTests,AnalyticsPendingEventMapperTests,AnalyticsPropertyValueTests,AnalyticsServiceTests,AnalyticsSessionTrackerTests,AnalyticsTestFixture,AnalyticsUploadRequestTests,AnalyticsUploaderTests}.swift \
       Packages/NovaAnalytics/Tests/NovaAnalyticsTests/
```

Replace `@testable import novawallet` with `@testable import NovaAnalytics`, drop
`import Cuckoo`, and convert the Cuckoo call sites using the table in Task 3, Step 5.

`AnalyticsFacadeFactoryTests` is **split**: move only
`testNoOpFacadeDropsEverythingSilently` into a new
`Packages/NovaAnalytics/Tests/NovaAnalyticsTests/NoOpAnalyticsServiceFacadeTests.swift`
in Task 5, when `NoOpAnalyticsServiceFacade` itself moves. Leave the file alone here.

`AnalyticsKillSwitchTests` exercises the facade, which has not moved yet — leave it in
`novawalletTests` until Task 5.

- [ ] **Step 11: Delete the app-side entity and wire the package**

Remove the `<entity name="CDAnalyticsEvent" …>` element from
`MultiassetUserDataModel21.xcdatamodel/contents`. Wire `Packages/NovaAnalytics` into
`project.pbxproj` exactly as Task 3, Step 6 wired `NovaAppAttest`, and remove the moved
files' `PBXBuildFile`/`PBXFileReference`/`PBXGroup` entries. Add
`import NovaAnalytics` to `AnalyticsServiceFacade.swift`, `AnalyticsFacadeFactory.swift`,
`NoOpAnalyticsServiceFacade.swift`, the two `Debug/` files,
`Modules/AnalyticsConsent/*.swift`, `Modules/Root/RootInteractor.swift`,
`Modules/Root/RootPresenterFactory.swift` and the MainTabBar consent-prompt sources.

Remove the four analytics entries from `Cuckoofile.toml` (line 138,
`AnalyticsProtocols.swift`) — nothing app-side mocks them any more. Add
`Packages/NovaAnalytics/Tests` to `.swiftlint.yml` `excluded:`.

- [ ] **Step 12: Run both package suites and the app suite**

```bash
swift test --package-path Packages/NovaAppAttest
swift test --package-path Packages/NovaAnalytics
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" 2>&1 | xcbeautify --quiet
```

Expected: all PASS.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "$(cat <<'MSG'
move the analytics mechanism into a local spm package with its own store

The event catalogue, queue, uploader, identity, consent and session
tracker know nothing about the wallet domain. Lift them into
NovaAnalytics, which depends on NovaAppAttest for the signed headers.

The pending event queue gets its own CoreData model and sqlite rather
than riding UserDataModel, so the package owns its persistence and can
be published without dragging the app's user store behind it. The store
drops an incompatible model rather than crashing, and stays out of
iCloud backups, because it holds unsent telemetry rather than user data.
CDAnalyticsEvent is hand written: SwiftPM compiles the model but does
not run Xcode's code generator.

AnalyticsServiceFacadeProtocol declares setup and throttle directly
instead of inheriting the app's ApplicationServiceProtocol, which cannot
cross the boundary. The facade itself stays in the app for one more
step, until the injected configuration exists.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 5: Move the facade behind an injected configuration

Closes the boundary. After this task no app type is reachable from either package.

**Files:**
- Create: `Packages/NovaAnalytics/Sources/NovaAnalytics/Configuration/AnalyticsConfiguration.swift`
- Create: `Packages/NovaAnalytics/Sources/NovaAnalytics/Configuration/AnalyticsRemoteSettings.swift`
- Create: `novawallet/Common/Services/Analytics/AnalyticsRemoteSettingsAdapter.swift`
- Create: `Packages/NovaAnalytics/Tests/NovaAnalyticsTests/NoOpAnalyticsServiceFacadeTests.swift`
- Move: `AnalyticsServiceFacade.swift`, `NoOpAnalyticsServiceFacade.swift` into the package
- Move: `AnalyticsKillSwitchTests.swift` into the package
- Modify: `novawallet/Common/Services/Analytics/AnalyticsFacadeFactory.swift` (rewritten)
- Modify: `novawallet/Common/Services/Analytics/Debug/AnalyticsDebugInspectorViewController.swift`
- Modify: `novawalletTests/Common/Services/Analytics/AnalyticsFacadeFactoryTests.swift` (reduced)

**Interfaces:**
- Consumes: everything Tasks 3 and 4 produced.
- Produces: `AnalyticsConfiguration.init(gatewayURL:appVersion:storeDirectory:isReleaseBuild:isFirstLaunch:settingsManager:remoteSettings:logger:operationQueue:analyticsOperationQueue:)`, `AnalyticsRemoteSettings.createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool>`, `AnalyticsServiceFacade(configuration:)`, and `AnalyticsServiceFacadeProtocol.debugPendingEventsWrapper(count:)`.

- [ ] **Step 1: Write the failing configuration test**

Create `Packages/NovaAnalytics/Tests/NovaAnalyticsTests/AnalyticsConfigurationTests.swift`:

```swift
import XCTest
import Operation_iOS
import Keystore_iOS
@testable import NovaAnalytics

private final class RemoteSettingsStub: AnalyticsRemoteSettings {
    var result: Result<Bool, Error> = .success(true)

    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        let result = result

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
    }
}

final class AnalyticsConfigurationTests: XCTestCase {
    private func makeConfiguration(
        directory: URL,
        remoteSettings: AnalyticsRemoteSettings
    ) -> AnalyticsConfiguration {
        AnalyticsConfiguration(
            gatewayURL: URL(string: "https://gateway.example/")!,
            appVersion: "10.9.0",
            storeDirectory: directory,
            isReleaseBuild: false,
            isFirstLaunch: { false },
            settingsManager: InMemorySettingsManager(),
            remoteSettings: remoteSettings,
            logger: SilentLogger(),
            operationQueue: OperationQueue(),
            analyticsOperationQueue: OperationQueue()
        )
    }

    /// The facade must be constructible from configuration alone — no singletons, no
    /// Bundle lookups, nothing reaching back into a host app.
    func testFacadeBuildsFromConfigurationAlone() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let facade = AnalyticsServiceFacade(
            configuration: makeConfiguration(directory: directory, remoteSettings: RemoteSettingsStub())
        )

        XCTAssertFalse(facade.consent.isEnabled)
    }

    /// `appVersion` must come from configuration. Reading it from
    /// `Bundle(for: AnalyticsServiceFacade.self)` inside a package resolves to the *package*
    /// bundle and yields "".
    func testAppVersionComesFromConfigurationNotTheBundle() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = makeConfiguration(directory: directory, remoteSettings: RemoteSettingsStub())

        XCTAssertEqual(configuration.appVersion, "10.9.0")
        XCTAssertNotEqual(configuration.appVersion, "")
    }
}
```

Add a `SilentLogger` to `Doubles/AnalyticsDoubles.swift`:

```swift
import SDKLogger

final class SilentLogger: SDKLoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
swift test --package-path Packages/NovaAnalytics --filter AnalyticsConfigurationTests
```

Expected: FAIL — `cannot find 'AnalyticsConfiguration' in scope`.

- [ ] **Step 3: Add the configuration and the remote-settings protocol**

Create `Packages/NovaAnalytics/Sources/NovaAnalytics/Configuration/AnalyticsRemoteSettings.swift`:

```swift
import Foundation
import Operation_iOS

/// The remote kill switch, as the package sees it. The host app owns the config format;
/// the package only needs the resolved flag.
///
/// Fail-open is the host's job on the *value* side (a missing analytics block means
/// enabled) and the facade's job on the *error* side: a failed wrapper leaves availability
/// exactly as the attestation ladder set it.
public protocol AnalyticsRemoteSettings {
    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool>
}
```

Create `Packages/NovaAnalytics/Sources/NovaAnalytics/Configuration/AnalyticsConfiguration.swift`:

```swift
import Foundation
import Operation_iOS
import Keystore_iOS
import SDKLogger

/// Everything the analytics stack needs from its host. No singletons, no `Bundle.main`
/// lookups, no app types — this struct is the whole boundary.
public struct AnalyticsConfiguration {
    public let gatewayURL: URL

    /// `CFBundleShortVersionString` only; the gateway does not expect a build number.
    /// Supplied by the host because `Bundle(for:)` inside a package resolves to the
    /// package bundle, not the app.
    public let appVersion: String

    /// Directory for `AnalyticsDataModel.sqlite`. The app passes its app-group CoreData
    /// directory so the file sits beside the user store.
    public let storeDirectory: URL

    /// Drives the attestation mode ladder.
    public let isReleaseBuild: Bool

    /// Read at `setup()` for the `app_opened` event. A closure rather than a `Bool` because
    /// the host flips it during launch.
    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let remoteSettings: AnalyticsRemoteSettings
    public let logger: SDKLoggerProtocol

    /// Shared, concurrent. The attestation chain nests wrappers, which a serial queue
    /// cannot run.
    public let operationQueue: OperationQueue

    /// Serial. Persistence runs here while a slow POST is in flight on `operationQueue`.
    public let analyticsOperationQueue: OperationQueue

    public init(
        gatewayURL: URL,
        appVersion: String,
        storeDirectory: URL,
        isReleaseBuild: Bool,
        isFirstLaunch: @escaping () -> Bool,
        settingsManager: SettingsManagerProtocol,
        remoteSettings: AnalyticsRemoteSettings,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.gatewayURL = gatewayURL
        self.appVersion = appVersion
        self.storeDirectory = storeDirectory
        self.isReleaseBuild = isReleaseBuild
        self.isFirstLaunch = isFirstLaunch
        self.settingsManager = settingsManager
        self.remoteSettings = remoteSettings
        self.logger = logger
        self.operationQueue = operationQueue
        self.analyticsOperationQueue = analyticsOperationQueue
    }
}
```

- [ ] **Step 4: Move the facade and rewrite its initialiser**

```bash
git mv novawallet/Common/Services/Analytics/AnalyticsServiceFacade.swift \
       novawallet/Common/Services/Analytics/NoOpAnalyticsServiceFacade.swift \
       Packages/NovaAnalytics/Sources/NovaAnalytics/
git mv novawalletTests/Common/Services/Analytics/AnalyticsKillSwitchTests.swift \
       Packages/NovaAnalytics/Tests/NovaAnalyticsTests/
```

In `AnalyticsServiceFacade.swift`:

1. Delete `static let shared` and change `private init()` to
   `public init(configuration: AnalyticsConfiguration)`.
2. Replace each app reference with its configuration field:

   | Was | Becomes |
   |---|---|
   | `SettingsManager.shared` | `configuration.settingsManager` |
   | `UserDataStorageFacade.shared.createRepository(...)` | `AnalyticsStorageFacade(storeDirectory: configuration.storeDirectory).createEventRepository()` |
   | `#if F_RELEASE … isReleaseBuild` | `configuration.isReleaseBuild` |
   | `ApplicationConfig.shared.gatewayURL` | `configuration.gatewayURL` |
   | `SettingsAppAttestKeyRepository(settingsManager: settingsManager)` | unchanged (already settings-backed) |
   | `OperationManagerFacade.sharedDefaultQueue` | `configuration.operationQueue` |
   | `OperationManagerFacade.analyticsQueue` | `configuration.analyticsOperationQueue` |
   | `Self.appVersion` | `configuration.appVersion` |
   | `GlobalConfigProvider.shared` | `configuration.remoteSettings` |
   | `Logger.shared` | `configuration.logger` |
   | `settingsManager.isAppFirstLaunch` | `configuration.isFirstLaunch()` |

3. Delete the `static var appVersion` helper entirely — it is the `Bundle(for:)` trap.
4. Rewrite `resolveRemoteAvailability()` to consume the resolved flag:

```swift
    func resolveRemoteAvailability() {
        execute(
            wrapper: remoteSettings.createRemoteEnabledWrapper(),
            inOperationQueue: configOperationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(isEnabled):
                availability.setRemoteEnabled(isEnabled)
                service.handleAvailabilityChanged()

                guard !availability.isAvailable else {
                    return
                }

                // The kill switch stops collection at the source: without this the session
                // tracker keeps observing foreground/background edges and keeps handing
                // events to a service that silently discards every one of them.
                throttle()
            case let .failure(error):
                logger.info("Analytics remote config unavailable: \(error)")
            }
        }
    }
```

5. Add the debug accessor to `AnalyticsServiceFacadeProtocol` and both implementations:

```swift
    /// Read-only view of the pending queue for a host's debug tooling. Routed through the
    /// facade rather than exposing the store, so a caller observes the same queue instance
    /// as everything else — one lock, one call store, one session.
    func debugPendingEventsWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>
```

`AnalyticsServiceFacade` forwards to `eventQueue.peekWrapper(count:)`;
`NoOpAnalyticsServiceFacade` returns `CompoundOperationWrapper.createWithResult([])`.

- [ ] **Step 5: Add the app-side adapter**

Create `novawallet/Common/Services/Analytics/AnalyticsRemoteSettingsAdapter.swift`:

```swift
import Foundation
import Operation_iOS
import NovaAnalytics

/// Bridges the app's `GlobalConfigProvider` to the package's `AnalyticsRemoteSettings`.
/// `GlobalConfig` and `AnalyticsRemoteConfig` are app models and must not cross the
/// boundary, so only the resolved flag is handed over.
final class AnalyticsRemoteSettingsAdapter {
    private let configProvider: GlobalConfigProviding

    init(configProvider: GlobalConfigProviding = GlobalConfigProvider.shared) {
        self.configProvider = configProvider
    }
}

extension AnalyticsRemoteSettingsAdapter: AnalyticsRemoteSettings {
    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        let configWrapper = configProvider.createConfigWrapper()

        // Fail-open on the value: a config with no analytics block means enabled. Fail-open
        // on the error is the facade's job — it leaves availability alone.
        let mapOperation = ClosureOperation<Bool> {
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            return config.analytics?.enabled ?? true
        }

        mapOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: mapOperation)
    }
}
```

- [ ] **Step 6: Rewrite the app factory**

Replace `novawallet/Common/Services/Analytics/AnalyticsFacadeFactory.swift`:

```swift
import Foundation
import Keystore_iOS
import NovaAnalytics

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches the singleton, so
    /// every call site shares one lock, one call store, one session and one queue.
    ///
    /// The `-UNITTEST` check mirrors `AppDelegate.isUnitTesting`. Without it, enabling
    /// `F_ANALYTICS` for Debug makes every `xcodebuild test` run build the real facade,
    /// which opens the developer's actual store, records a session and POSTs to the live
    /// gateway.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        #if F_ANALYTICS
            guard !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
                return NoOpAnalyticsServiceFacade.shared
            }

            return sharedFacade
        #else
            return NoOpAnalyticsServiceFacade.shared
        #endif
    }

    #if F_ANALYTICS
        private static let sharedFacade: AnalyticsServiceFacadeProtocol = {
            #if F_RELEASE
                let isReleaseBuild = true
            #else
                let isReleaseBuild = false
            #endif

            let settingsManager = SettingsManager.shared

            return AnalyticsServiceFacade(
                configuration: AnalyticsConfiguration(
                    gatewayURL: ApplicationConfig.shared.gatewayURL,
                    // `ApplicationConfig.version` appends the build number, which the
                    // gateway does not expect.
                    appVersion: Bundle.main
                        .infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                    storeDirectory: UserStorageParams.sharedStorageDirectoryURL,
                    isReleaseBuild: isReleaseBuild,
                    isFirstLaunch: { settingsManager.isAppFirstLaunch },
                    settingsManager: settingsManager,
                    remoteSettings: AnalyticsRemoteSettingsAdapter(),
                    logger: Logger.shared,
                    operationQueue: OperationManagerFacade.sharedDefaultQueue,
                    analyticsOperationQueue: OperationManagerFacade.analyticsQueue
                )
            )
        }()
    #endif
}
```

- [ ] **Step 7: Retarget the debug inspector**

In `novawallet/Common/Services/Analytics/Debug/AnalyticsDebugInspectorViewController.swift`,
delete the `UserDataStorageFacade.shared.createRepository(...)` block and the second
`CoreDataAnalyticsEventQueue`. Take the facade only, and read the queue through
`facade.debugPendingEventsWrapper(count:)`. Replace the `eventQueue:` initialiser parameter
with nothing — the view controller already holds `facade`.

- [ ] **Step 8: Split the factory test**

Move `testNoOpFacadeDropsEverythingSilently` out of
`novawalletTests/Common/Services/Analytics/AnalyticsFacadeFactoryTests.swift` into
`Packages/NovaAnalytics/Tests/NovaAnalyticsTests/NoOpAnalyticsServiceFacadeTests.swift`
(changing `@testable import novawallet` to `@testable import NovaAnalytics`). The remaining
two tests — `testCreateDefaultReturnsTheSameInstance` and
`testUnitTestProcessNeverBuildsTheRealFacade` — stay in the app: they test build-flag gating
and the singleton, both of which are app concerns.

- [ ] **Step 9: Run everything**

```bash
swift test --package-path Packages/NovaAppAttest
swift test --package-path Packages/NovaAnalytics
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" 2>&1 | xcbeautify --quiet
```

Expected: all PASS.

- [ ] **Step 10: Verify the boundary actually closed**

```bash
grep -rnE "ApplicationConfig|UserDataStorageFacade|OperationManagerFacade|GlobalConfig|Logger\.shared|R\.string|SettingsKey|ApplicationServiceProtocol" Packages/
```

Expected: **no output.** Any hit is an app type that leaked into a package; fix it before
committing.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "$(cat <<'MSG'
inject the analytics facade's host dependencies as configuration

The facade was the last thing holding app singletons: ApplicationConfig
for the gateway, GlobalConfigProvider for the kill switch, the shared
operation queues, SettingsManager and Logger. Replace all of them with
one AnalyticsConfiguration the host fills in, plus an
AnalyticsRemoteSettings protocol the app satisfies by mapping its
GlobalConfig down to the resolved flag.

Reading the app version through Bundle(for: AnalyticsServiceFacade.self)
had to go: inside a package that resolves to the package bundle and
yields an empty string, so the version comes from configuration.

The debug inspector no longer opens the store itself. It reads through a
narrow facade accessor, which also fixes it observing a second event
queue instance rather than the one the rest of the app shares.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 6: Delete `MultiassetUserDataModel21` and update the docs

With both entities gone, v21's only remaining difference from v20 is dropping the already
dead `CDAppAttestBrowserSettings` — not worth a migration on every install. The branch stops
touching `UserDataModel` at all, taking its migration surface from one shipped user-store
migration to zero.

**Files:**
- Delete: `novawallet/Common/Storage/UserDataModel.xcdatamodeld/MultiassetUserDataModel21.xcdatamodel/`
- Delete: `novawalletTests/Common/Migration/AnalyticsUserModel21MigrationTests.swift`
- Modify: `novawallet/Common/Storage/UserDataStorageFacade.swift` (`modelVersion`)
- Modify: `novawallet/Common/Migration/UserStorageVersion.swift`
- Modify: `novawallet/Common/Storage/UserDataModel.xcdatamodeld/.xccurrentversion`
- Modify: `.claude/docs/code/project-layout.md`, `.claude/docs/code/build-and-tooling.md`

**Interfaces:**
- Consumes: Tasks 2 and 4 removed `CDAppAttestKey` and `CDAnalyticsEvent` from the model.
- Produces: nothing further depends on this.

- [ ] **Step 1: Confirm v21 is now identical to v20 apart from the dead entity**

```bash
diff <(grep -oE '<entity name="[A-Za-z]+"' novawallet/Common/Storage/UserDataModel.xcdatamodeld/MultiassetUserDataModel20.xcdatamodel/contents | sort) \
     <(grep -oE '<entity name="[A-Za-z]+"' novawallet/Common/Storage/UserDataModel.xcdatamodeld/MultiassetUserDataModel21.xcdatamodel/contents | sort)
```

Expected: exactly one line of difference — `< <entity name="CDAppAttestBrowserSettings"`.
Anything else means an entity change rode along and this task must stop.

- [ ] **Step 2: Delete the model version and the migration test**

```bash
git rm -r novawallet/Common/Storage/UserDataModel.xcdatamodeld/MultiassetUserDataModel21.xcdatamodel
git rm novawalletTests/Common/Migration/AnalyticsUserModel21MigrationTests.swift
```

Set `.xccurrentversion` back to `MultiassetUserDataModel20.xcdatamodel`, and remove the v21
`PBXFileReference` and `XCVersionGroup` child entry from `project.pbxproj`.

- [ ] **Step 3: Revert the storage version**

In `novawallet/Common/Migration/UserStorageVersion.swift`, delete
`case version22 = "MultiassetUserDataModel21"`, and change the `nextVersion` transition
`case .version21: .version22` to `case .version21: nil`, deleting `case .version22: nil`.

In `novawallet/Common/Storage/UserDataStorageFacade.swift`, change
`static let modelVersion: UserStorageVersion = .version22` back to `.version21`.

- [ ] **Step 4: Update the architecture docs**

In `.claude/docs/code/project-layout.md`, replace the opening sentence
"One Xcode project, no local SPM packages." with:

```markdown
One Xcode project plus two local SPM packages under `Packages/`. The structural boundaries
are `Common/` (shared) vs. `Modules/` (features) inside the app target, and the package
boundary outside it.

| The code knows about…                                    | It belongs in    |
|-----------------------------------------------------------|------------------|
| Analytics events, the queue, consent, the uploader        | `Packages/NovaAnalytics` |
| App Attest, DeviceCheck, gateway register/sign            | `Packages/NovaAppAttest` |

Nothing in a package may reference an app type — no `ApplicationConfig`, `GlobalConfig`,
`Logger`, `UserDataStorageFacade`, `OperationManagerFacade`, `R.string` or
`ApplicationServiceProtocol`. Host dependencies arrive through `AnalyticsConfiguration`.
Package test targets take no external test dependencies: XCTest and hand-written doubles,
never Cuckoo.
```

In `.claude/docs/code/build-and-tooling.md`, replace "All SPM, all remote — there are no
local packages." with a note that `Packages/NovaAppAttest` and `Packages/NovaAnalytics` are
local, that `logger-ios` was added, and add the package test commands:

```bash
swift test --package-path Packages/NovaAppAttest
swift test --package-path Packages/NovaAnalytics
```

- [ ] **Step 5: Run the full suite and a Release build**

```bash
swift test --package-path Packages/NovaAppAttest
swift test --package-path Packages/NovaAnalytics
set -o pipefail && RUN_IN_CI=true xcodebuild test -project novawallet.xcodeproj \
  -scheme novawallet -destination "id=$SIM_ID" 2>&1 | xcbeautify --quiet
set -o pipefail && RUN_IN_CI=true xcodebuild -project novawallet.xcodeproj \
  -scheme novawallet -configuration Release -destination "id=$SIM_ID" \
  build 2>&1 | xcbeautify --quiet
```

The Release build confirms `#if F_ANALYTICS` and `#if F_DEV` still exclude the debug
inspector and the fixture recorder.

- [ ] **Step 6: Verify a clean install still migrates**

Delete the app from the simulator, install a build from `develop` (model v20), then install
this branch's build over it and confirm it launches with wallets intact. v21 never shipped,
so this is the only migration path that matters — and after this task there is no analytics
migration at all.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "$(cat <<'MSG'
drop user data model 21 now that nothing analytics lives there

The analytics queue moved to the package's own store and the app attest
key row moved to settings, so v21's only remaining difference from v20 is
removing the already dead CDAppAttestBrowserSettings entity. That is not
worth a migration on every install: the entity is unused, it is already
present everywhere, and leaving it costs nothing.

Deleting the version takes this branch's CoreData migration surface from
one shipped user store migration to zero, which is a strictly safer place
to be than where the branch started.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG
)"
```

---

## Done criteria

1. `swift test --package-path Packages/NovaAppAttest` and `…/NovaAnalytics` both pass.
2. The full app unit suite passes (`GiftsSyncServiceTests` excepted — pre-existing flaky).
3. The Task 5 Step 10 grep over `Packages/` returns nothing.
4. Neither `Package.swift` mentions Cuckoo; neither package has a `Cuckoofile.toml`.
5. `UserStorageParams.modelVersion == .version21` and `MultiassetUserDataModel21` is gone.
6. A Release build excludes the debug inspector and the fixture recorder.
7. `.claude/docs/code/project-layout.md` no longer claims there are no local packages.
