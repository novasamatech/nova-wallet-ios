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
