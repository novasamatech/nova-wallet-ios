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

    func testReplaceWithEmptySetRemovesTheSettingsKey() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(repository.saveOperation({ [self.makeRow("a")] }, { [] }))
        _ = try run(repository.replaceOperation { [] })

        XCTAssertEqual(try run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [])
        XCTAssertNil(settings.data(for: SettingsAppAttestKeyRepository.storageKey))
    }

    func testRowsAreStoredUnderThePinnedSettingsKey() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        _ = try run(repository.saveOperation({ [self.makeRow("a")] }, { [] }))

        XCTAssertNotNil(settings.data(for: "appAttestKeys"))
    }

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
