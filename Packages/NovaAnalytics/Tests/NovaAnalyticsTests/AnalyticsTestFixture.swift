import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS
import NovaAppAttest
import NovaOperationSupport
import SDKLogger

struct AnalyticsTestFixture {
    let service: AnalyticsService
    let consent: AnalyticsConsentManager
    let availability: AnalyticsAvailabilityProvider
    let queue: CoreDataAnalyticsEventQueue
    let clearInterceptor: AnalyticsEventQueueClearInterceptor
    let identity: AnalyticsIdentity
    let settings: SerialisedSettingsManager
    let uploader: AnalyticsUploadingSpy
    let attestation: BackendAttestationProvider?
    let operationQueue: OperationQueue
    let uploadOperationQueue: OperationQueue
    let attestationOperationQueue: OperationQueue
    let completionQueue: DispatchQueue
}

extension AnalyticsTestFixture {
    enum Keys {
        static let analyticsEnabled = "analyticsEnabled"
        static let analyticsInstallId = "analyticsInstallId"
        static let erasureOwed = "analyticsErasureOwed"
        static let gatewayClientId = "gatewayAttestationClientId"
        static let appAttestKeys = "appAttestKeys"
        static let remoteEnabled = "analyticsRemoteEnabled"
    }

    static func make(
        isAvailable: Bool = true,
        resolvesRemote: Bool = true,
        now: @escaping () -> Date = { Date() },
        deviceCheck: DeviceCheckAttestingSpy? = nil,
        clearError: Error? = nil,
        settings: SerialisedSettingsManager = SerialisedSettingsManager(),
        storage: AnalyticsStorageTestFacade = AnalyticsStorageTestFacade(),
        logger: SDKLoggerProtocol = SilentLogger()
    ) -> AnalyticsTestFixture {
        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(storage.createEventRepository()),
            maxCount: 500
        )

        let clearInterceptor = AnalyticsEventQueueClearInterceptor(wrapping: eventQueue)
        clearInterceptor.clearError = clearError

        let availability = AnalyticsAvailabilityProvider(
            attestationMode: isAvailable ? .appAttest : .unavailable,
            settingsManager: settings
        )

        if resolvesRemote {
            availability.setRemoteEnabled(true)
        }

        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: availability
        )

        let attestationOperationQueue = OperationQueue()

        let attestation = deviceCheck.map {
            makeAttestation(deviceCheck: $0, settings: settings, operationQueue: attestationOperationQueue)
        }

        let uploader = AnalyticsUploadingSpy()
        uploader.flushStub = { _ in
            guard let attestation else {
                return CompoundOperationWrapper<Void>.createWithResult(())
            }

            let wrapper = attestation.createSignedHeadersWrapper { Data("{}".utf8) }

            let mapOperation = ClosureOperation<Void> {
                _ = try wrapper.targetOperation.extractNoCancellableResultData()
            }

            mapOperation.addDependency(wrapper.targetOperation)

            return wrapper.insertingTail(operation: mapOperation)
        }

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let uploadOperationQueue = OperationQueue()
        let completionQueue = DispatchQueue(label: "test.analytics.completions")

        let identity = AnalyticsIdentity(settingsManager: settings)

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: clearInterceptor,
            identity: identity,
            uploader: uploader,
            attestation: attestation,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue,
            completionQueue: completionQueue,
            timeProvider: now,
            logger: logger
        )

        return AnalyticsTestFixture(
            service: service,
            consent: consent,
            availability: availability,
            queue: eventQueue,
            clearInterceptor: clearInterceptor,
            identity: identity,
            settings: settings,
            uploader: uploader,
            attestation: attestation,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue,
            attestationOperationQueue: attestationOperationQueue,
            completionQueue: completionQueue
        )
    }

    private static func makeAttestation(
        deviceCheck: DeviceCheckAttestingSpy,
        settings: SerialisedSettingsManager,
        operationQueue: OperationQueue
    ) -> BackendAttestationProvider {
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        return BackendAttestationProvider(
            appAttest: AppAttestService(service: deviceCheck),
            remoteFactory: BackendAttestationRemoteFactorySpy(),
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: AnyDataProviderRepository(repository),
            gatewayURL: URL(string: "https://gateway.example/")!,
            mode: .appAttest,
            bundle: Bundle.main,
            operationQueue: operationQueue,
            logger: SilentLogger()
        )
    }

    static func makeConsented(
        now: @escaping () -> Date = { Date() },
        deviceCheck: DeviceCheckAttestingSpy? = nil,
        settings: SerialisedSettingsManager = SerialisedSettingsManager(),
        storage: AnalyticsStorageTestFacade = AnalyticsStorageTestFacade()
    ) -> AnalyticsTestFixture {
        settings.set(value: true, for: Keys.analyticsEnabled)

        return make(now: now, deviceCheck: deviceCheck, settings: settings, storage: storage)
    }

    static func makeUnresolved(
        settings: SerialisedSettingsManager,
        storage: AnalyticsStorageTestFacade
    ) -> AnalyticsTestFixture {
        make(resolvesRemote: false, settings: settings, storage: storage)
    }

    func drain() {
        operationQueue.waitUntilAllOperationsAreFinished()
    }

    func drainUploads() {
        uploadOperationQueue.waitUntilAllOperationsAreFinished()
    }

    func drainAttestation() {
        attestationOperationQueue.waitUntilAllOperationsAreFinished()
    }

    func drainCompletions() {
        completionQueue.sync {}
    }

    func queueCount() throws -> Int {
        drain()

        let operation = queue.countOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func enqueueBypassingTheGuard(name: String) throws {
        drain()

        let wrapper = queue.enqueueWrapper(
            name: name,
            timestamp: Date(),
            payload: Data("{}".utf8),
            consentEpoch: identity.consentEpoch
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func peekEvents() throws -> [AnalyticsPendingEvent] {
        drain()

        let wrapper = queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func peekNames() throws -> [String] {
        try peekEvents().map(\.name)
    }

    func persistedInstallId() -> String? {
        settings.string(for: Keys.analyticsInstallId)
    }

    func track(_ count: Int, _ event: @autoclosure () -> AnalyticsEvent) {
        for _ in 0 ..< count {
            service.track(event())
        }
    }
}
