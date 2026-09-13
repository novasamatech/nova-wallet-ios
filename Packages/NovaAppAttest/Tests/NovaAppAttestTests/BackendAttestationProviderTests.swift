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
            appIdentity: AppAttestAppIdentity(
                appId: "ABCDEFGHIJ.io.novafoundation.novawallet.dev",
                environment: "production"
            ),
            operationQueue: operationQueue,
            logger: SilentLogger(),
            timeProvider: { [clock] in clock.now }
        )

        remote.onChallenge = optOutDuringChallenge ? { [weak provider] in provider?.forgetClient() } : nil
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

    func testFirstRequestAttestsOnlyAfterTheGatewayRefusesTheRequestChallenge() throws {
        makeProvider()
        let result = try XCTUnwrap(try headers())

        XCTAssertEqual(Set(result.keys), [.profile, .clientId, .challenge, .appAttestAssertion])
        XCTAssertEqual(result[.profile], "2")
        // The gateway's refusal is what starts attestation, so the request challenge is asked for
        // before any key exists and asked for again once the binding does.
        XCTAssertEqual(remote.challengePurposes, [.request, .register, .request])
        XCTAssertEqual(appAttest.attestationKeyIds.count, 1)
        XCTAssertEqual(appAttest.assertionKeyIds.count, 1)
        XCTAssertEqual(try storedRow()?.isAttested, true)
    }

    func testSecondRequestSkipsAttestationAndOnlyAsserts() throws {
        makeProvider()
        _ = try headers()
        appAttest.reset()
        remote.reset()
        _ = try headers()

        XCTAssertTrue(appAttest.attestationKeyIds.isEmpty)
        XCTAssertEqual(appAttest.assertionKeyIds.count, 1)
        // A gateway that still knows this client grants the challenge, so nothing registers again.
        XCTAssertEqual(remote.challengePurposes, [.request])
        XCTAssertEqual(remote.registerCallCount, 0)
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

    func testARegisterClientErrorWaitsForTheWindowAndThenAttestsAFreshKey() throws {
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

        // The first attempt already spent this key's one attestation, so retrying it could only earn
        // DCError.invalidKey: the window reopens on a freshly minted key instead.
        XCTAssertGreaterThan(remote.challengeCallCount, 0)
        XCTAssertEqual(appAttest.generateKeyCallCount, 1)
        XCTAssertFalse(appAttest.attestationKeyIds.contains(row.keyId))
        XCTAssertEqual(appAttest.attestationKeyIds, appAttest.generatedKeyIds)
        XCTAssertNotEqual(try storedRow()?.keyId, row.keyId)

        // The ladder keeps its place across episodes: this second failure escalates instead of
        // re-arming the first rung, so the window doubles rather than repeating 60 s.
        let escalated = try XCTUnwrap(try storedRow())
        XCTAssertEqual(escalated.attemptCount, 2)
        XCTAssertEqual(escalated.nextAttemptAt, clock.now.addingTimeInterval(120))
    }

    func testARegisterChallengeFailureLeavesTheKeyUnspentAndTheLadderIntact() throws {
        makeProvider()
        remote.registerChallengeError = BackendAttestationError.serverError(statusCode: 503)

        XCTAssertThrowsError(try headers())

        // attestKey never ran, so the key this row names must still be usable: recording it spent
        // would orphan a Secure Enclave key Apple can neither list nor delete.
        let row = try XCTUnwrap(try storedRow())
        XCTAssertFalse(row.isAttestationSpent)
        XCTAssertTrue(appAttest.attestationKeyIds.isEmpty)
        XCTAssertEqual(appAttest.generateKeyCallCount, 1)

        // The same key is retried when the window reopens, and the ladder escalates.
        clock.advance(by: 61)
        appAttest.reset()
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
        XCTAssertEqual(try storedRow()?.keyId, row.keyId)
        XCTAssertEqual(try storedRow()?.attemptCount, 2)
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

    func testAnEventsEndpointRejectionReMintsTheKeyAndTheClientIdOncePerLaunch() throws {
        makeProvider()
        _ = try headers()

        let rejectedClientId = settings.gatewayAttestationClientId

        provider.markUnattested()
        XCTAssertNil(try storedRow())

        appAttest.reset()
        _ = try headers()

        XCTAssertEqual(appAttest.generateKeyCallCount, 1)
        XCTAssertEqual(appAttest.attestationKeyIds.count, 1)
        XCTAssertNotEqual(settings.gatewayAttestationClientId, rejectedClientId)

        let reMinted = try XCTUnwrap(try storedRow())

        provider.markUnattested()
        XCTAssertEqual(try storedRow(), reMinted)
    }

    func testAnUnauthorizedRegisterRetiresTheIdentityAndRetriesExactlyOnce() throws {
        makeProvider(registerError: BackendAttestationError.unauthorized(statusCode: 401))

        XCTAssertThrowsError(try headers()) { error in
            guard case BackendAttestationError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(remote.registerCallCount, 2)
        XCTAssertEqual(remote.registeredClientIds.count, 2)
        XCTAssertNotEqual(remote.registeredClientIds.first, remote.registeredClientIds.last)
        XCTAssertEqual(appAttest.generateKeyCallCount, 2)

        // With the launch's one retirement spent, a repeating 401 arms the persisted window rather
        // than replaying the request the gateway just refused: otherwise every flush would mint a
        // key and spend an attestKey call on a verdict nothing has changed.
        _ = try storedRow()
        remote.reset()
        appAttest.reset()
        XCTAssertThrowsError(try headers()) { error in
            guard case BackendAttestationError.retryLater = error else {
                return XCTFail("expected .retryLater, got \(error)")
            }
        }

        XCTAssertEqual(remote.registerCallCount, 0)
        XCTAssertEqual(appAttest.generateKeyCallCount, 0)

        // A consent cycle mints an identity the gateway has never refused, so the launch brake and
        // the window it armed both start over.
        provider.allowClient()
        remote.reset()
        appAttest.reset()
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(remote.registerCallCount, 2)
        XCTAssertEqual(Set(remote.registeredClientIds).count, 2)
    }

    func testAChallengeFailureNeverCostsTheAttestedKeyOrTheIdentity() throws {
        makeProvider()
        _ = try headers()

        let attestedClientId = settings.gatewayAttestationClientId
        let attestedRow = try XCTUnwrap(try storedRow())

        // The challenge POST carries no identity, so nothing it answers can be a verdict on one.
        remote.challengeError = BackendAttestationError.clientError(statusCode: 401)
        appAttest.reset()
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(settings.gatewayAttestationClientId, attestedClientId)
        XCTAssertEqual(try storedRow(), attestedRow)
        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
    }

    func testAChallengeFailureThatIsNotAVerdictNeverStartsAttestation() throws {
        makeProvider()

        // Only the gateway saying it does not know this client may start attestation. A 503 says
        // nothing about the binding, so nothing is minted and no row is left behind.
        remote.challengeError = BackendAttestationError.serverError(statusCode: 503)
        XCTAssertThrowsError(try headers())

        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
        XCTAssertNil(try storedRow())
    }

    func testARequestForAnotherOriginIsNeverAttested() throws {
        makeProvider()

        for origin in ["https://attacker.example", "https://gateway.example:8443", "http://gateway.example"] {
            XCTAssertThrowsError(try headers(origin: origin)) { error in
                guard case BackendAttestationError.unsupported = error else {
                    return XCTFail("expected .unsupported for \(origin), got \(error)")
                }
            }
        }

        XCTAssertEqual(remote.challengeCallCount, 0)
        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
        XCTAssertNil(settings.gatewayAttestationClientId)
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
        // Key generation is the one step the register subtree guards with no epoch check of its own.
        XCTAssertEqual(appAttest.generateKeyCallCount, 0)
    }
}
