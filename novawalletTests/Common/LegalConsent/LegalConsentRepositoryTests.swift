import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import Operation_iOS

final class LegalConsentRepositoryTests: XCTestCase {
    private let validJson = """
    {
      "termsOfService": { "version": 2, "updatedAt": "2026-08-04" },
      "privacyNotice":  { "version": 1, "updatedAt": "2026-03-04" }
    }
    """

    // MARK: - Decoding

    func testDeserialisesBothDocuments() throws {
        let remote = try JSONDecoder().decode(
            LegalDocumentsRemote.self,
            from: Data(validJson.utf8)
        )

        XCTAssertEqual(remote.termsOfService.version, 2)
        XCTAssertEqual(remote.privacyNotice.version, 1)
    }

    func testMapperPreservesVersionAndDatePerType() throws {
        let remote = try JSONDecoder().decode(
            LegalDocumentsRemote.self,
            from: Data(validJson.utf8)
        )

        let documents = remote.mapToDocuments()

        XCTAssertEqual(documents.map(\.type), [.termsOfService, .privacyNotice])
        XCTAssertEqual(documents[0].version, 2)
        XCTAssertEqual(documents[1].version, 1)
        XCTAssertEqual(documents[0].updatedAt, remote.termsOfService.updatedAt.date)
    }

    // MARK: - Repository contract

    func testUnavailableConfigNeverPrompts() {
        let settings = InMemorySettingsManager()
        let factory = MockLegalDocumentsFetchOperationFactoryProtocol()

        stub(factory) { stub in
            stub.fetchOperation().then {
                BaseOperation.createWithError(NetworkBaseError.unexpectedEmptyData)
            }
        }

        let repository = createRepository(fetchFactory: factory, settings: settings)

        XCTAssertFalse(resolveConsentRequired(repository))
    }

    func testPendingAcceptanceIsRedeemedByFirstSuccessfulSync() {
        let settings = InMemorySettingsManager()
        let repository = createRepository(
            fetchFactory: createSuccessFactory(),
            settings: settings
        )

        repository.acceptCurrentVersions(deferringWhenUnavailable: true)

        XCTAssertTrue(settings.legalConsentPendingSync)
        XCTAssertTrue(settings.legalConsentAcceptedVersions.isEmpty)

        XCTAssertFalse(resolveConsentRequired(repository))

        XCTAssertFalse(settings.legalConsentPendingSync)
        XCTAssertEqual(
            settings.legalConsentAcceptedVersions,
            [
                LegalDocumentType.termsOfService.rawValue: 2,
                LegalDocumentType.privacyNotice.rawValue: 1
            ]
        )
    }

    func testNonDeferringAcceptanceRecordsNothingWhenConfigUnavailable() {
        let settings = InMemorySettingsManager()
        let repository = createRepository(
            fetchFactory: createSuccessFactory(),
            settings: settings
        )

        repository.acceptCurrentVersions(deferringWhenUnavailable: false)

        XCTAssertFalse(settings.legalConsentPendingSync)
        XCTAssertTrue(settings.legalConsentAcceptedVersions.isEmpty)
    }

    func testDowngradeAndEqualVersionsDoNotPrompt() {
        let settings = InMemorySettingsManager()
        settings.legalConsentAcceptedVersions = [
            LegalDocumentType.termsOfService.rawValue: 5,
            LegalDocumentType.privacyNotice.rawValue: 1
        ]

        let repository = createRepository(
            fetchFactory: createSuccessFactory(),
            settings: settings
        )

        XCTAssertFalse(resolveConsentRequired(repository))
    }

    func testSingleDocumentBumpPrompts() {
        let settings = InMemorySettingsManager()
        settings.legalConsentAcceptedVersions = [
            LegalDocumentType.termsOfService.rawValue: 1,
            LegalDocumentType.privacyNotice.rawValue: 1
        ]

        let repository = createRepository(
            fetchFactory: createSuccessFactory(),
            settings: settings
        )

        XCTAssertTrue(resolveConsentRequired(repository))
    }

    func testResolvedConfigIsCachedAcrossCalls() {
        let settings = InMemorySettingsManager()
        let factory = createSuccessFactory()

        let repository = createRepository(fetchFactory: factory, settings: settings)

        XCTAssertTrue(resolveConsentRequired(repository))
        XCTAssertTrue(resolveConsentRequired(repository))
        XCTAssertTrue(resolveConsentRequired(repository))

        verify(factory, times(1)).fetchOperation()
    }

    func testFailedFetchIsNotCached() {
        let settings = InMemorySettingsManager()
        let factory = MockLegalDocumentsFetchOperationFactoryProtocol()

        var shouldFail = true

        stub(factory) { stub in
            stub.fetchOperation().then { [validJson] in
                guard !shouldFail else {
                    return BaseOperation.createWithError(NetworkBaseError.unexpectedEmptyData)
                }

                return ClosureOperation {
                    try JSONDecoder().decode(LegalDocumentsRemote.self, from: Data(validJson.utf8))
                }
            }
        }

        let repository = createRepository(fetchFactory: factory, settings: settings)

        XCTAssertFalse(resolveConsentRequired(repository))

        shouldFail = false

        XCTAssertTrue(resolveConsentRequired(repository))

        verify(factory, times(2)).fetchOperation()
    }

    // MARK: - Private

    private func createSuccessFactory() -> MockLegalDocumentsFetchOperationFactoryProtocol {
        let factory = MockLegalDocumentsFetchOperationFactoryProtocol()

        stub(factory) { stub in
            stub.fetchOperation().then { [validJson] in
                ClosureOperation {
                    try JSONDecoder().decode(LegalDocumentsRemote.self, from: Data(validJson.utf8))
                }
            }
        }

        return factory
    }

    private func createRepository(
        fetchFactory: LegalDocumentsFetchOperationFactoryProtocol,
        settings: SettingsManagerProtocol
    ) -> LegalConsentRepositoryProtocol {
        LegalConsentRepository(
            fetchFactory: fetchFactory,
            settingsManager: settings,
            logger: Logger.shared
        )
    }

    private func resolveConsentRequired(_ repository: LegalConsentRepositoryProtocol) -> Bool {
        let wrapper = repository.consentRequiredWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return (try? wrapper.targetOperation.extractNoCancellableResultData()) ?? false
    }
}
