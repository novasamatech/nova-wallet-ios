import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import SDKLogger
import NovaAppAttest

public final class AnalyticsServiceFacade {
    public let consent: AnalyticsConsentManagerProtocol

    private let isFirstLaunch: () -> Bool
    private let service: AnalyticsService
    private let sessionTracker: AnalyticsSessionTracking
    private let availability: AnalyticsAvailabilityProvider
    private let eventQueue: AnalyticsEventQueueProtocol
    private let remoteSettings: AnalyticsRemoteSettings
    private let configOperationQueue: OperationQueue
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()
    private var isSetUp: Bool = false
    private var isActive: Bool = false
    private var isResolving: Bool = false

    public init(configuration: AnalyticsConfiguration) {
        let settingsManager = configuration.settingsManager

        let storageFacade = AnalyticsStorageFacade(
            storeDirectory: configuration.storeDirectory
        )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: storageFacade.createEventRepository()
        )

        let appAttest = AppAttestService()

        let attestationMode = BackendAttestationModeResolver.resolve(
            isReleaseBuild: configuration.isReleaseBuild,
            isAppAttestSupported: appAttest.isSupported
        )

        let availability = AnalyticsAvailabilityProvider(
            attestationMode: attestationMode,
            settingsManager: settingsManager
        )

        let consent = AnalyticsConsentManager(
            settingsManager: settingsManager,
            availabilityProvider: availability
        )

        let gatewayURL = configuration.gatewayURL

        let attestKeyRepository = SettingsAppAttestKeyRepository(settingsManager: settingsManager)

        let attestation = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: gatewayURL),
            identity: BackendAttestationIdentity(settingsManager: settingsManager),
            repository: AnyDataProviderRepository(attestKeyRepository),
            gatewayURL: gatewayURL,
            mode: attestationMode,
            operationQueue: configuration.operationQueue,
            logger: configuration.logger
        )

        let identity = AnalyticsIdentity(settingsManager: settingsManager)

        let uploader = AnalyticsUploader(
            queue: eventQueue,
            identity: identity,
            attestation: attestation,
            uploadFactory: AnalyticsUploadOperationFactory(baseURL: gatewayURL),
            operationQueue: configuration.operationQueue,
            appVersion: configuration.appVersion,
            logger: configuration.logger
        )

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: eventQueue,
            identity: identity,
            uploader: uploader,
            attestation: attestation,
            operationQueue: configuration.analyticsOperationQueue,
            uploadOperationQueue: configuration.operationQueue,
            logger: configuration.logger
        )

        let sessionTracker = AnalyticsSessionTracker(
            tracker: service,
            applicationHandler: ApplicationHandler(),
            backgroundTaskRunner: UIApplicationBackgroundTaskRunner()
        )

        isFirstLaunch = configuration.isFirstLaunch
        self.consent = consent
        self.service = service
        self.sessionTracker = sessionTracker
        self.availability = availability
        self.eventQueue = eventQueue
        remoteSettings = configuration.remoteSettings
        configOperationQueue = configuration.operationQueue
        logger = configuration.logger

        consent.addObserver(with: self, queue: nil) { [weak self] oldValue, newValue in
            guard !oldValue, newValue else {
                return
            }

            self?.startSessionIfActive()
        }
    }
}

// MARK: - AnalyticsServiceFacadeProtocol

extension AnalyticsServiceFacade: AnalyticsServiceFacadeProtocol {
    public func setup() {
        mutex.lock()

        guard !isSetUp else {
            mutex.unlock()
            return
        }

        isSetUp = true
        mutex.unlock()

        resolveRemoteAvailability()
    }

    public func throttle() {
        mutex.lock()

        guard isSetUp else {
            mutex.unlock()
            return
        }

        isSetUp = false
        mutex.unlock()

        reconcile()
    }

    public func track(_ event: AnalyticsEvent) {
        service.track(event)
    }

    public func trackAndFlush(
        _ event: AnalyticsEvent,
        reason: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        service.trackAndFlush(event, reason: reason, completion: completion)
    }

    public func flush(reason: AnalyticsFlushReason) {
        service.flush(reason: reason)
    }
}

// MARK: - AnalyticsDebugInspecting

extension AnalyticsServiceFacade: AnalyticsDebugInspecting {
    public func debugPendingEventsWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        eventQueue.peekWrapper(count: count)
    }

    public func debugClearPendingEventsOperation() -> BaseOperation<Void> {
        eventQueue.clearOperation()
    }
}

// MARK: - Private

private extension AnalyticsServiceFacade {
    func resolveRemoteAvailability() {
        mutex.lock()

        guard isSetUp, !isResolving else {
            mutex.unlock()
            return
        }

        isResolving = true
        mutex.unlock()

        let remoteWrapper = remoteSettings.createRemoteEnabledWrapper()

        // Applied as the wrapper's own tail, so the launch sequence is ordered behind the
        // resolution on the queue itself rather than behind a completion block.
        let applyOperation = ClosureOperation<Void> { [weak self] in
            let result = Result { try remoteWrapper.targetOperation.extractNoCancellableResultData() }

            self?.apply(remoteResult: result)
        }

        applyOperation.addDependency(remoteWrapper.targetOperation)

        execute(
            wrapper: remoteWrapper.insertingTail(operation: applyOperation),
            inOperationQueue: configOperationQueue,
            runningCallbackIn: nil
        ) { [weak self] _ in
            self?.finishResolving()
        }
    }

    func apply(remoteResult: Result<Bool, Error>) {
        switch remoteResult {
        case let .success(isEnabled):
            availability.setRemoteEnabled(isEnabled)
            service.handleAvailabilityChanged()
        case let .failure(error):
            logger.info("Analytics remote config unavailable, keeping the last resolved state: \(error)")
        }

        finishResolving()
        reconcile()
    }

    func finishResolving() {
        mutex.lock()
        isResolving = false
        mutex.unlock()
    }

    func reconcile() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let shouldRun = isSetUp && availability.isAvailable

        guard shouldRun != isActive else {
            return
        }

        isActive = shouldRun

        if shouldRun {
            activateLocked()
        } else {
            deactivateLocked()
        }
    }

    func activateLocked() {
        sessionTracker.setup()
        sessionTracker.startSession()

        service.trackAndFlush(
            .appOpened(isFirstLaunch: isFirstLaunch()),
            reason: .launch,
            completion: {}
        )
    }

    func deactivateLocked() {
        sessionTracker.throttle()
        service.cancelFlush()
    }

    func startSessionIfActive() {
        mutex.lock()
        let isActive = self.isActive
        mutex.unlock()

        guard isActive else {
            return
        }

        sessionTracker.startSession()
    }
}
