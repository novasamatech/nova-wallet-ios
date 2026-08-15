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

    /// A malformed date invalidates the whole config, including the valid version numbers.
    /// `"2026/08/04"` and `"2026-8-4"` are the cases a bare `DateFormatter` wrongly accepts.
    func testMalformedDatesFailDecoding() {
        let badValues = [
            "4 March 2026",
            "2026-13-45",
            "2026/08/04",
            "2026-8-4",
            "20260804",
            "2026-08-04T00:00:00Z",
            ""
        ]

        for badValue in badValues {
            let json = """
            {
              "termsOfService": { "version": 2, "updatedAt": "\(badValue)" },
              "privacyNotice":  { "version": 1, "updatedAt": "2026-03-04" }
            }
            """

            XCTAssertThrowsError(
                try JSONDecoder().decode(LegalDocumentsRemote.self, from: Data(json.utf8)),
                "Expected \(badValue) to be rejected"
            )
        }
    }

    func testNumericDateFailsDecoding() {
        let json = #"{"version": 1, "updatedAt": 2026}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(LegalDocumentRemote.self, from: Data(json.utf8))
        )
    }

    func testMissingDocumentFailsDecoding() {
        let json = #"{"termsOfService": {"version": 1, "updatedAt": "2026-03-04"}}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(LegalDocumentsRemote.self, from: Data(json.utf8))
        )
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

    /// Once the config has loaded, later callers are answered from the cache without another fetch.
    func testResolvedConfigIsCachedAcrossCalls() {
        let settings = InMemorySettingsManager()
        let factory = createSuccessFactory()

        let repository = createRepository(fetchFactory: factory, settings: settings)

        XCTAssertTrue(resolveConsentRequired(repository))
        XCTAssertTrue(resolveConsentRequired(repository))
        XCTAssertTrue(resolveConsentRequired(repository))

        verify(factory, times(1)).fetchOperation()
    }

    /// A failure is never cached, so the next caller retries rather than being stuck on `false`.
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

    // MARK: - Localized template contract

    /// `LegalConsentTextFactory` silently drops a link whose marker is missing from the template.
    func testEnglishAgreementTemplateCarriesBothMarkers() {
        let template = R.string(preferredLanguages: ["en"]).localizable
            .legalConsentAgreement("{TOS}", "{PN}")

        XCTAssertTrue(template.contains("{TOS}"))
        XCTAssertTrue(template.contains("{PN}"))
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
