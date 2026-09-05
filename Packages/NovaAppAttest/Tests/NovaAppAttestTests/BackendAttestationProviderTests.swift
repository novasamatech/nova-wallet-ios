import XCTest
@testable import NovaAppAttest
import Operation_iOS
import Keystore_iOS

final class BackendAttestationProviderTests: XCTestCase {
    private let gatewayURL = URL(string: "https://gateway.example/")!

    private enum OptOutPoint {
        case challenge
        case attestation
        case register
    }

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

    private final class SaveHookRepository: DataProviderRepositoryProtocol {
        typealias Model = AppAttestKeySettings

        private let wrapped: AnyDataProviderRepository<AppAttestKeySettings>
        private let afterAttestedSave: () -> Void

        init(
            wrapping wrapped: AnyDataProviderRepository<AppAttestKeySettings>,
            afterAttestedSave: @escaping () -> Void
        ) {
            self.wrapped = wrapped
            self.afterAttestedSave = afterAttestedSave
        }

        func saveOperation(
            _ updateModelsBlock: @escaping () throws -> [Model],
            _ deleteIdsBlock: @escaping () throws -> [String]
        ) -> BaseOperation<Void> {
            let sawAttested = AttestedFlag()

            let inner = wrapped.saveOperation({
                let models = try updateModelsBlock()

                if models.contains(where: \.isAttested) {
                    sawAttested.set()
                }

                return models
            }, deleteIdsBlock)

            return ClosureOperation<Void> { [afterAttestedSave] in
                OperationQueue().addOperations([inner], waitUntilFinished: true)
                try inner.extractNoCancellableResultData()

                guard sawAttested.value else {
                    return
                }

                afterAttestedSave()
            }
        }

        func fetchOperation(
            by modelIdClosure: @escaping () throws -> String,
            options: RepositoryFetchOptions
        ) -> BaseOperation<Model?> {
            wrapped.fetchOperation(by: modelIdClosure, options: options)
        }

        func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
            wrapped.fetchAllOperation(with: options)
        }

        func fetchOperation(
            by request: RepositorySliceRequest,
            options: RepositoryFetchOptions
        ) -> BaseOperation<[Model]> {
            wrapped.fetchOperation(by: request, options: options)
        }

        func replaceOperation(
            _ newModelsBlock: @escaping () throws -> [Model]
        ) -> BaseOperation<Void> {
            wrapped.replaceOperation(newModelsBlock)
        }

        func fetchCountOperation() -> BaseOperation<Int> {
            wrapped.fetchCountOperation()
        }

        func deleteAllOperation() -> BaseOperation<Void> {
            wrapped.deleteAllOperation()
        }
    }

    private final class AttestedFlag {
        private let mutex = NSLock()
        private var flag = false

        func set() {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            flag = true
        }

        var value: Bool {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            return flag
        }
    }

    private struct Fixture {
        let provider: BackendAttestationProvider
        let appAttest: AppAttestServiceSpy
        let remote: BackendAttestationRemoteFactorySpy
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
        thenReconsent: Bool = false,
        optOutAfterAttestedSave: Bool = false,
        sharingStoreWith existing: Fixture? = nil
    ) -> Fixture {
        let settings = existing?.settings ?? InMemorySettingsManager()

        let realRepository = AnyDataProviderRepository(
            SettingsAppAttestKeyRepository(settingsManager: settings)
        )

        let registered = RegisterRecorder()

        var providerBox: BackendAttestationProvider?

        let saveHook = OneShotHook { providerBox?.forgetClient() }

        let repository = optOutAfterAttestedSave
            ? AnyDataProviderRepository(
                SaveHookRepository(wrapping: realRepository) { saveHook.fire() }
            )
            : realRepository
        let optOutHook = OneShotHook {
            providerBox?.forgetClient()

            if thenReconsent {
                providerBox?.allowClient()
            }
        }

        let appAttest = AppAttestServiceSpy()

        if optOutAt == .attestation {
            appAttest.onAttestation = { optOutHook.fire() }
        }

        if let assertionError {
            appAttest.assertionResult = .failure(assertionError)
        }

        let remote = BackendAttestationRemoteFactorySpy()
        remote.registerError = registerError
        remote.onRegisterRequest = { registered.record($0) }

        if optOutAt == .challenge {
            remote.onChallenge = { optOutHook.fire() }
        }

        if optOutAt == .register {
            remote.onRegister = { optOutHook.fire() }
        }

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
            logger: SilentLogger()
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

    private func storedRow(_ fixture: Fixture) throws -> AppAttestKeySettings? {
        fixture.operationQueue.waitUntilAllOperationsAreFinished()

        let operation = fixture.repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData().first
    }

    func testFirstRequestAttestsThenAsserts() throws {
        let fixture = makeFixture()

        let result = try headers(fixture)

        XCTAssertNotNil(result?[.clientId])
        XCTAssertNotNil(result?[.challenge])
        XCTAssertNotNil(result?[.signature])
        XCTAssertEqual(fixture.appAttest.attestationKeyIds.count, 1)
        XCTAssertEqual(fixture.appAttest.assertionKeyIds.count, 1)
        XCTAssertEqual(try storedRow(fixture)?.isAttested, true)
    }

    func testSecondRequestSkipsAttestationAndOnlyAsserts() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)
        fixture.appAttest.reset()

        _ = try headers(fixture)

        XCTAssertTrue(fixture.appAttest.attestationKeyIds.isEmpty)
        XCTAssertEqual(fixture.appAttest.assertionKeyIds.count, 1)
    }

    func testKeyIdIsPersistedBeforeRegisterSoARetryReusesTheSameKey() throws {
        let fixture = makeFixture(registerError: BackendAttestationError.serverError(statusCode: 500))

        XCTAssertThrowsError(try headers(fixture))

        let row = try storedRow(fixture)
        XCTAssertNotNil(row?.keyId)
        XCTAssertEqual(row?.isAttested, false)
    }

    func testRegisterClientErrorKeepsTheRowAndDoesNotRejectTheProcess() throws {
        let fixture = makeFixture(registerError: BackendAttestationError.clientError(statusCode: 409))

        XCTAssertThrowsError(try headers(fixture))
        XCTAssertEqual(try storedRow(fixture)?.isAttested, false)

        let keyId = try storedRow(fixture)?.keyId

        fixture.remote.reset()
        XCTAssertThrowsError(try headers(fixture))
        XCTAssertGreaterThan(fixture.remote.challengeCallCount, 0)
        XCTAssertEqual(try storedRow(fixture)?.keyId, keyId)
    }

    func testRegisterRejectionShortCircuitsForTheRestOfTheProcess() throws {
        let fixture = makeFixture(registerError: BackendAttestationError.rejected(statusCode: 403))

        XCTAssertThrowsError(try headers(fixture))
        fixture.remote.reset()

        XCTAssertThrowsError(try headers(fixture)) { error in
            guard case BackendAttestationError.rejected = error else {
                return XCTFail("expected .rejected, got \(error)")
            }
        }
        XCTAssertEqual(fixture.remote.challengeCallCount, 0)
    }

    func testMarkUnattestedForcesAFreshKey() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)

        fixture.provider.markUnattested()
        XCTAssertNil(try storedRow(fixture))

        fixture.appAttest.reset()
        _ = try headers(fixture)

        XCTAssertEqual(fixture.appAttest.attestationKeyIds.count, 1)
        XCTAssertNil(fixture.appAttest.attestationKeyIds.last ?? nil)
    }

    func testForgetClientDropsTheRowAndTheClientId() throws {
        let fixture = makeFixture()
        _ = try headers(fixture)
        let firstClientId = fixture.settings.gatewayAttestationClientId

        fixture.provider.forgetClient()

        XCTAssertNil(try storedRow(fixture))
        XCTAssertNil(fixture.settings.gatewayAttestationClientId)

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

        XCTAssertThrowsError(try headers(fixture))
        XCTAssertNotNil(try storedRow(fixture))
    }

    func testUnsupportedModeReturnsNilHeaders() throws {
        let fixture = makeFixture(mode: .none)

        XCTAssertNil(try headers(fixture))
        XCTAssertTrue(fixture.appAttest.assertionKeyIds.isEmpty)
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

        XCTAssertEqual(fixture.appAttest.assertionClientDataClosures.count, 1)

        let clientData = try XCTUnwrap(fixture.appAttest.assertionClientDataClosures.last)()
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

    func testOptOutBeforeTheAttestationStepNeverTouchesAppAttest() throws {
        let fixture = makeFixture(optOutAt: .challenge)

        XCTAssertThrowsError(try headers(fixture))

        XCTAssertTrue(fixture.appAttest.attestationKeyIds.isEmpty)
        XCTAssertTrue(fixture.appAttest.assertionKeyIds.isEmpty)
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

    func testAnOptOutBetweenTheRowWriteAndTheCacheNeverResurrectsTheKey() throws {
        let fixture = makeFixture(optOutAfterAttestedSave: true)

        XCTAssertThrowsError(try headers(fixture))
        XCTAssertNil(try storedRow(fixture))

        fixture.provider.allowClient()
        fixture.appAttest.reset()

        _ = try headers(fixture)

        XCTAssertEqual(fixture.appAttest.attestationKeyIds.count, 1)
        XCTAssertNil(fixture.appAttest.attestationKeyIds.last ?? nil)
    }

    func testARowLeftBehindByAFailedOptOutDeleteIsNotAdoptedAfterReconsent() throws {
        let first = makeFixture()
        _ = try headers(first)

        let survivingRow = try XCTUnwrap(try storedRow(first))
        XCTAssertTrue(survivingRow.isAttested)

        first.settings.gatewayAttestationClientId = nil

        let relaunched = makeFixture(sharingStoreWith: first)

        XCTAssertNotNil(try storedRow(relaunched), "the stale row must still be on disk")

        _ = try headers(relaunched)

        XCTAssertEqual(relaunched.appAttest.attestationKeyIds.count, 1)
        XCTAssertNil(
            relaunched.appAttest.attestationKeyIds.last ?? nil,
            "the new consent cycle adopted the previous cycle's attested key"
        )

        let headersForNewClient = try headers(relaunched)
        XCTAssertNotEqual(
            headersForNewClient?[.clientId],
            nil
        )
    }

    func testAKeyAttestedAcrossAnOptOutNeverSignsForTheNewClient() throws {
        let fixture = makeFixture(optOutAt: .register)

        XCTAssertThrowsError(try headers(fixture))

        fixture.provider.allowClient()
        fixture.appAttest.reset()

        _ = try headers(fixture)

        XCTAssertEqual(fixture.appAttest.attestationKeyIds.count, 1)
        XCTAssertNil(fixture.appAttest.attestationKeyIds.last ?? nil)
    }

    func testTheConsentGateReadsTheEpochWithoutMintingAnIdentity() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        identity.forgetClientId()
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
