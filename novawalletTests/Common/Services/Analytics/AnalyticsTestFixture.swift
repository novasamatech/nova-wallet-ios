import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo
import NovaAppAttest

/// A fixture builder, not a protocol double. Everything except the uploader is the
/// production object: the real queue over an in-memory store, the real settings, the
/// real consent manager and the real identity.
struct AnalyticsTestFixture {
    let service: AnalyticsService
    let consent: AnalyticsConsentManager
    let availability: AnalyticsAvailabilityProvider
    let queue: CoreDataAnalyticsEventQueue
    let settings: InMemorySettingsManager
    let uploader: MockAnalyticsUploading
    /// Present only when a `deviceCheck` double is supplied: a real provider over a real
    /// `AppAttestService`, so a flush genuinely reaches DeviceCheck.
    let attestation: BackendAttestationProvider?
    let operationQueue: OperationQueue
    let uploadOperationQueue: OperationQueue
    /// Serial, so `sync {}` on it is a complete drain of everything already queued.
    let completionQueue: DispatchQueue
}

extension AnalyticsTestFixture {
    static func make(
        isAvailable: Bool = true,
        now: @escaping () -> Date = { Date() },
        deviceCheck: MockDeviceCheckAttesting? = nil
    ) -> AnalyticsTestFixture {
        let facade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(repository),
            maxCount: 500
        )

        let settings = InMemorySettingsManager()

        let availability = AnalyticsAvailabilityProvider(
            attestationMode: isAvailable ? .appAttest : .unavailable
        )

        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: availability
        )

        let attestation = deviceCheck.map {
            makeAttestation(deviceCheck: $0, settings: settings)
        }

        let uploader = MockAnalyticsUploading()
        stub(uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).then { _ in
                guard let attestation else {
                    return CompoundOperationWrapper<Void>.createWithResult(())
                }

                // A real flush signs the bytes it is about to send, so DeviceCheck is
                // reached exactly when a flush runs and never otherwise.
                let wrapper = attestation.createSignedHeadersWrapper { Data("{}".utf8) }

                let mapOperation = ClosureOperation<Void> {
                    _ = try wrapper.targetOperation.extractNoCancellableResultData()
                }

                mapOperation.addDependency(wrapper.targetOperation)

                return wrapper.insertingTail(operation: mapOperation)
            }
        }

        // Serial, exactly as OperationManagerFacade.analyticsQueue is: two enqueues in
        // flight at once would race for the same sequence number.
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let uploadOperationQueue = OperationQueue()
        let completionQueue = DispatchQueue(label: "test.analytics.completions")

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: eventQueue,
            identity: AnalyticsIdentity(settingsManager: settings),
            uploader: uploader,
            attestation: attestation,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue,
            completionQueue: completionQueue,
            timeProvider: now,
            logger: Logger.shared
        )

        return AnalyticsTestFixture(
            service: service,
            consent: consent,
            availability: availability,
            queue: eventQueue,
            settings: settings,
            uploader: uploader,
            attestation: attestation,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue,
            completionQueue: completionQueue
        )
    }

    /// The remote gateway is the only piece that cannot run: DeviceCheck comes in as the
    /// supplied double and everything between it and the queue is the production object.
    private static func makeAttestation(
        deviceCheck: MockDeviceCheckAttesting,
        settings: InMemorySettingsManager
    ) -> BackendAttestationProvider {
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        let remote = MockBackendAttestationRemoteFactoryProtocol()
        stub(remote) { stub in
            when(stub.createChallengeWrapper()).then { _ in
                CompoundOperationWrapper.createWithResult(UUID().uuidString)
            }

            when(stub.createRegisterOperation(any())).then { requestClosure in
                ClosureOperation<Void> { _ = try requestClosure() }
            }
        }

        return BackendAttestationProvider(
            appAttest: AppAttestService(service: deviceCheck),
            remoteFactory: remote,
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: AnyDataProviderRepository(repository),
            gatewayURL: URL(string: "https://gateway.example/")!,
            mode: .appAttest,
            bundle: Bundle.main,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    static func makeConsented(now: @escaping () -> Date = { Date() }) -> AnalyticsTestFixture {
        let fixture = make(now: now)
        fixture.consent.setEnabled(true)

        return fixture
    }

    /// Enqueue, count and clear all land on the service's serial queue, so waiting on it
    /// is the whole synchronisation the assertions need. Never a sleep.
    func drain() {
        operationQueue.waitUntilAllOperationsAreFinished()
    }

    /// A flush runs on the upload queue; its inner attestation operations finish before
    /// the outer wrapper does, so this one wait covers the whole signing chain.
    func drainUploads() {
        uploadOperationQueue.waitUntilAllOperationsAreFinished()
    }

    /// Flush completions are dispatched off the service's mutex, so an assertion about
    /// them has to wait for that hop. Serial queue, so this drains everything queued.
    func drainCompletions() {
        completionQueue.sync {}
    }

    func queueCount() throws -> Int {
        drain()

        let operation = queue.countOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    /// Writes straight to the queue, past the consent and availability guard, so a test
    /// can stage the rows a previous process would have left behind.
    func enqueueBypassingTheGuard(name: String) throws {
        drain()

        let wrapper = queue.enqueueWrapper(
            name: name,
            timestamp: Date(),
            payload: Data("{}".utf8)
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func peekNames() throws -> [String] {
        drain()

        let wrapper = queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map(\.name)
    }

    func persistedInstallId() -> String? {
        settings.string(for: SettingsKey.analyticsInstallId.rawValue)
    }

    func track(_ count: Int, _ event: @autoclosure () -> AnalyticsEvent) {
        for _ in 0 ..< count {
            service.track(event())
        }
    }
}
