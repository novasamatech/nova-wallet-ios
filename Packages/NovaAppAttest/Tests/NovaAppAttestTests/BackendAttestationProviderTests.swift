import XCTest
@testable import NovaAppAttest
import Operation_iOS
import Keystore_iOS

final class BackendAttestationProviderTests: XCTestCase {
    private let clock = TestClock()

    private var provider: BackendAttestationProvider!
    private var appAttest: AppAttestServiceSpy!
    private var remote: BackendAttestationRemoteFactorySpy!
    private var settings: InMemorySettingsManager!
    private var repository: AnyDataProviderRepository<AppAttestKeySettings>!
    private var operationQueue: OperationQueue!

    private func makeProvider() {
        settings = InMemorySettingsManager()
        repository = AnyDataProviderRepository(SettingsAppAttestKeyRepository(settingsManager: settings))
        operationQueue = OperationQueue()
        appAttest = AppAttestServiceSpy()
        remote = BackendAttestationRemoteFactorySpy()

        provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: remote,
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: repository,
            gatewayURL: URL(string: "https://gateway.example/")!,
            mode: .appAttest,
            appIdentity: AppAttestAppIdentity(
                appId: "ABCDEFGHIJ.io.novafoundation.novawallet.dev",
                environment: "production"
            ),
            operationQueue: operationQueue,
            logger: SilentLogger(),
            timeProvider: { [clock] in clock.now }
        )
    }

    private func headers(origin: String = "https://gateway.example") throws -> [AttestationHeaderKey: String]? {
        let target = try AttestationRequestTarget(
            url: URL(string: "\(origin)/v1/analytics/events")!,
            method: "post",
            contentType: "application/json"
        )

        let wrapper = provider.createSignedHeadersWrapper(target: target) { Data("body".utf8) }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func storedRow() throws -> AppAttestKeySettings? {
        operationQueue.waitUntilAllOperationsAreFinished()
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData().first
    }

    func testRegistersClientAndSignsRequest() throws {
        makeProvider()

        let result = try XCTUnwrap(try headers())

        XCTAssertEqual(Set(result.keys), [.profile, .clientId, .challenge, .appAttestAssertion])
        XCTAssertEqual(result[.profile], "2")
        XCTAssertEqual(remote.challengePurposes, [.request, .register, .request])
        XCTAssertEqual(appAttest.attestationKeyIds.count, 1)
        XCTAssertEqual(appAttest.assertionKeyIds.count, 1)
        XCTAssertEqual(try storedRow()?.isAttested, true)
    }

    func testReusesAttestedKey() throws {
        makeProvider()
        _ = try headers()
        let keyId = try XCTUnwrap(try storedRow()?.keyId)

        _ = try headers()

        XCTAssertEqual(appAttest.generatedKeyIds, [keyId])
        XCTAssertEqual(appAttest.attestationKeyIds, [keyId])
        XCTAssertEqual(appAttest.assertionKeyIds, [keyId, keyId])
        XCTAssertEqual(remote.registerCallCount, 1)
    }

    func testRetriesUnavailableAttestationWithSameKey() throws {
        makeProvider()
        appAttest.attestationError = AppAttestServiceError.serviceUnavailable
        XCTAssertThrowsError(try headers())
        let row = try XCTUnwrap(try storedRow())
        XCTAssertFalse(row.isAttested)

        XCTAssertThrowsError(try headers()) { error in
            guard case BackendAttestationError.retryLater = error else {
                return XCTFail("Expected retryLater, got \(error)")
            }
        }

        clock.advance(by: 61)
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(appAttest.generatedKeyIds, [row.keyId])
        XCTAssertEqual(appAttest.attestationKeyIds, [row.keyId, row.keyId])
        XCTAssertEqual(try storedRow()?.keyId, row.keyId)
    }

    func testMarkUnattestedRequiresCurrentClient() throws {
        makeProvider()
        let result = try XCTUnwrap(try headers())
        let clientId = try XCTUnwrap(result[.clientId])
        let row = try XCTUnwrap(try storedRow())

        provider.markUnattested(ifCurrentClientId: "another-client")
        XCTAssertEqual(try storedRow(), row)
        XCTAssertEqual(settings.gatewayAttestationClientId, clientId)

        provider.markUnattested(ifCurrentClientId: clientId)
        XCTAssertNil(try storedRow())

        _ = try headers()
        XCTAssertNotEqual(settings.gatewayAttestationClientId, clientId)
        XCTAssertNotEqual(try storedRow()?.keyId, row.keyId)
    }

    func testRejectsOtherOrigin() throws {
        makeProvider()

        XCTAssertThrowsError(try headers(origin: "https://another.example")) { error in
            guard case BackendAttestationError.unsupported = error else {
                return XCTFail("Expected unsupported, got \(error)")
            }
        }

        XCTAssertTrue(remote.challengePurposes.isEmpty)
        XCTAssertTrue(appAttest.generatedKeyIds.isEmpty)
        XCTAssertNil(settings.gatewayAttestationClientId)
    }

    func testForgetClientClearsState() throws {
        makeProvider()
        _ = try headers()

        let firstClientId = settings.gatewayAttestationClientId
        provider.forgetClient()

        XCTAssertNil(try storedRow())
        XCTAssertNil(settings.gatewayAttestationClientId)
        XCTAssertThrowsError(try headers())
        XCTAssertNil(settings.gatewayAttestationClientId)

        provider.allowClient()
        _ = try headers()
        XCTAssertNotEqual(settings.gatewayAttestationClientId, firstClientId)
    }

    func testOptOutDuringChallengeStopsRegistration() throws {
        makeProvider()
        remote.onChallenge = { [weak provider] in provider?.forgetClient() }

        XCTAssertThrowsError(try headers())

        XCTAssertEqual(remote.registerCallCount, 0)
        XCTAssertNil(try storedRow())
        XCTAssertNil(settings.gatewayAttestationClientId)
        XCTAssertTrue(appAttest.generatedKeyIds.isEmpty)
    }
}
