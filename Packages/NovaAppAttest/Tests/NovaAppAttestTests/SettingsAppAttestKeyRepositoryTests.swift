import XCTest
import Operation_iOS
import Keystore_iOS
@testable import NovaAppAttest

final class SettingsAppAttestKeyRepositoryTests: XCTestCase {
    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }

    func testSavedRowIsFetchedBackById() throws {
        let repository = SettingsAppAttestKeyRepository(settingsManager: InMemorySettingsManager())
        let row = AppAttestKeySettings(identifier: "gateway|client-a", keyId: "key-a", isAttested: true)

        _ = try run(repository.saveOperation({ [row] }, { [] }))

        let fetched = try run(repository.fetchOperation(by: { "gateway|client-a" }, options: RepositoryFetchOptions()))

        XCTAssertEqual(fetched, row)
    }

    func testLegacyRowWithoutTheBackoffFieldsStillDecodes() throws {
        let settings = InMemorySettingsManager()
        let legacy = Data(#"{"a":{"identifier":"a","keyId":"key-a","isAttested":true}}"#.utf8)
        settings.set(value: legacy, for: SettingsAppAttestKeyRepository.storageKey)

        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)
        let fetched = try run(repository.fetchOperation(by: { "a" }, options: RepositoryFetchOptions()))

        XCTAssertEqual(fetched?.keyId, "key-a")
        XCTAssertEqual(fetched?.isAttested, true)
        XCTAssertEqual(fetched?.attemptCount, 0)
        XCTAssertNil(fetched?.nextAttemptAt)
    }
}
