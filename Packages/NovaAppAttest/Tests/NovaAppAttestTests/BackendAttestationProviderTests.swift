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

    private func makeProvider(registerError: Error? = nil, attestationError: Error? = nil, optOutDuringChallenge: Bool = false) {
        settings = InMemorySettingsManager()
        repository = AnyDataProviderRepository(SettingsAppAttestKeyRepository(settingsManager: settings))
        operationQueue = OperationQueue()
        appAttest = AppAttestServiceSpy()
        appAttest.attestationError = attestationError
        remote = BackendAttestationRemoteFactorySpy()
        remote.registerError = registerError

        provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: remote,
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: repository,
            gatewayURL: URL(string: "https://gateway.example/")!,
            mode: .appAttest,
            operationQueue: operationQueue,
            logger: SilentLogger(),
            timeProvider: { [clock] in clock.now }
        )

        remote.onChallenge = optOutDuringChallenge ? { [weak provider] in provider?.forgetClient() } : nil
    }

    private func headers() throws -> [AttestationHeaderKey: String]? {
        let wrapper = provider.createSignedHeadersWrapper { Data("body".utf8) }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func storedRow() throws -> AppAttestKeySettings? {
        operationQueue.waitUntilAllOperationsAreFinished()
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData().first
    }

    func testFirstRequestAttestsThenAsserts() throws {
        makeProvider()
        let result = try XCTUnwrap(try headers())

        XCTAssertEqual(Set(result.keys), [.clientId, .challenge, .signature])
        XCTAssertEqual(appAttest.attestationKeyIds.count, 1)
        XCTAssertEqual(appAttest.assertionKeyIds.count, 1)
        XCTAssertEqual(try storedRow()?.isAttested, true)
    }

    func testSecondRequestSkipsAttestationAndOnlyAsserts() throws {
        makeProvider()
        _ = try headers()
        appAttest.reset()
        _ = try headers()

        XCTAssertTrue(appAttest.attestationKeyIds.isEmpty)
        XCTAssertEqual(appAttest.assertionKeyIds.count, 1)
    }

    func testAttestationFailureLeavesTheGeneratedKeyIdPersistedAsUnattested() throws {
        makeProvider(attestationError: AppAttestServiceError.serviceUnavailable)
        XCTAssertThrowsError(try headers())

        let row = try XCTUnwrap(try storedRow())

        XCTAssertEqual(row.keyId, appAttest.generatedKeyIds.first)
        XCTAssertFalse(row.isAttested)
    }

    func testServerUnavailableOnAttestationRetriesTheSameKeyWithoutMintingANewOne() throws {
        makeProvider(attestationError: AppAttestServiceError.serviceUnavailable)
        XCTAssertThrowsError(try headers())

        let keyId = try XCTUnwrap(try storedRow()?.keyId)

        clock.advance(by: 61)
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(appAttest.generateKeyCallCount, 1)
        XCTAssertEqual(appAttest.attestationKeyIds, [keyId, keyId])
        XCTAssertEqual(try storedRow()?.keyId, keyId)
    }

    func testARegisterClientErrorKeepsTheKeyAndRetriesItOnlyOnceTheWindowExpires() throws {
        makeProvider(registerError: BackendAttestationError.clientError(statusCode: 429))
        XCTAssertThrowsError(try headers())

        let row = try XCTUnwrap(try storedRow())
        XCTAssertFalse(row.isAttested)

        remote.reset()
        appAttest.reset()
        XCTAssertThrowsError(try headers()) { error in
            guard case BackendAttestationError.retryLater = error else {
                return XCTFail("expected .retryLater, got \(error)")
            }
        }
        XCTAssertEqual(remote.challengeCallCount, 0)
        XCTAssertEqual(remote.registerCallCount, 0)
        XCTAssertTrue(appAttest.attestationKeyIds.isEmpty)

        clock.advance(by: 61)
        XCTAssertThrowsError(try headers())

        XCTAssertGreaterThan(remote.challengeCallCount, 0)
        XCTAssertEqual(appAttest.attestationKeyIds, [row.keyId])
        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
        XCTAssertEqual(try storedRow()?.keyId, row.keyId)
    }

    func testRegisterRejectionShortCircuitsForTheRestOfTheProcess() throws {
        makeProvider(registerError: BackendAttestationError.rejected(statusCode: 403))
        XCTAssertThrowsError(try headers())
        remote.reset()

        XCTAssertThrowsError(try headers()) { error in
            guard case BackendAttestationError.rejected = error else {
                return XCTFail("expected .rejected, got \(error)")
            }
        }
        XCTAssertEqual(remote.challengeCallCount, 0)
    }

    func testAnEventsEndpointRejectionReMintsTheKeyOncePerLaunch() throws {
        makeProvider()
        _ = try headers()

        provider.markUnattested()
        XCTAssertNil(try storedRow())

        appAttest.reset()
        _ = try headers()

        XCTAssertEqual(appAttest.generateKeyCallCount, 1)
        XCTAssertEqual(appAttest.attestationKeyIds.count, 1)

        let reMinted = try XCTUnwrap(try storedRow())

        provider.markUnattested()
        XCTAssertEqual(try storedRow(), reMinted)
    }

    func testForgetClientDropsTheRowAndTheClientId() throws {
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

    func testOptOutDuringTheChallengeNeverRegistersAFreshKey() throws {
        makeProvider(optOutDuringChallenge: true)
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(remote.registerCallCount, 0)
        XCTAssertNil(try storedRow())
        XCTAssertNil(settings.gatewayAttestationClientId)
    }
}
