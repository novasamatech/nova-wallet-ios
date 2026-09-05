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
    private var isActive: Bool = false

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

        let availability = AnalyticsAvailabilityProvider(attestationMode: attestationMode)

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

            self?.sessionTracker.startSession()
        }
    }
}

// MARK: - AnalyticsServiceFacadeProtocol

extension AnalyticsServiceFacade: AnalyticsServiceFacadeProtocol {
    public func setup() {
        mutex.lock()

        guard !isActive else {
            mutex.unlock()
            return
        }

        isActive = true
        mutex.unlock()

        sessionTracker.setup()
        sessionTracker.startSession()

        service.trackAndFlush(
            .appOpened(isFirstLaunch: isFirstLaunch()),
            reason: .launch,
            completion: {}
        )

        resolveRemoteAvailability()
    }

    public func throttle() {
        mutex.lock()

        guard isActive else {
            mutex.unlock()
            return
        }

        isActive = false
        mutex.unlock()

        sessionTracker.throttle()
        service.cancelFlush()
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
        execute(
            wrapper: remoteSettings.createRemoteEnabledWrapper(),
            inOperationQueue: configOperationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(isEnabled):
                availability.setRemoteEnabled(isEnabled)
                service.handleAvailabilityChanged()

                guard !availability.isAvailable else {
                    return
                }

                throttle()
            case let .failure(error):
                logger.info("Analytics remote config unavailable: \(error)")
            }
        }
    }
}
