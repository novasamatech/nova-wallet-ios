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

        let expectation = XCTestExpectation()

        repository.isConsentRequired(runningIn: .main) { required in
            XCTAssertFalse(required)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
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

        let expectation = XCTestExpectation()

        repository.isConsentRequired(runningIn: .main) { required in
            XCTAssertFalse(required)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

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

        let expectation = XCTestExpectation()

        repository.isConsentRequired(runningIn: .main) { required in
            XCTAssertFalse(required)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
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

        let expectation = XCTestExpectation()

        repository.isConsentRequired(runningIn: .main) { required in
            XCTAssertTrue(required)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    /// A burst of callers must coalesce into exactly one network request.
    func testConcurrentRequestsShareSingleFetch() {
        let settings = InMemorySettingsManager()
        let factory = createSuccessFactory()

        let repository = createRepository(fetchFactory: factory, settings: settings)

        let expectations = (0 ..< 5).map { _ in XCTestExpectation() }

        expectations.forEach { expectation in
            repository.isConsentRequired(runningIn: .main) { required in
                XCTAssertTrue(required)
                expectation.fulfill()
            }
        }

        wait(for: expectations, timeout: 5)

        verify(factory, times(1)).fetchOperation()
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
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }
}
