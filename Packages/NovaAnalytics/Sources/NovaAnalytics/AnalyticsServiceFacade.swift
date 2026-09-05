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

    /// Composed from `configuration` alone. The host owns the singleton and the build-flag
    /// gating — `AnalyticsFacadeFactory` in the app — so nothing here reaches back into it.
    public init(configuration: AnalyticsConfiguration) {
        let settingsManager = configuration.settingsManager

        // The package owns its persistence: its own model, its own sqlite, and a store
        // that drops an incompatible model rather than crashing a launch over unsent
        // telemetry. The directory is the host's to choose.
        let storageFacade = AnalyticsStorageFacade(
            storeDirectory: configuration.storeDirectory
        )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: storageFacade.createEventRepository()
        )

        let appAttest = AppAttestService()

        // The ladder's inputs are read here, at the factory, so the resolver itself
        // stays pure and unit-tested (spec §7.5).
        let attestationMode = BackendAttestationModeResolver.resolve(
            isReleaseBuild: configuration.isReleaseBuild,
            isAppAttestSupported: appAttest.isSupported
        )

        // Optimistic until setup() resolves the remote config: fail-open is what makes a
        // fetch error leave availability alone (spec §10).
        let availability = AnalyticsAvailabilityProvider(attestationMode: attestationMode)

        let consent = AnalyticsConsentManager(
            settingsManager: settingsManager,
            availabilityProvider: availability
        )

        let gatewayURL = configuration.gatewayURL

        let attestKeyRepository = SettingsAppAttestKeyRepository(settingsManager: settingsManager)

        // The provider signs on the shared queue: its wrapper chain nests, which a
        // serial queue could not run.
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

        // Persistence runs on the serial analytics queue and the upload on the shared
        // network queue, so an event is stored while a slow POST is in flight.
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

        // The opt-out wipe belongs to AnalyticsService, which observes the same manager.
        // The facade owns only the opt-in edge, which opens a session (spec §9).
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

        // Ordered, not fire-and-forget: a bare track() + flush() pair lets the launch
        // batch's peek run before app_opened and session_started have been written, so the
        // two events the launch flush exists for normally miss it.
        service.trackAndFlush(
            .appOpened(isFirstLaunch: isFirstLaunch()),
            reason: .launch,
            completion: {}
        )

        resolveRemoteAvailability()
    }

    /// A real symmetric throttle: the launch path never calls it, but the kill switch does
    /// once the remote config turns analytics off, and so do the tests.
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
        // track() depends on consent and availability only, never on isActive.
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

    public func debugPendingEventsWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        eventQueue.peekWrapper(count: count)
    }

    public func debugClearPendingEventsOperation() -> BaseOperation<Void> {
        eventQueue.clearOperation()
    }
}

// MARK: - Private

private extension AnalyticsServiceFacade {
    /// Spec §10. The host's provider caches after one fetch per process, so a change on
    /// the server takes effect on the next cold start. Fail-open: a fetch error logs at
    /// `.info` and leaves availability exactly as the attestation ladder set it.
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

                // The kill switch stops collection at the source: without this the session
                // tracker keeps observing foreground/background edges and keeps handing
                // events to a service that silently discards every one of them.
                throttle()
            case let .failure(error):
                logger.info("Analytics remote config unavailable: \(error)")
            }
        }
    }
}
