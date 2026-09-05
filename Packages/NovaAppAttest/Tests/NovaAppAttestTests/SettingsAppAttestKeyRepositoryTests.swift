import XCTest
import Operation_iOS
import Keystore_iOS
@testable import NovaAppAttest

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
    /// not just the current one: a cycle whose delete failed has left one behind. Also pins
    /// the map-shaped store's one distinguishing property: the wipe removes the settings key
    /// outright rather than leaving an empty `{}` behind.
    func testDeleteAllClearsEveryClientsRow() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(repository.saveOperation({ [self.makeRow("a"), self.makeRow("b")] }, { [] }))
        _ = try run(repository.deleteAllOperation())

        XCTAssertEqual(try run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [])
        XCTAssertNil(settings.data(for: SettingsAppAttestKeyRepository.storageKey))
    }

    func testSaveDeleteIdsBlockRemovesNamedRowsOnly() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        _ = try run(repository.saveOperation({ [self.makeRow("a"), self.makeRow("b")] }, { [] }))
        _ = try run(repository.saveOperation({ [] }, { ["a"] }))

        let remaining = try run(repository.fetchAllOperation(with: RepositoryFetchOptions()))

        XCTAssertEqual(remaining.map(\.identifier), ["b"])
    }

    func testReplaceDropsRowsAbsentFromTheNewSet() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())

        _ = try run(repository.saveOperation({ [self.makeRow("a"), self.makeRow("b")] }, { [] }))
        _ = try run(repository.replaceOperation { [self.makeRow("b")] })

        let remaining = try run(repository.fetchAllOperation(with: RepositoryFetchOptions()))

        XCTAssertEqual(remaining.map(\.identifier), ["b"])
    }

    /// The same opt-out guarantee as `testDeleteAllClearsEveryClientsRow`, reached through
    /// `replaceOperation` instead: an empty replacement removes the settings key outright
    /// rather than leaving `{}` behind.
    func testReplaceWithEmptySetRemovesTheSettingsKey() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(repository.saveOperation({ [self.makeRow("a")] }, { [] }))
        _ = try run(repository.replaceOperation { [] })

        XCTAssertEqual(try run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [])
        XCTAssertNil(settings.data(for: SettingsAppAttestKeyRepository.storageKey))
    }

    /// The only assertion that names the on-disk key. Every other test reaches the store
    /// through `SettingsAppAttestKeyRepository.storageKey`, so a typo in that literal would
    /// pass the whole suite while silently orphaning whatever rows already exist under the
    /// old name.
    ///
    /// No *shipped* install holds `appAttestKeys`: the key arrives with this branch, and the
    /// rows it replaces lived in `CDAppAttestKey` with nothing migrating them. What is at
    /// risk today is dev and TestFlight installs of this branch — and, from here on, every
    /// install, which is why the literal is pinned rather than left to be retyped.
    func testRowsAreStoredUnderThePinnedSettingsKey() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(repository.saveOperation({ [self.makeRow("a")] }, { [] }))

        XCTAssertNotNil(settings.data(for: "appAttestKeys"))
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
    /// atomicity only, so an unguarded read-modify-write of the map loses writes. The store
    /// is wrapped in `SerialisedSettingsManager` so that hazard is isolated to the
    /// repository's own lock: plain `InMemorySettingsManager` holds an unguarded
    /// `[String: Any]` and would otherwise crash under concurrent access before the map's
    /// race ever got a chance to lose a write, which would fail this test for the wrong
    /// reason.
    func testConcurrentSavesDoNotLoseRows() throws {
        let repository = SettingsAppAttestKeyRepository(
            settingsManager: SerialisedSettingsManager(wrapping: InMemorySettingsManager())
        )
        let concurrent = OperationQueue()
        concurrent.maxConcurrentOperationCount = 8

        let operations = (0 ..< 64).map { index in
            repository.saveOperation({ [self.makeRow("row-\(index)")] }, { [] })
        }

        concurrent.addOperations(operations, waitUntilFinished: true)

        XCTAssertEqual(try run(repository.fetchCountOperation()), 64)
    }
}
