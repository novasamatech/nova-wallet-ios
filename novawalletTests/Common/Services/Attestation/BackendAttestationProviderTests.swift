import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class BackendAttestationProviderTests: XCTestCase {
    private let gatewayURL = URL(string: "https://gateway.example/")!

    /// Where in the already-composed chain the user opts out. Each point sits after the
    /// composition-time client id read, so only an execution-time gate can stop it.
    private enum OptOutPoint {
        case challenge
        case attestation
        case register
    }

    /// Records the registration requests that actually reached the transport. Counting
    /// `createRegisterOperation` calls would not do: the operation is *constructed* before
    /// the opt-out lands, and what must not happen is its request closure producing a value.
    private final class RegisterRecorder {
        private let mutex = NSLock()
        private var requests: [BackendAttestationRegisterRequest] = []

        func record(_ request: BackendAttestationRegisterRequest) {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            requests.append(request)
        }

        var recorded: [BackendAttestationRegisterRequest] {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            return requests
        }
    }

    /// Fires its closure exactly once, however many times the chain reaches it — a signed
    /// request asks for two challenges, and the opt-out must be injected at one point only.
    private final class OneShotHook {
        private let mutex = NSLock()
        private var hasFired = false
        private let body: () -> Void

        init(_ body: @escaping () -> Void) {
            self.body = body
        }


        func fire() {
            mutex.lock()
            let shouldFire = !hasFired
            hasFired = true
            mutex.unlock()

            guard shouldFire else {
                return
            }

            body()
        }
    }

    private struct Fixture {
        let provider: BackendAttestationProvider
        let appAttest: MockAppAttestServiceProtocol
        let remote: MockBackendAttestationRemoteFactoryProtocol
        let settings: InMemorySettingsManager
        let repository: AnyDataProviderRepository<AppAttestKeySettings>
        let operationQueue: OperationQueue
        let registered: RegisterRecorder
    }

    private func makeFixture(
        mode: BackendAttestationMode = .appAttest,
        registerError: Error? = nil,
        assertionError: Error? = nil,
        optOutAt: OptOutPoint? = nil,
        thenReconsent: Bool = false
    ) -> Fixture {
        let facade = UserDataStorageTestFacade()
        let coreDataRepository: CoreDataRepository<AppAttestKeySettings, CDAppAttestKey> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(AppAttestKeyMapper())
            )

        let repository = AnyDataProviderRepository(coreDataRepository)

        let registered = RegisterRecorder()

        // Assigned after the provider exists; the hook only ever runs inside an operation,
        // by which time the box is populated.
        var providerBox: BackendAttestationProvider?
        let optOutHook = OneShotHook {
            providerBox?.forgetClient()

            if thenReconsent {
                // Re-arms minting. A `clientId() != nil` gate would now mint a *new* id and
                // wave this stale chain through to register the old one.
                providerBox?.allowClient()
            }
        }

        let appAttest = MockAppAttestServiceProtocol()
        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)

            when(stub.createAttestationWrapper(using: any(), clientData: any())).then { keyId, clientData in
                let resolvedKeyId = keyId ?? UUID().uuidString

                return CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAttestation> {
                    _ = try clientData(resolvedKeyId)

                    if optOutAt == .attestation {
                        optOutHook.fire()
                    }

                    return AppAttestAttestation(
                        keyId: resolvedKeyId,
                        attestation: Data("attestation-object".utf8)
                    )
                })
            }

            when(stub.createAssertionWrapper(keyId: any(), clientData: any())).then { _, clientData in
                CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAssertion> {
                    _ = try clientData()

                    if let assertionError {
                        throw assertionError
                    }

                    return Data("assertion".utf8)
                })
            }
        }

        let remote = MockBackendAttestationRemoteFactoryProtocol()
        stub(remote) { stub in
            when(stub.createChallengeWrapper()).then { _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<String> {
                    if optOutAt == .challenge {
                        optOutHook.fire()
                    }

                    return UUID().uuidString
                })
            }

            when(stub.createRegisterOperation(any())).then { requestClosure in
                ClosureOperation<Void> {
                    if optOutAt == .register {
                        optOutHook.fire()
                    }

                    try registered.record(requestClosure())

                    if let registerError {
                        throw registerError
                    }
                }
            }
        }

        let settings = InMemorySettingsManager()
        let operationQueue = OperationQueue()

        let provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: remote,
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: repository,
            gatewayURL: gatewayURL,
            mode: mode,
            bundle: Bundle.main,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        providerBox = provider

        return Fixture(
            provider: provider,
            appAttest: appAttest,
            remote: remote,
            settings: settings,
            repository: repository,
            operationQueue: operationQueue,
            registered: registered
        )
    }

    private func headers(_ fixture: Fixture) throws -> [AttestationHeaderKey: String]? {
        let wrapper = fixture.provider.createSignedHeadersWrapper { Data("body".utf8) }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    /// Recovery deletes the row through the provider's own queue, so the assertions wait
    /// on it exactly as `AnalyticsTestFixture.drain()` waits on the service's queue.
    private func storedRow(_ fixture: Fixture) throws -> AppAttestKeySettings? {
        fixture.operationQueue.waitUntilAllOperationsAreFinished()

        let operation = fixture.repository.fetchOperation(
            by: { self.gatewayURL.absoluteString },
            options: RepositoryFetchOptions()
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }

    func testFirstRequestAttestsThenAsserts() throws {
        let fixture = makeFixture()

        let result = try headers(fixture)

        XCTAssertNotNil(result?[.clientId])
        XCTAssertNotNil(result?[.challenge])
        XCTAssertNotNil(result?[.signature])
        verify(fixture.appAttest, times(1)).createAttestationWrapper(using: any(), clientData: any())
        verify(fixture.appAttest, times(1)).createAssertionWrapper(keyId: any(), clientData: any())
        XCTAssertEqual(try storedRow(fixture)?.isAttested, true)
    }

    func testSecondRequestSkipsAttestationAndOnlyAsserts() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)
        clearInvocations(fixture.appAttest)

        _ = try headers(fixture)

        // Apple asks apps to attest sparingly: a key is attested once, ever.
        verify(fixture.appAttest, never()).createAttestationWrapper(using: any(), clientData: any())
        verify(fixture.appAttest, times(1)).createAssertionWrapper(keyId: any(), clientData: any())
    }

    func testKeyIdIsPersistedBeforeRegisterSoARetryReusesTheSameKey() throws {
        let fixture = makeFixture(registerError: BackendAttestationError.serverError(statusCode: 500))

        XCTAssertThrowsError(try headers(fixture))

        let row = try storedRow(fixture)
        XCTAssertNotNil(row?.keyId)
        XCTAssertEqual(row?.isAttested, false)
    }

    func testRegisterClientErrorKeepsTheRowAndDoesNotRejectTheProcess() throws {
        // A 409/422/429 from a challenge that expired during the Apple round-trip is
        // not a rejected client.
        let fixture = makeFixture(registerError: BackendAttestationError.clientError(statusCode: 409))

        XCTAssertThrowsError(try headers(fixture))
        XCTAssertEqual(try storedRow(fixture)?.isAttested, false)

        let keyId = try storedRow(fixture)?.keyId

        clearInvocations(fixture.remote)
        XCTAssertThrowsError(try headers(fixture))
        verify(fixture.remote, atLeastOnce()).createChallengeWrapper()
        XCTAssertEqual(try storedRow(fixture)?.keyId, keyId)
    }

    func testRegisterRejectionShortCircuitsForTheRestOfTheProcess() throws {
        let fixture = makeFixture(registerError: BackendAttestationError.rejected(statusCode: 403))

        XCTAssertThrowsError(try headers(fixture))
        clearInvocations(fixture.remote)

        XCTAssertThrowsError(try headers(fixture)) { error in
            guard case BackendAttestationError.rejected = error else {
                return XCTFail("expected .rejected, got \(error)")
            }
        }
        verify(fixture.remote, never()).createChallengeWrapper()
    }

    func testMarkUnattestedForcesAFreshKey() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)

        fixture.provider.markUnattested()
        XCTAssertNil(try storedRow(fixture))

        clearInvocations(fixture.appAttest)
        _ = try headers(fixture)

        // Recovery always means a NEW key, never a second attestation of the old one.
        let captor = ArgumentCaptor<AppAttestKeyId?>()
        verify(fixture.appAttest).createAttestationWrapper(using: captor.capture(), clientData: any())
        XCTAssertNil(captor.value ?? nil)
    }

    func testForgetClientDropsTheRowAndTheClientId() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)
        let firstClientId = fixture.settings.gatewayAttestationClientId

        fixture.provider.forgetClient()

        XCTAssertNil(try storedRow(fixture))
        XCTAssertNil(fixture.settings.gatewayAttestationClientId)

        // Opting out latches minting shut, so an upload chain still executing cannot
        // register a fresh attested client behind the user's back.
        XCTAssertThrowsError(try headers(fixture))
        XCTAssertNil(fixture.settings.gatewayAttestationClientId)

        fixture.provider.allowClient()

        _ = try headers(fixture)
        XCTAssertNotEqual(fixture.settings.gatewayAttestationClientId, firstClientId)
    }

    func testInvalidKeyIdDiscardsTheRowAtMostOncePerLaunch() throws {
        let fixture = makeFixture(assertionError: AppAttestServiceError.invalidKeyId)

        XCTAssertThrowsError(try headers(fixture))
        XCTAssertNil(try storedRow(fixture))

        // A second invalidKeyId must not loop into endless key generation.
        XCTAssertThrowsError(try headers(fixture))
        XCTAssertNotNil(try storedRow(fixture))
    }

    func testUnsupportedModeReturnsNilHeaders() throws {
        let fixture = makeFixture(mode: .none)

        XCTAssertNil(try headers(fixture))
        verify(fixture.appAttest, never()).createAssertionWrapper(keyId: any(), clientData: any())
    }

    func testUnavailableModeThrows() {
        let fixture = makeFixture(mode: .unavailable)

        XCTAssertThrowsError(try headers(fixture)) { error in
            guard case BackendAttestationError.unsupported = error else {
                return XCTFail("expected .unsupported, got \(error)")
            }
        }
    }

    func testAssertionClientDataCoversTheExactBodyBytes() throws {
        let fixture = makeFixture()
        let body = Data(#"{"v":1}"#.utf8)

        let wrapper = fixture.provider.createSignedHeadersWrapper { body }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        _ = try wrapper.targetOperation.extractNoCancellableResultData()

        let captor = ArgumentCaptor<() throws -> Data>()
        verify(fixture.appAttest).createAssertionWrapper(keyId: any(), clientData: captor.capture())

        let clientData = try XCTUnwrap(captor.value)()
        XCTAssertTrue(
            String(data: clientData, encoding: .utf8)!
                .hasSuffix(AttestationClientData.bodyDigestHex(body))
        )
    }

    func testOptOutBeforeTheChainStartsIsRefused() throws {
        let fixture = makeFixture()

        fixture.provider.forgetClient()

        XCTAssertThrowsError(try headers(fixture))

        XCTAssertNil(try storedRow(fixture))
        XCTAssertNil(fixture.settings.gatewayAttestationClientId)
        XCTAssertEqual(fixture.registered.recorded.count, 0)
    }

    func testOptOutDuringTheChallengeNeverRegistersAFreshKey() throws {
        try assertOptOutMidChainRegistersNothing(at: .challenge)
    }

    func testOptOutDuringTheAppleAttestationNeverRegistersAFreshKey() throws {
        try assertOptOutMidChainRegistersNothing(at: .attestation)
    }

    func testOptOutJustBeforeTheRegisterPostNeverRegistersAFreshKey() throws {
        try assertOptOutMidChainRegistersNothing(at: .register)
    }

    /// The chain is composed while consent is still on — the client id and the epoch are
    /// read before any of these hooks fire — so nothing here is stopped by the entry guard.
    private func assertOptOutMidChainRegistersNothing(at point: OptOutPoint) throws {
        let fixture = makeFixture(optOutAt: point)

        XCTAssertThrowsError(try headers(fixture))

        XCTAssertEqual(
            fixture.registered.recorded.count,
            0,
            "a registration reached the gateway after the user opted out at \(point)"
        )
        XCTAssertNil(try storedRow(fixture), "the key row survived an opt-out at \(point)")
        XCTAssertNil(fixture.settings.gatewayAttestationClientId)
    }

    /// The gate before the Secure Enclave work, not just the ones before the network calls:
    /// generating and attesting a key for an install that has just opted out burns one of
    /// Apple's per-key attestations and produces a credential nothing should ever hold.
    func testOptOutBeforeTheAttestationStepNeverTouchesAppAttest() throws {
        let fixture = makeFixture(optOutAt: .challenge)

        XCTAssertThrowsError(try headers(fixture))

        verify(fixture.appAttest, never()).createAttestationWrapper(using: any(), clientData: any())
        verify(fixture.appAttest, never()).createAssertionWrapper(keyId: any(), clientData: any())
    }

    func testReconsentDuringTheChallengeNeverRegistersTheOldClient() throws {
        try assertReconsentMidChainRegistersNothing(at: .challenge)
    }

    func testReconsentDuringTheAppleAttestationNeverRegistersTheOldClient() throws {
        try assertReconsentMidChainRegistersNothing(at: .attestation)
    }

    func testReconsentJustBeforeTheRegisterPostNeverRegistersTheOldClient() throws {
        try assertReconsentMidChainRegistersNothing(at: .register)
    }

    /// The opt-out→re-consent race is what separates the epoch gate from the
    /// `identity.clientId() != nil` predicate it replaced: after `allowClient()` that
    /// accessor mints happily, so a chain composed in the previous consent cycle would sail
    /// through every gate and register its stale client id against the new identity.
    private func assertReconsentMidChainRegistersNothing(at point: OptOutPoint) throws {
        let fixture = makeFixture(optOutAt: point, thenReconsent: true)

        XCTAssertThrowsError(try headers(fixture))

        XCTAssertEqual(
            fixture.registered.recorded.count,
            0,
            "a client id from the previous consent cycle was registered after re-consent at \(point)"
        )
        XCTAssertNil(try storedRow(fixture), "the key row survived a re-consent at \(point)")
    }

    func testAKeyAttestedAcrossAnOptOutNeverSignsForTheNewClient() throws {
        let fixture = makeFixture(optOutAt: .register)

        XCTAssertThrowsError(try headers(fixture))

        // Re-consent, then run a clean chain. If `cacheAttestedKeyId` had run on the far
        // side of the opt-out, this would assert the *old* key — a key minted for the
        // previous consent cycle signing for the new one.
        fixture.provider.allowClient()
        clearInvocations(fixture.appAttest)

        _ = try headers(fixture)

        let captor = ArgumentCaptor<AppAttestKeyId?>()
        verify(fixture.appAttest).createAttestationWrapper(using: captor.capture(), clientData: any())
        XCTAssertNil(captor.value ?? nil)
    }

    /// The guard must not be `identity.clientId() != nil`: that accessor mints, so during
    /// an opt-out→re-consent race it would write a brand new client id and then wave the
    /// stale chain through to register the old one.
    func testTheConsentGateReadsTheEpochWithoutMintingAnIdentity() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        identity.forgetClientId()
        // Re-consent re-arms minting, which is what makes the two accessors differ here.
        identity.allowCreation()

        XCTAssertNil(settings.gatewayAttestationClientId)

        _ = identity.consentEpoch

        XCTAssertNil(
            settings.gatewayAttestationClientId,
            "the chain's consent gate minted a client id"
        )

        _ = identity.clientId()

        XCTAssertNotNil(
            settings.gatewayAttestationClientId,
            "clientId() is expected to mint — that is precisely why it cannot be the gate"
        )
    }

    func testTheEpochChangesOnEveryConsentBoundary() {
        let identity = BackendAttestationIdentity(settingsManager: InMemorySettingsManager())

        let initial = identity.consentEpoch
        identity.forgetClientId()
        let afterForget = identity.consentEpoch
        identity.allowCreation()
        let afterAllow = identity.consentEpoch

        XCTAssertNotEqual(initial, afterForget)
        XCTAssertNotEqual(afterForget, afterAllow)
        XCTAssertNotEqual(initial, afterAllow)
    }
}
