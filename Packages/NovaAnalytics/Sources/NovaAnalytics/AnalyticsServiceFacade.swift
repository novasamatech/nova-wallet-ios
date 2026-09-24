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
    private let applicationHandler: ApplicationHandlerProtocol
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()
    private var isSetUp: Bool = false
    private var isActive: Bool = false
    private var isInForeground: Bool = true
    private var isLaunchFlushPending: Bool = false
    private var isFirstLaunchAtSetup: Bool = false

    public convenience init(configuration: AnalyticsConfiguration) {
        self.init(
            configuration: configuration,
            sessionApplicationHandler: ApplicationHandler(),
            backgroundTaskRunner: UIApplicationBackgroundTaskRunner()
        )
    }

    init(
        configuration: AnalyticsConfiguration,
        sessionApplicationHandler: ApplicationHandlerProtocol,
        backgroundTaskRunner: BackgroundTaskRunning
    ) {
        let settingsManager = configuration.settingsManager

        let storageFacade = AnalyticsStorageFacade(
            storeDirectory: configuration.storeDirectory
        )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: storageFacade.createEventRepository()
        )

        let appAttest = configuration.appAttestService

        let attestationMode = BackendAttestationModeResolver.resolve(
            isAppAttestSupported: appAttest.isSupported
        )

        let availability = AnalyticsAvailabilityProvider(attestationMode: attestationMode)

        let consent = AnalyticsConsentManager(
            settingsManager: settingsManager,
            availabilityProvider: availability
        )

        let gatewayResolver = AnalyticsGatewayResolver(
            infraURLProvider: configuration.infraURLProvider,
            appAttest: appAttest,
            attestationMode: attestationMode,
            appIdentity: configuration.appIdentity,
            settingsManager: settingsManager,
            operationQueue: configuration.operationQueue,
            logger: configuration.logger
        )

        let identity = AnalyticsIdentity(settingsManager: settingsManager)

        let uploader = AnalyticsUploader(
            queue: eventQueue,
            identity: identity,
            gatewayResolver: gatewayResolver,
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
            gatewayResolver: gatewayResolver,
            operationQueue: configuration.analyticsOperationQueue,
            uploadOperationQueue: configuration.operationQueue,
            logger: configuration.logger
        )

        let sessionTracker = AnalyticsSessionTracker(
            tracker: service,
            applicationHandler: sessionApplicationHandler,
            backgroundTaskRunner: backgroundTaskRunner
        )

        isFirstLaunch = configuration.isFirstLaunch
        self.consent = consent
        self.service = service
        self.sessionTracker = sessionTracker
        self.availability = availability
        applicationHandler = ApplicationHandler()
        logger = configuration.logger

        consent.addObserver(with: self, queue: nil) { [weak self] oldValue, newValue in
            guard !oldValue, newValue else {
                return
            }

            self?.startSessionIfActive()
        }

        applicationHandler.delegate = self
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

        // Capture before the host clears its first-launch flag.
        isFirstLaunchAtSetup = isFirstLaunch()
        mutex.unlock()

        reconcile()
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

// MARK: - ApplicationHandlerDelegate

extension AnalyticsServiceFacade: ApplicationHandlerDelegate {
    public func didReceiveWillEnterForeground(notification _: Notification) {
        mutex.lock()
        isInForeground = true
        let shouldFlushLaunch = isLaunchFlushPending
        isLaunchFlushPending = false
        mutex.unlock()

        if shouldFlushLaunch {
            service.flush(reason: .launch)
        }

        reconcile()
    }

    public func didReceiveDidEnterBackground(notification _: Notification) {
        mutex.lock()
        isInForeground = false
        mutex.unlock()
    }
}

// MARK: - Private

private extension AnalyticsServiceFacade {
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

        let appOpened = AnalyticsEvent.appOpened(isFirstLaunch: isFirstLaunchAtSetup)

        guard isInForeground else {
            service.trackDeferringFlush(appOpened)
            isLaunchFlushPending = true
            return
        }

        sessionTracker.startSession()
        service.trackAndFlush(appOpened, reason: .launch, completion: {})
    }

    func deactivateLocked() {
        isLaunchFlushPending = false
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
