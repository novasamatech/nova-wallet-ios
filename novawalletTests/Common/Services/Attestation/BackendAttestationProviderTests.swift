import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class BackendAttestationProviderTests: XCTestCase {
    private let gatewayURL = URL(string: "https://gateway.example/")!

    private struct Fixture {
        let provider: BackendAttestationProvider
        let appAttest: MockAppAttestServiceProtocol
        let remote: MockBackendAttestationRemoteFactoryProtocol
        let settings: InMemorySettingsManager
        let repository: AnyDataProviderRepository<AppAttestKeySettings>
        let operationQueue: OperationQueue
    }

    private func makeFixture(
        mode: BackendAttestationMode = .appAttest,
        registerError: Error? = nil,
        assertionError: Error? = nil
    ) -> Fixture {
        let facade = UserDataStorageTestFacade()
        let coreDataRepository: CoreDataRepository<AppAttestKeySettings, CDAppAttestKey> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(AppAttestKeyMapper())
            )

        let repository = AnyDataProviderRepository(coreDataRepository)

        let appAttest = MockAppAttestServiceProtocol()
        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)

            when(stub.createAttestationWrapper(using: any(), clientData: any())).then { keyId, clientData in
                let resolvedKeyId = keyId ?? UUID().uuidString

                return CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAttestation> {
                    _ = try clientData(resolvedKeyId)

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
                CompoundOperationWrapper.createWithResult(UUID().uuidString)
            }

            when(stub.createRegisterOperation(any())).then { requestClosure in
                ClosureOperation<Void> {
                    _ = try requestClosure()

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

        return Fixture(
            provider: provider,
            appAttest: appAttest,
            remote: remote,
            settings: settings,
            repository: repository,
            operationQueue: operationQueue
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
}
